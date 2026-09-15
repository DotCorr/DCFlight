"""Development-time Swift calls from SDK symbol graphs; no executable SDK templates."""
from dataclasses import dataclass
from pathlib import Path
import json
import math
import re
from ..symbolgraph import symbols

_IDENT = re.compile(r'^[A-Za-z_][A-Za-z_0-9]*$')
_TYPE = re.compile(r'^[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*\??$')
_KINDS = {'swift.init': 'constructor', 'swift.method': 'method', 'swift.type.method': 'static_method', 'swift.func': 'function', 'swift.property': 'property', 'swift.type.property': 'static_property'}


def _identifier(value):
    if not isinstance(value, str) or not _IDENT.fullmatch(value):
        raise ValueError('Expected a Swift identifier')
    return '`' + value + '`'


def _typename(value):
    if not isinstance(value, str) or not _TYPE.fullmatch(value):
        raise ValueError('Unsupported Swift type: ' + str(value))
    return value


@dataclass(frozen=True)
class Parameter:
    label: str
    name: str
    type: str


@dataclass(frozen=True)
class API:
    id: str
    module: str
    path: tuple
    kind: str
    parameters: tuple
    result: str
    availability: tuple
    unsupported: tuple
    async_: bool = False
    throws: bool = False

    def to_dict(self):
        from dataclasses import asdict
        return {"id": self.id, "name": self.path[-1] if self.path else "", "kind": self.kind,
                "owner": self.owner, "module": self.module, "platform": "ios",
                "parameters": [asdict(p) for p in self.parameters], "resultType": self.result,
                "emittable": not self.unsupported, "unsupportedReasons": list(self.unsupported),
                "availability": list(self.availability), "async": self.async_, "throws": self.throws}

    @property
    def owner(self):
        return '.'.join(self.path[:-1])


@dataclass(frozen=True)
class Reference:
    """A named, typed local binding, never a Swift expression string."""
    name: str
    type: str


@dataclass(frozen=True)
class Literal:
    value: object


@dataclass(frozen=True)
class Emission:
    expression: str
    result_type: str
    imports: tuple


def _text(fragments):
    return ''.join(f.get('spelling', '') for f in fragments)


def _descriptor(symbol, module):
    kind = _KINDS.get(symbol.get('kind', {}).get('identifier'), 'unsupported')
    path = tuple(symbol.get('pathComponents', []))
    decl = _text(symbol.get('declarationFragments', []))
    sig = symbol.get('functionSignature', {})
    reasons = []
    params = []
    title = path[-1] if path else ''
    labels = title.partition('(')[2].rstrip(')').split(':')[:-1] if '(' in title else []
    raw_params = sig.get('parameters', [])
    for index, param in enumerate(raw_params):
        typ = _text(param.get('declarationFragments', [])).partition(':')[2].strip()
        label = labels[index] if index < len(labels) else param.get('name', '')
        params.append(Parameter(label, param.get('name', ''), typ))
        if not _TYPE.fullmatch(typ):
            reasons.append('parameter type requires structured lowering: ' + typ)
        if label != '_' and not _IDENT.fullmatch(label):
            reasons.append('invalid parameter label')
    result = _text(sig.get('returns', [])).strip() or 'Void'
    if kind == 'constructor':
        result = '.'.join(path[:-1])
        if 'init?' in decl or 'init!' in decl:
            result += '?'
    if kind.endswith('property'):
        result = decl.partition(':')[2].partition('{')[0].strip()
    if not _TYPE.fullmatch(result):
        reasons.append('result type requires structured lowering: ' + result)
    if kind == 'unsupported':
        reasons.append('symbol is not an invocable member')
    if symbol.get('swiftGenerics') or symbol.get('swiftExtension', {}).get('constraints'):
        reasons.append('generic constraints require specialization')
    if re.search(r'\b(Self|some|any|inout|rethrows)\b', decl):
        reasons.append('polymorphic or ownership signature requires lowering')
    if len(labels) != len(raw_params):
        reasons.append('parameter labels do not match signature')
    if not path or any(not _IDENT.fullmatch(p) for p in path[:-1]):
        reasons.append('unsupported owner path')
    name = title.partition('(')[0]
    if not _IDENT.fullmatch(name):
        reasons.append('unsupported callable name')
    if kind != 'function' and len(path) < 2:
        reasons.append('missing receiver type')
    return API(symbol['identifier']['precise'], module, path, kind, tuple(params), result,
               tuple(symbol.get('availability', [])), tuple(dict.fromkeys(reasons)),
               bool(re.search(r'\basync\b', decl)), bool(re.search(r'\bthrows\b', decl)))


class SDKCatalog:
    def __init__(self, apis):
        self.apis = {api.id: api for api in apis}

    @classmethod
    def from_symbolgraphs(cls, paths, module):
        _identifier(module)
        return cls(_descriptor(symbol, module) for path in paths for symbol in symbols(Path(path)))

    def search(self, query, *, emittable_only=False):
        return [api for api in self.apis.values() if query.casefold() in '.'.join(api.path).casefold()
                and (not emittable_only or not api.unsupported)]

    def records(self):
        return (api.to_dict() for api in self.apis.values())

    def get(self, precise_id):
        return self.apis[precise_id]

    def coverage(self):
        return {'indexed': len(self.apis), 'emittable_signatures': sum(not api.unsupported for api in self.apis.values()),
                'native_tested': None}

    def emit_call(self, precise_id, arguments=(), *, receiver=None, ios_version=(18, 0), allow_async=False, allow_throws=False):
        api = self.get(precise_id)
        if api.unsupported:
            raise ValueError('; '.join(api.unsupported))
        for entry in api.availability:
            if entry.get('domain') not in ('iOS', '*', 'Swift'):
                continue
            if entry.get('isUnconditionallyUnavailable'):
                raise ValueError('API unavailable on iOS')
            if entry.get('domain') == 'iOS':
                for key, reject in [('introduced', lambda version: ios_version < version), ('obsoleted', lambda version: ios_version >= version)]:
                    if key in entry:
                        version = entry[key]; version = (version.get('major', 0), version.get('minor', 0))
                        if reject(version):
                            raise ValueError('API outside target iOS availability')
        if api.async_ and not allow_async or api.throws and not allow_throws:
            raise ValueError('Caller must explicitly support async/throws')
        if len(arguments) != len(api.parameters):
            raise ValueError('Pass every parameter explicitly, including SDK defaults')
        instance = api.kind in ('method', 'property')
        if instance:
            if not isinstance(receiver, Reference) or receiver.type != api.owner:
                raise ValueError('Expected receiver binding of type ' + api.owner)
            target = _identifier(receiver.name) + '.'
        elif receiver is not None:
            raise ValueError('Static calls and constructors do not take receivers')
        else:
            target = '.'.join(_identifier(p) for p in api.path[:-1])
            target = target + '.' if target else ''
        name = api.path[-1].partition('(')[0]
        if api.kind == 'constructor':
            expression = target.rstrip('.')
        else:
            expression = target + _identifier(name)
        if not api.kind.endswith('property'):
            args = []
            for param, value in zip(api.parameters, arguments):
                rendered = _argument(value, param.type)
                args.append(rendered if param.label == '_' else _identifier(param.label) + ': ' + rendered)
            expression += '(' + ', '.join(args) + ')'
        return Emission(('try ' if api.throws else '') + ('await ' if api.async_ else '') + expression, api.result, (api.module,))


def _argument(value, expected):
    if isinstance(value, Reference):
        _typename(value.type)
        if value.type != expected:
            raise ValueError('Argument type mismatch: expected ' + expected)
        return _identifier(value.name)
    if not isinstance(value, Literal):
        raise ValueError('Arguments must be Literal or Reference nodes')
    raw = value.value
    if raw is None and expected.endswith('?'):
        return 'nil'
    if type(raw) is bool and expected == 'Bool':
        return 'true' if raw else 'false'
    if type(raw) is str and expected == 'String':
        # JSON Unicode escapes are not Swift escapes; keep Unicode literal and escape control characters explicitly.
        return '"' + ''.join('\\"' if c == '"' else '\\\\' if c == '\\' else '\\u{' + format(ord(c), 'x') + '}' if ord(c) < 32 or ord(c) == 127 else c for c in raw) + '"'
    if type(raw) is int and expected in ('Int', 'Int8', 'Int16', 'Int32', 'Int64', 'UInt', 'UInt8', 'UInt16', 'UInt32', 'UInt64'):
        unsigned = expected.startswith('U'); bits = int(re.sub('[^0-9]', '', expected) or '64')
        if not (0 if unsigned else -(2 ** (bits - 1))) <= raw < 2 ** (bits if unsigned else bits - 1):
            raise ValueError('Integer literal out of range')
        return str(raw)
    if type(raw) in (float, int) and expected in ('Double', 'Float', 'CGFloat', 'TimeInterval') and math.isfinite(raw):
        return str(float(raw))
    raise ValueError('Literal is incompatible with ' + expected)


def parse_cli_value(value):
    """Decode a closed JSON value schema. Raw Swift expressions are never accepted."""
    if not isinstance(value, dict):
        raise ValueError("Expected a typed value object")
    if set(value) == {"literal"}:
        return Literal(value["literal"])
    if set(value) == {"ref", "type"}:
        _identifier(value["ref"]); _typename(value["type"])
        return Reference(value["ref"], value["type"])
    raise ValueError("Expected {literal: value} or {ref: name, type: type}")
