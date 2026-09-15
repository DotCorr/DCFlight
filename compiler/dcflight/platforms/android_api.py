"""Development-time Android metalava catalog and typed, direct Java call emission.

Catalog coverage is not device-tested coverage. No catalog or helper ships in apps.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict, replace
from types import MappingProxyType
import hashlib
import json
from pathlib import Path
import re

_IDENT = re.compile(r"^[A-Za-z_$][A-Za-z0-9_$]*$")
_TYPE = re.compile(r"^(?:[A-Za-z_$][A-Za-z0-9_$]*\.)*[A-Za-z_$][A-Za-z0-9_$]*(?:\[\])*$")
_KEYWORDS = set("abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null".split())
_PRIMITIVES = set("boolean byte char short int long float double void".split())
_BOXES = dict(zip('boolean byte char short int long float double'.split(),
                  ('java.lang.' + name for name in 'Boolean Byte Character Short Integer Long Float Double'.split())))
_JAVA_LANG = set("String CharSequence Object Class Boolean Byte Character Short Integer Long Float Double Number Throwable Exception RuntimeException Error Enum Iterable Comparable Cloneable AutoCloseable Runnable StringBuilder StringBuffer Void".split())
_MODIFIERS = set("public protected private static final abstract default synchronized native strictfp transient volatile deprecated".split())


def _identifier(value: str) -> str:
    if not isinstance(value, str) or not _IDENT.fullmatch(value) or value in _KEYWORDS:
        raise ValueError(f"Invalid Java identifier: {value!r}")
    return value


def _type(value: str) -> str:
    value = value.strip().replace("...", "[]")
    return re.sub(r'(?<![\w.$])[A-Za-z_$][\w$]*(?![\w.$])', lambda m: 'java.lang.' + m[0] if m[0] in _JAVA_LANG else m[0], value)


def _safe_type(value: str) -> bool:
    """Recognize fully concrete Java types, including nested generic arguments.

    This deliberately does not erase types or accept free type variables. Wildcard
    bounds are native Java syntax and stay explicit in generated signatures.
    """
    if not isinstance(value, str) or len(value) > 4096: return False
    tokens = re.findall(r'[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*|\[\]|[<>,?]|\S', value)
    cursor = 0

    def parse_type(argument=False, depth=0):
        nonlocal cursor
        if depth > 16: return False
        if cursor >= len(tokens): return False
        if tokens[cursor] == '?':
            if not argument: return False
            cursor += 1
            if cursor < len(tokens) and tokens[cursor] in ('extends', 'super'):
                cursor += 1
                bound_start = cursor
                valid = parse_type(False, depth+1)
                return valid and (tokens[bound_start] not in _PRIMITIVES or tokens[cursor - 1] == '[]')
            return True
        name = tokens[cursor]
        if not _TYPE.fullmatch(name): return False
        if name not in _PRIMITIVES and '.' not in name: return False
        if name not in _PRIMITIVES and any(part in _KEYWORDS for part in name.split('.')): return False
        cursor += 1
        if cursor < len(tokens) and tokens[cursor] == '<':
            if name in _PRIMITIVES: return False
            cursor += 1
            if not parse_type(True, depth+1): return False
            while cursor < len(tokens) and tokens[cursor] == ',':
                cursor += 1
                if not parse_type(True, depth+1): return False
            if cursor >= len(tokens) or tokens[cursor] != '>': return False
            cursor += 1
        arrays = 0
        while cursor < len(tokens) and tokens[cursor] == '[]':
            cursor += 1; arrays += 1
        if name == 'void' and (argument or arrays): return False
        if argument and name in _PRIMITIVES and not arrays: return False
        return True

    return parse_type() and cursor == len(tokens)


def _concrete_owner_type(value):
    """A concrete owner may contain nested unbounded wildcards, e.g List<Class<?>>.

    Wildcards occupying the owner's own slots are capture types, not bindings.
    Bounded wildcard constraints remain outside this explicit substitution slice.
    """
    if not _safe_type(value) or value in _PRIMITIVES or value.endswith('[]'):
        return False
    if re.search(r'\?\s+(?:extends|super)\b',value):return False
    _,separator,arguments=value.partition('<')
    return not separator or all(not argument.strip().startswith('?') for argument in _split(arguments[:-1]))


def _class_type(value):
    if not isinstance(value, str): raise ValueError('Class literal requires a type name')
    value = _type(value)
    if not _safe_type(value) or '<' in value:
        raise ValueError('Class literal requires a non-parameterized native type')
    return value, 'java.lang.Class<' + _BOXES.get(value, 'java.lang.Void' if value == 'void' else value) + '>'


def _annotations(text: str) -> tuple[str, tuple[str, ...]]:
    """Remove annotations with balanced arguments, retaining complete metadata."""
    annotations, pieces, i = [], [], 0
    while i < len(text):
        if text[i] != '@':
            pieces.append(text[i]); i += 1; continue
        start = i
        i += 1
        while i < len(text) and (text[i].isalnum() or text[i] in '._$'):
            i += 1
        if i < len(text) and text[i] == '(':
            depth, quote, escaped = 0, None, False
            while i < len(text):
                char = text[i]
                if quote:
                    if escaped: escaped = False
                    elif char == '\\': escaped = True
                    elif char == quote: quote = None
                elif char in '\"\'': quote = char
                elif char == '(': depth += 1
                elif char == ')':
                    depth -= 1
                    if depth == 0:
                        i += 1; break
                i += 1
        annotations.append(text[start:i]); pieces.append(' ')
    return ''.join(pieces).strip(), tuple(annotations)


def _split(text: str) -> list[str]:
    if not text.strip(): return []
    result, start, depth = [], 0, 0
    for i, char in enumerate(text):
        if char in '<([{': depth += 1
        elif char in '>)]}': depth -= 1
        elif char == ',' and depth == 0:
            result.append(text[start:i].strip()); start = i + 1
    result.append(text[start:].strip())
    return result


@dataclass(frozen=True)
class Parameter:
    java_type: str
    annotations: tuple[str, ...] = ()

    @property
    def nullability(self) -> str:
        if any(re.match(r'@(?:\w+\.)*NonNull\b', x) for x in self.annotations): return 'nonnull'
        if any(re.match(r'@(?:\w+\.)*Nullable\b', x) for x in self.annotations): return 'nullable'
        return 'unspecified'


@dataclass(frozen=True)
class Member:
    id: str
    owner: str
    kind: str
    name: str
    java_type: str
    parameters: tuple[Parameter, ...]
    static: bool
    annotations: tuple[str, ...]
    declaration: str
    api_level: int
    unsupported_reasons: tuple[str, ...]

    @property
    def emittable(self) -> bool:
        return not self.unsupported_reasons


@dataclass(frozen=True)
class JavaValue:
    """Structured values only: identifiers, literals or explicitly typed null."""
    kind: str
    value: object
    java_type: str

    def __post_init__(self):
        if not _safe_type(self.java_type) or self.java_type == 'void': raise ValueError('Invalid value type')
        if self.kind == 'reference': _identifier(self.value)
        elif self.kind == 'null':
            if self.value is not None or self.java_type in _PRIMITIVES: raise ValueError('Invalid null')
        elif self.kind == 'literal':
            if type(self.value) not in (str, int, float, bool): raise ValueError('Unsupported literal')
            expected = {str: 'java.lang.String', bool: 'boolean', int: 'int', float: 'double'}[type(self.value)]
            if self.java_type != expected: raise ValueError('Literal type mismatch')
            if type(self.value) is int and not -(2**31) <= self.value < 2**31: raise ValueError('Integer literal outside int range; use a typed reference')
            if type(self.value) is float:
                import math
                if not math.isfinite(self.value): raise ValueError('Nonfinite literal')
        elif self.kind == 'typed_literal':
            if self.java_type not in _PRIMITIVES: raise ValueError('Typed scalar requires a primitive type')
            _scalar_source(self.value, self.java_type)
        elif self.kind == 'array':
            _array_source(self.value, self.java_type)
        elif self.kind == 'class':
            native, expected = _class_type(self.value)
            if native != self.value or self.java_type != expected:
                raise ValueError('Class literal type mismatch')
        else: raise ValueError('Raw expressions are not accepted')

    @classmethod
    def reference(cls, name: str, java_type: str) -> JavaValue:
        return cls('reference', name, _type(java_type))

    @classmethod
    def literal(cls, value: str | int | float | bool) -> JavaValue:
        types = {str: 'java.lang.String', bool: 'boolean', int: 'int', float: 'double'}
        if type(value) not in types: raise ValueError('Unsupported literal')
        return cls('literal', value, types[type(value)])

    @classmethod
    def typed_literal(cls, value, java_type: str) -> JavaValue:
        return cls('typed_literal', value, _type(java_type))

    @classmethod
    def null(cls, java_type: str) -> JavaValue:
        return cls('null', None, _type(java_type))

    @classmethod
    def array(cls, values, java_type: str) -> JavaValue:
        def freeze(value, depth=0):
            if depth > 16: raise ValueError('Native array nesting exceeds 16')
            if type(value) is list: return tuple(freeze(item, depth + 1) for item in value)
            return value
        return cls('array', freeze(values), _type(java_type))

    @classmethod
    def class_literal(cls, java_type: str) -> JavaValue:
        native, result = _class_type(java_type)
        return cls('class', native, result)

    def source(self) -> str:
        if self.kind == 'class': return self.value + '.class'
        if self.kind == 'reference': return str(self.value)
        if self.kind == 'null': return f'({self.java_type}) null'
        if self.kind == 'array': return _array_source(self.value, self.java_type)
        if self.kind == 'typed_literal': return _scalar_source(self.value, self.java_type)
        return json.dumps(self.value, ensure_ascii=True)


def _scalar_source(value, expected):
    import math
    if expected == 'java.lang.String' and type(value) is str:
        if any(0xD800 <= ord(c) <= 0xDFFF for c in value):
            raise ValueError('String literals require valid Unicode')
        return json.dumps(value, ensure_ascii=True)
    if expected == 'boolean' and type(value) is bool:
        return 'true' if value else 'false'
    if expected == 'char' and type(value) is str and len(value) == 1 and ord(value) <= 0xFFFF and not 0xD800 <= ord(value) <= 0xDFFF:
        return '(char) ' + str(ord(value))
    if expected in ('byte', 'short', 'int', 'long') and type(value) is int:
        bits = {'byte':8, 'short':16, 'int':32, 'long':64}[expected]
        if not -(2**(bits-1)) <= value < 2**(bits-1): raise ValueError('Integer literal out of range')
        return str(value) + ('L' if expected == 'long' else '')
    if expected in ('float', 'double') and type(value) in (int, float):
        try: number = float(value)
        except OverflowError: raise ValueError('Floating literal out of range') from None
        if not math.isfinite(number) or expected == 'float' and abs(number) > 3.4028234663852886e38:
            raise ValueError('Floating literal out of range')
        return ('(float) ' if expected == 'float' else '') + repr(number) + 'd'
    raise ValueError('Literal does not match ' + expected)


def _array_source(values, java_type):
    """Emit real Java arrays; no erased generic allocation or runtime conversion."""
    if not java_type.endswith('[]') or '<' in java_type or not _safe_type(java_type):
        raise ValueError('Array literal requires a concrete reifiable array type')
    remaining = [4096]
    def emit(value, expected, depth):
        remaining[0] -= 1
        if remaining[0] < 0 or depth > 16:
            raise ValueError('Native array exceeds size or nesting limit')
        if value is None and expected not in _PRIMITIVES:
            return 'null'
        if expected.endswith('[]') and type(value) is tuple:
            return 'new ' + expected + ' {' + ', '.join(emit(item, expected[:-2], depth + 1) for item in value) + '}'
        return _scalar_source(value, expected)
    if type(values) is not tuple:
        raise ValueError('Array literal requires a list of values')
    return emit(values, java_type, 0)


@dataclass(frozen=True)
class NativeExpression:
    source: str
    java_type: str
    member_id: str


class AndroidAPI:
    def __init__(self, text: str, api_level: int = 35):
        if type(api_level) is not int or api_level < 1: raise ValueError('Invalid API level')
        self.api_level = api_level
        self.source_sha256 = hashlib.sha256(text.encode()).hexdigest()
        self.members: dict[str, Member] = {}
        self.classes: dict[str, dict] = {}
        self.unparsed: list[str] = []
        package, owner, owner_annotations, owner_reasons = '', '', (), ()
        for original in text.splitlines():
            line = original.strip()
            if line.startswith('package '):
                package = line.split()[1]; owner = ''; continue
            clean, annotations = _annotations(line.replace("@interface", "interface"))
            match = re.match(r'.*?\b(class|interface|enum|@interface)\s+([\w.$]+)', clean)
            if match and line.endswith('{'):
                owner = package + '.' + match[2]
                if not _safe_type(owner): raise ValueError('Unsafe SDK class name')
                owner_annotations = annotations
                owner_reasons = tuple(['flagged API requires separate SDK support'] if any('FlaggedApi' in a for a in annotations) else [])
                if 'public' not in clean.split(): owner_reasons += ('non-public owner',)
                self.classes[owner] = {'declaration': line, 'annotations': annotations, 'kind': match[1]}
                continue
            if line == '}': owner = ''; continue
            if not line.startswith(('ctor ', 'method ', 'field ', 'enum_constant ')): continue
            if not owner:
                self.unparsed.append(line); continue
            try:
                member = self._parse_member(owner, line, owner_annotations, owner_reasons)
            except (ValueError, IndexError):
                self.unparsed.append(line); continue
            if member.id in self.members: raise ValueError(f'Duplicate SDK member: {member.id}')
            self.members[member.id] = member

        # Enclosing flagged classes also gate nested types and signatures.
        flagged = {name for name, c in self.classes.items() if any('FlaggedApi' in a for a in c['annotations'])}
        for member_id, member in list(self.members.items()):
            expressions = [member.owner, member.java_type] + [p.java_type for p in member.parameters]
            types = [t for expression in expressions for t in re.findall(r'[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*', expression)]
            if any(any(t == f or t.startswith(f + '.') for f in flagged) for t in types):
                reason = 'flagged API requires separate SDK support'
                self.members[member_id] = replace(member, unsupported_reasons=tuple(dict.fromkeys(member.unsupported_reasons + (reason,))))

        # SDK members are immutable after parsing and flag propagation. Freezing
        # the public mapping prevents later mutations from invalidating the
        # overload index; specializations already return immutable replacements.
        peers = {}
        for member in self.members.values():
            key = (member.owner, member.kind, '<init>' if member.kind == 'ctor' else member.name)
            peers.setdefault(key, []).append(member)
        self.members = MappingProxyType(self.members)
        self._overloads = MappingProxyType({key: tuple(values) for key, values in peers.items()})

    def _overload_peers(self, member):
        return self._overloads.get((member.owner, member.kind, '<init>' if member.kind == 'ctor' else member.name), ())

    @classmethod
    def from_file(cls, path: str | Path, api_level: int = 35) -> AndroidAPI:
        return cls(Path(path).read_text(), api_level)

    def _parse_member(self, owner, line, owner_annotations, owner_reasons):
        kind, declaration = line.split(' ', 1)
        # Parse parameters before removing their annotations so nullability is preserved.
        no_annotations, all_annotations = _annotations(declaration)
        words = no_annotations.split()
        reasons = list(owner_reasons)
        if 'public' not in words: reasons.append('non-public member')
        if any('FlaggedApi' in a for a in all_annotations): reasons.append('flagged API requires separate SDK support')
        parameters = []
        if kind in ('method', 'ctor'):
            # Locate method argument list after stripping prefix annotations only.
            name_match = re.search(r'([\w$]+)\s*\(', no_annotations)
            if not name_match: raise ValueError('Missing callable name')
            name = name_match[1]
            prefix = no_annotations[:name_match.start()].split()
            if kind == 'ctor' and '<' in no_annotations[:name_match.start()]:
                reasons.append('generic constructor type parameters are unsupported')
            java_type = owner if kind == 'ctor' else _type(' '.join(w for w in prefix if w not in _MODIFIERS))
            # Find the actual callable parentheses (annotation argument lists excluded).
            actual = re.search(r'\b' + re.escape(name) + r'\s*\(', declaration)
            if not actual: raise ValueError('Missing parameter list')
            param_start = declaration.index('(', actual.start())
            depth, param_end = 1, param_start + 1
            quote = None
            while param_end < len(declaration) and depth:
                char = declaration[param_end]
                if quote:
                    if char == quote and declaration[param_end - 1] != '\\': quote = None
                elif char in '\"\'': quote = char
                elif char == '(': depth += 1
                elif char == ')': depth -= 1
                param_end += 1
            for param in _split(declaration[param_start + 1:param_end - 1]):
                value, anns = _annotations(param)
                value = re.sub(r'^final\s+', '', value)
                parameters.append(Parameter(_type(value), anns))
            if kind == 'ctor' and ('abstract ' in self.classes[owner]['declaration'] or self.classes[owner]['kind'] != 'class'):
                reasons.append('owner cannot be directly instantiated')
            # Non-static member classes require enclosing instance syntax.
            class_decl = self.classes[owner]['declaration']
            decl_name = re.search(r'\bclass\s+([\w.$]+)', class_decl)
            if kind == 'ctor' and decl_name and '.' in decl_name[1] and ' static ' not in ' ' + class_decl:
                reasons.append('non-static inner constructor requires enclosing instance')
        else:
            left = no_annotations.split(' = ', 1)[0].rstrip(';').split()
            name = left[-1]
            java_type = owner if kind == 'enum_constant' else _type(' '.join(w for w in left[:-1] if w not in _MODIFIERS))
        _identifier(name)
        for value in [java_type] + [p.java_type for p in parameters]:
            if not _safe_type(value): reasons.append('generic or unsupported type: ' + value)
            elif '.' not in value and value.replace('[]', '') not in _PRIMITIVES:
                reasons.append('unresolved type: ' + value)
        member_id = f'{owner}#{"<init>" if kind == "ctor" else name}'
        if kind in ('method', 'ctor'): member_id += '(' + ','.join(p.java_type for p in parameters) + ')'
        return Member(member_id, owner, kind, name, java_type, tuple(parameters), 'static' in words or kind == 'enum_constant', tuple(dict.fromkeys(owner_annotations + all_annotations)), line, self.api_level, tuple(dict.fromkeys(reasons)))

    def _receiver_type(self, owner: str) -> str:
        declaration, _ = _annotations(self.classes.get(owner, {}).get('declaration', ''))
        match = re.search(r'\b(?:class|interface)\s+[\w.$]+<', declaration)
        if not match: return owner
        start, cursor, depth = match.end(), match.end(), 1
        while cursor < len(declaration) and depth:
            if declaration[cursor] == '<': depth += 1
            elif declaration[cursor] == '>': depth -= 1
            cursor += 1
        if depth: return owner
        # A wildcard view of the generic receiver avoids raw invocation erasure.
        return owner + '<' + ','.join('?' for _ in _split(declaration[start:cursor - 1])) + '>'

    def _generic_parents(self, actual: str):
        base, separator, arguments = actual.partition('<')
        declaration, _ = _annotations(self.classes.get(base, {}).get('declaration', ''))
        match = re.search(r'\b(?:class|interface)\s+[\w.$]+', declaration)
        if not match: return ()
        tail = declaration[match.end():].strip()
        bindings = {}
        if tail.startswith('<'):
            if not separator: return ()  # Raw owners cannot supply concrete arguments.
            depth, end = 1, 1
            while end < len(tail) and depth:
                if tail[end] == '<': depth += 1
                elif tail[end] == '>': depth -= 1
                end += 1
            if depth: return ()
            formals = _split(tail[1:end-1]); values = _split(arguments[:-1])
            if len(formals) != len(values): return ()
            for formal, value in zip(formals, values):
                name = formal.strip().split()[0]
                if not _IDENT.fullmatch(name): return ()
                bindings[name] = value
            tail = tail[end:].strip()
        elif separator:
            return ()  # A parameterized receiver needs declared type parameters.
        parents = re.split(r'\b(?:extends|implements)\b', tail.rstrip('{').strip())
        result = []
        for group in parents[1:]:
            for parent in _split(group.strip()):
                resolved = re.sub(r'(?<![\w.$])[A-Za-z_$][\w$]*(?![\w.$])',
                                  lambda m: bindings.get(m[0], m[0]), parent.strip())
                if _safe_type(resolved): result.append(resolved)
        return tuple(result)

    def is_assignable(self, actual: str, expected: str, _depth=0) -> bool:
        if _depth > 32 or len(actual) > 4096 or len(expected) > 4096: return False

        if re.sub(r'\s+', '', actual) == re.sub(r'\s+', '', expected): return True
        if actual.endswith('[]') and expected.endswith('[]'):
            if actual[:-2] in _PRIMITIVES or expected[:-2] in _PRIMITIVES:
                return False  # Primitive arrays do not inherit scalar widening.
            return self.is_assignable(actual[:-2], expected[:-2], _depth+1)
        if actual.endswith('[]') or expected.endswith('[]'):
            return actual.endswith('[]') and expected in ('java.lang.Object', 'java.lang.Cloneable', 'java.io.Serializable')
        if actual in _PRIMITIVES or expected in _PRIMITIVES:
            if actual in _BOXES and expected not in _PRIMITIVES:
                return self.is_assignable(_BOXES[actual], expected, _depth+1)
            if actual in _BOXES.values() and expected in _PRIMITIVES:
                primitive = next(key for key, value in _BOXES.items() if value == actual)
                return self.is_assignable(primitive, expected, _depth+1)
            return expected in {
                'byte':('short','int','long','float','double'),
                'short':('int','long','float','double'),
                'char':('int','long','float','double'),
                'int':('long','float','double'),
                'long':('float','double'),
                'float':('double',),
            }.get(actual,())
        if '<' in actual:
            actual_base, actual_args = actual.split('<', 1)
            if '<' not in expected:
                return self.is_assignable(actual_base, expected, _depth+1)
            expected_base, expected_args = expected.split('<', 1)
            if actual_base != expected_base:
                return any(self.is_assignable(parent, expected, _depth+1) for parent in self._generic_parents(actual))
            left, right = _split(actual_args[:-1]), _split(expected_args[:-1])
            if len(left) != len(right): return False
            for provided, required in zip(left, right):
                if required == '?' or re.sub(r'\s+', '', provided) == re.sub(r'\s+', '', required): continue
                if required.startswith('? extends '):
                    if provided.startswith('? super '): return False
                    bound = 'java.lang.Object' if provided == '?' else provided.removeprefix('? extends ')
                    if not self.is_assignable(bound, required[len('? extends '):], _depth+1): return False
                elif required.startswith('? super '):
                    if provided == '?' or provided.startswith('? extends '): return False
                    if not self.is_assignable(required[len('? super '):], provided.removeprefix('? super '), _depth+1): return False
                else: return False
            return True
        if '<' in expected:
            # A non-generic class can fix its parent's type parameters in its
            # declaration. Preserve those arguments rather than erasing them.
            return any(self.is_assignable(parent, expected, _depth+1) for parent in self._generic_parents(actual))
        if expected == 'java.lang.Object' and actual not in _PRIMITIVES: return True
        if actual == 'java.lang.String' and expected in ('java.lang.CharSequence', 'java.io.Serializable'): return True
        if actual.endswith('[]') or expected.endswith('[]'): return False
        seen, pending = set(), [actual]
        while pending:
            current = pending.pop()
            if current == expected: return True
            if current in seen: continue
            seen.add(current)
            declaration = self.classes.get(current, {}).get('declaration', '')
            # Only non-generic fully qualified inheritance edges are trusted.
            while re.search(r'<[^<>]*>', declaration):
                declaration = re.sub(r'<[^<>]*>', '', declaration)
            declaration, _ = _annotations(declaration)
            tail = re.split(r'\b(?:extends|implements)\b', declaration, maxsplit=1)
            if len(tail) == 2:
                for candidate in re.findall(r'(?<![\w.])(?:[a-zA-Z_$][\w$]*\.)+[a-zA-Z_$][\w$]*(?![\w.<])', tail[1]):
                    pending.append(candidate)
        return False

    def is_writable(self, member: Member) -> bool:
        # Inspect declaration modifiers, never a string constant's initializer.
        declaration, _ = _annotations(member.declaration)
        prefix = declaration.split('=', 1)[0].split()
        return (member.emittable and member.kind == 'field' and 'final' not in prefix
                and self.classes[member.owner]['kind'] != 'interface')

    def thread_requirement(self, member: Member) -> str:
        # Parameter annotations describe parameter/callback contracts, not the
        # thread on which the containing method must be invoked.
        prefix = member.declaration
        if member.kind in ('method','ctor'):
            match = re.search(r'\b' + re.escape(member.name) + r'\s*\(', prefix)
            if match: prefix = prefix[:match.start()]
        else:
            prefix = prefix.split(' = ', 1)[0]
        _, annotations = _annotations(prefix)
        def requirement(values):
            names = {a.split('(',1)[0].rsplit('.',1)[-1].lstrip('@') for a in values}
            contexts = set()
            if names & {'MainThread','UiThread'}: contexts.add('main')
            if 'WorkerThread' in names: contexts.add('worker')
            if 'AnyThread' in names: contexts.add('any')
            return 'conflicting' if len(contexts)>1 else next(iter(contexts),None)
        return requirement(annotations) or requirement(self.classes[member.owner]['annotations']) or 'unknown'

    def check_thread(self, member: Member, context):
        if context not in (None,'unknown','main','worker'):
            raise ValueError('Execution context requires unknown, main or worker')
        required = self.thread_requirement(member)
        if required == 'conflicting': raise ValueError('Conflicting native thread requirements')
        if context is not None and required in ('main','worker') and context != required:
            raise ValueError('Native API requires '+required+' execution context')

    def records(self) -> list[dict]:
        from ..android_generic_invocation import requirements
        return [{
            'id': m.id, 'name': m.name, 'kind': m.kind, 'owner': m.owner,
            'platform': 'android', 'module': m.owner.rsplit('.', 1)[0],
            'parameters': [{'type': p.java_type, 'java_type': p.java_type, 'nullability': p.nullability, 'annotations': list(p.annotations)} for p in m.parameters],
            'resultType': m.java_type, 'emittable': m.emittable, 'supported': m.emittable,
            'unsupportedReasons': list(m.unsupported_reasons),
            'availability': {'sdkSnapshot': m.api_level, 'minimumApi': None, 'annotations': list(m.annotations)},
            'static': m.static, 'writable': self.is_writable(m), 'nativeTested': False, 'nativeDeclaration': m.declaration,
            'threadRequirement': self.thread_requirement(m),
            **({'invocationRequirements':info} if (info := requirements(self,m)) is not None else {}),
        } for m in self.members.values()]

    def search(self, query: str, limit: int = 50) -> list[Member]:
        if not 1 <= limit <= 10000: raise ValueError('limit must be 1..10000')
        return [m for m in self.members.values() if query.casefold() in m.id.casefold()][:limit]

    def get(self, member_id: str) -> Member:
        try: return self.members[member_id]
        except KeyError: raise ValueError(f'Unknown Android API: {member_id}') from None

    def stats(self) -> dict:
        return {'api_level': self.api_level, 'source_sha256': self.source_sha256, 'classes_indexed': len(self.classes), 'members_indexed': len(self.members), 'members_emittable': sum(m.emittable for m in self.members.values()), 'members_unsupported': sum(not m.emittable for m in self.members.values()), 'declarations_unparsed': len(self.unparsed), 'members_native_tested': 0}

    def _owner_view(self, owner: str, receiver_type: str, _depth=0):
        """Resolve a concrete receiver to its declared owner without erasure."""
        if _depth > 16: raise ValueError('Owner argument nesting is too deep')
        if not _safe_type(receiver_type): raise ValueError('Invalid receiver type')
        pending, seen, matches = [(receiver_type, 0)], set(), []
        while pending:
            current, depth = pending.pop()
            if depth > 32: raise ValueError('Generic owner inheritance is too deep')
            if current in seen: continue
            seen.add(current)
            base, separator, arguments = current.partition('<')
            declaration, _ = _annotations(self.classes.get(base, {}).get('declaration', ''))
            match = re.search(r'\b(?:class|interface)\s+[\w.$]+', declaration)
            tail = declaration[match.end():].strip() if match else ''
            bindings = {}
            if tail.startswith('<'):
                end, nesting = 1, 1
                while end < len(tail) and nesting:
                    if tail[end] == '<': nesting += 1
                    elif tail[end] == '>': nesting -= 1
                    end += 1
                if nesting: raise ValueError('Invalid owner type parameters')
                if not separator:
                    if base == owner: return None
                    continue
                formals, values = _split(_type(tail[1:end-1])), _split(arguments[:-1])
                if len(formals) != len(values): raise ValueError('Owner type argument count mismatch')
                if any(value.strip().startswith('?') or re.search(r'\?\s+(?:extends|super)\b',value) for value in values): return None
                bounds = []
                for formal, value in zip(formals, values):
                    parameter = re.fullmatch(r'([A-Za-z_$][\w$]*)(?:\s+extends\s+(.+))?', formal)
                    if not parameter or parameter[1] in bindings or parameter[1] in _KEYWORDS:
                        raise ValueError('Unsupported owner type parameter')
                    if not _safe_type(value) or value in _PRIMITIVES:
                        raise ValueError('Owner arguments must be concrete reference types')
                    nested = value
                    while nested.endswith('[]'): nested = nested[:-2]
                    if '<' in nested:
                        self._owner_view(nested.split('<', 1)[0], nested, _depth+1)
                    bindings[parameter[1]] = value
                    bounds.append((value, parameter[2] or 'java.lang.Object'))
                for value, bound in bounds:
                    for constraint in bound.split('&'):
                        resolved = self._substitute(constraint.strip(), bindings)
                        if not _safe_type(resolved) or not self.is_assignable(value, resolved):
                            raise ValueError('Owner type argument does not satisfy bound: ' + resolved)
            elif separator:
                raise ValueError('Parameterized receiver has no declared owner type parameters')
            if base == owner:
                matches.append((current, bindings))
            else:
                pending.extend((parent, depth+1) for parent in self._generic_parents(current))
        if len({view for view, _ in matches}) > 1:
            raise ValueError('Conflicting generic owner inheritance')
        return matches[0] if matches else None

    @staticmethod
    def _substitute(text, bindings):
        return re.sub(r'(?<![\w.$])[A-Za-z_$][\w$]*(?![\w.$])',
                      lambda match: bindings.get(match[0], match[0]), text)

    @staticmethod
    def _callable_type_prefix(member):
        if member.kind != 'ctor':
            return member.java_type
        declaration, _ = _annotations(member.declaration)
        match = re.search(r'([\w$]+)\s*\(', declaration)
        prefix = declaration[:match.start()] if match else ''
        start = prefix.find('<')
        return _type(prefix[start:].strip()) + ' ' + member.java_type if start >= 0 else member.java_type

    @classmethod
    def _callable_variables(cls, member):
        prefix = cls._callable_type_prefix(member)
        if not prefix.startswith('<'): return set()
        depth, end = 1, 1
        while end < len(prefix) and depth:
            if prefix[end] == '<': depth += 1
            elif prefix[end] == '>': depth -= 1
            end += 1
        if depth: raise ValueError('Unbalanced generic callable declaration')
        return {formal.split()[0] for formal in _split(prefix[1:end-1])}

    def resolve_member(self, member_id: str, receiver_type=None, type_arguments=None, constructed_type=None) -> Member:
        """Specialize owner and method variables using explicit native types."""
        member = self.get(member_id)
        if constructed_type is not None:
            if member.kind != 'ctor' or receiver_type is not None:
                raise ValueError('Constructed type requires a constructor without a receiver')
            if not isinstance(constructed_type, str):
                raise ValueError('Constructed type must be a native type name')
            constructed_type = _type(constructed_type)
            if (not _concrete_owner_type(constructed_type)
                    or constructed_type.split('<', 1)[0] != member.owner):
                raise ValueError('Constructed type must name the exact constructor owner with concrete arguments')
            view = self._owner_view(member.owner, constructed_type)
            if view is None:
                raise ValueError('Constructed type requires concrete owner type arguments; raw generic types are unsupported')
            _, bindings = view
            # Constructor variables have their own scope, even when an owner
            # variable uses the same name.
            shadowed = self._callable_variables(member)
            bindings = {key: value for key, value in bindings.items() if key not in shadowed}
            parameters = tuple(replace(p, java_type=self._substitute(p.java_type, bindings)) for p in member.parameters)
            reasons = tuple(r for r in member.unsupported_reasons if not r.startswith('generic or unsupported type: '))
            for parameter in parameters:
                if not _safe_type(parameter.java_type):
                    reasons += ('generic or unsupported type: ' + parameter.java_type,)
            member = replace(member, java_type=constructed_type, parameters=parameters, unsupported_reasons=reasons)
        if receiver_type is not None and not member.static and member.kind != 'ctor':
            view = self._owner_view(member.owner, receiver_type)
            if view:
                _, bindings = view
                # Method variables shadow identically named owner variables.
                if member.java_type.startswith('<'):
                    depth, end = 1, 1
                    while end < len(member.java_type) and depth:
                        if member.java_type[end] == '<': depth += 1
                        elif member.java_type[end] == '>': depth -= 1
                        end += 1
                    shadowed = {formal.split()[0] for formal in _split(member.java_type[1:end-1])}
                    bindings = {key: value for key, value in bindings.items() if key not in shadowed}
                result = self._substitute(member.java_type, bindings)
                parameters = tuple(replace(p, java_type=self._substitute(p.java_type, bindings)) for p in member.parameters)
                reasons = tuple(r for r in member.unsupported_reasons if not r.startswith('generic or unsupported type: '))
                for value in [result] + [p.java_type for p in parameters]:
                    if not _safe_type(value): reasons += ('generic or unsupported type: ' + value,)
                member = replace(member, java_type=result, parameters=parameters, unsupported_reasons=reasons)
        if type_arguments is not None:
            member = self.specialize(member_id, type_arguments, _member=member)
        return member

    def specialize(self, member_id: str, type_arguments, *, _member=None) -> Member:
        """Resolve explicit method or constructor arguments at development time."""
        member = _member or self.get(member_id)
        if member.kind not in ('method', 'ctor'):
            raise ValueError('Type arguments require a generic method or constructor')
        if not isinstance(type_arguments, (list, tuple)) or not 1 <= len(type_arguments) <= 32:
            raise ValueError('Expected 1..32 explicit type arguments')
        values = []
        for value in type_arguments:
            if not isinstance(value, str): raise ValueError('Type arguments must be type names')
            value = _type(value)
            if not _safe_type(value) or value in _PRIMITIVES:
                raise ValueError('Type arguments must be reference types')
            values.append(value)
        # java_type preserves the method formal prefix, e.g. <T extends X> T.
        prefix = self._callable_type_prefix(member)
        if not prefix.startswith('<'): raise ValueError('Callable has no type parameters')
        if member.kind == 'ctor':
            view = self._owner_view(member.owner, member.java_type)
            if view is None:
                raise ValueError('Generic constructor requires concrete owner type arguments')
            shadowed = self._callable_variables(member)
            prefix = self._substitute(prefix, {key: value for key, value in view[1].items() if key not in shadowed})
        depth, end = 1, 1
        while end < len(prefix) and depth:
            if prefix[end] == '<': depth += 1
            elif prefix[end] == '>': depth -= 1
            end += 1
        if depth: raise ValueError('Unbalanced generic method declaration')
        formals = _split(prefix[1:end-1])
        if len(formals) != len(values): raise ValueError('Type argument count mismatch')
        bindings, bounds = {}, []
        for formal, value in zip(formals, values):
            match = re.fullmatch(r'([A-Za-z_$][\w$]*)(?:\s+extends\s+(.+))?', formal)
            if not match or match[1] in bindings or match[1] in _KEYWORDS:
                raise ValueError('Unsupported method type parameter')
            bindings[match[1]] = value
            bounds.append((value, match[2] or 'java.lang.Object'))
        def substitute(text):
            return re.sub(r'(?<![\w.$])[A-Za-z_$][\w$]*(?![\w.$])',
                          lambda m: bindings.get(m[0], m[0]), text)
        for value, bound in bounds:
            for constraint in bound.split('&'):
                resolved = substitute(constraint.strip())
                if not _safe_type(resolved) or not self.is_assignable(value, resolved):
                    raise ValueError('Type argument does not satisfy bound: ' + resolved)
        result = substitute(prefix[end:].strip())
        parameters = tuple(replace(p, java_type=substitute(p.java_type)) for p in member.parameters)
        if any(not _safe_type(t) for t in [result] + [p.java_type for p in parameters]):
            raise ValueError('Specialization leaves an unsupported type')
        reasons = tuple(r for r in member.unsupported_reasons
                        if not r.startswith('generic or unsupported type: ')
                        and r != 'generic constructor type parameters are unsupported')
        return replace(member, java_type=result, parameters=parameters, unsupported_reasons=reasons)

    def emit(self, member_id: str, arguments: list[JavaValue] | tuple[JavaValue, ...] = (), receiver: JavaValue | None = None, type_arguments=None, execution_context=None, constructed_type=None) -> NativeExpression:
        member = self.resolve_member(member_id, receiver.java_type if isinstance(receiver, JavaValue) else None, type_arguments, constructed_type)
        if constructed_type is not None and receiver is not None:
            raise ValueError('Constructed type requires a constructor without a receiver')
        if constructed_type is not None or (member.kind == 'ctor' and type_arguments is not None):
            for peer in self._overload_peers(member):
                if peer.id == member.id or peer.owner != member.owner or peer.kind != 'ctor': continue
                try:
                    peer_types = type_arguments if self._callable_variables(peer) else None
                    alternative = self.resolve_member(peer.id, type_arguments=peer_types, constructed_type=constructed_type)
                except ValueError: continue
                if (alternative.emittable and tuple(p.java_type for p in alternative.parameters)
                        == tuple(p.java_type for p in member.parameters)):
                    raise ValueError('Owner specialization collapses distinct native overloads: ' + peer.id)
        if type_arguments is not None:
            # Java generic varargs overload resolution can remain ambiguous
            # after explicit substitution. Do not promise exact selection when
            # a sibling's T... also accepts the selected concrete array.
            for peer in self._overload_peers(member):
                if (peer.id == member.id or peer.owner != member.owner or peer.name != member.name
                        or peer.kind != member.kind or not peer.parameters or '...' not in peer.declaration
                        or len(peer.parameters) != len(member.parameters)):
                    continue
                last = peer.parameters[-1].java_type
                if not last.endswith('[]') or not _IDENT.fullmatch(last[:-2]) or last[:-2] in _PRIMITIVES:
                    continue
                original_last = self.get(member_id).parameters[-1].java_type
                if original_last == last or not _safe_type(original_last): continue
                try: alternative = self.resolve_member(peer.id, type_arguments=type_arguments, constructed_type=constructed_type)
                except ValueError: continue
                if (alternative.emittable
                        and alternative.parameters[:-1] == member.parameters[:-1]
                        and self.is_assignable(member.parameters[-1].java_type, alternative.parameters[-1].java_type)):
                    raise ValueError('Generic array overload may be ambiguous after specialization: ' + peer.id)
        if isinstance(receiver, JavaValue) and member.kind == 'method' and not member.static:
            for peer in self._overload_peers(member):
                if peer.id == member.id or peer.owner != member.owner or peer.name != member.name or peer.kind != 'method': continue
                try: alternative = self.resolve_member(peer.id, receiver.java_type, type_arguments)
                except ValueError: continue
                if (alternative.emittable and len(alternative.parameters) == len(member.parameters)
                        and tuple(p.java_type for p in alternative.parameters) == tuple(p.java_type for p in member.parameters)):
                    raise ValueError('Owner specialization collapses distinct native overloads: ' + peer.id)
        if not member.emittable: raise ValueError('; '.join(member.unsupported_reasons))
        self.check_thread(member, execution_context)
        if len(arguments) != len(member.parameters): raise ValueError('Argument count mismatch')
        emitted = []
        for value, param in zip(arguments, member.parameters):
            if not isinstance(value, JavaValue): raise ValueError('Expected structured JavaValue')
            if not self.is_assignable(value.java_type, param.java_type): raise ValueError(f'Expected {param.java_type}, got {value.java_type}; use an explicitly typed reference')
            if value.kind == 'null' and param.java_type in _PRIMITIVES: raise ValueError('Cannot unbox an explicit null')
            if value.kind == 'null' and param.nullability == 'nonnull': raise ValueError('Null passed to nonnull parameter')
            emitted.append(f'({param.java_type}) ({value.source()})')
        if member.kind == 'ctor' or member.static:
            if receiver is not None: raise ValueError('Static members and constructors do not accept a receiver')
            target = member.java_type if member.kind == 'ctor' else member.owner
        else:
            if not isinstance(receiver, JavaValue) or receiver.kind != 'reference' or not self.is_assignable(receiver.java_type, member.owner):
                raise ValueError(f'Receiver must be a reference of type {member.owner}')
            view = self._owner_view(member.owner, receiver.java_type)
            depends_on_owner = self.resolve_member(member_id, receiver.java_type) != self.get(member_id)
            target = f'(({view[0] if view and depends_on_owner else self._receiver_type(member.owner)}) {receiver.source()})'
        if member.kind == 'ctor':
            types = '<' + ', '.join(_type(t) for t in type_arguments) + '> ' if type_arguments is not None else ''
            source = f'new {types}{target}({", ".join(emitted)})'
        elif member.kind in ('field', 'enum_constant'): source = f'{target}.{member.name}'
        else:
            types = '<' + ', '.join(_type(t) for t in type_arguments) + '>' if type_arguments is not None else ''
            source = f'{target}.{types}{member.name}({", ".join(emitted)})'
        return NativeExpression(source, member.java_type, member.id)

    def emit_set(self, member_id: str, value: JavaValue, receiver: JavaValue | None = None, execution_context=None) -> NativeExpression:
        member = self.resolve_member(member_id, receiver.java_type if isinstance(receiver, JavaValue) else None)
        self.check_thread(member, execution_context)
        if not self.is_writable(member):
            raise ValueError('Assignment requires a supported writable field; final fields and enum constants are read-only')
        if not isinstance(value, JavaValue):
            raise ValueError('Expected structured JavaValue')
        if not self.is_assignable(value.java_type, member.java_type):
            raise ValueError(f'Expected {member.java_type}, got {value.java_type}; use an explicitly typed reference')
        if value.kind == 'null' and member.java_type in _PRIMITIVES:
            raise ValueError('Cannot unbox an explicit null')
        if value.kind == 'null' and Parameter(member.java_type, member.annotations).nullability == 'nonnull':
            raise ValueError('Null assigned to nonnull field')
        # Reuse the exact field-read receiver checks and owner qualification.
        target = self.emit(member_id, receiver=receiver).source
        return NativeExpression(f'{target} = ({member.java_type}) ({value.source()})', member.java_type, member.id)

    def export(self, path: str | Path):
        Path(path).write_text(json.dumps({'statistics': self.stats(), 'classes': self.classes, 'members': [asdict(x) for x in self.members.values()], 'unparsed': self.unparsed}, indent=2) + '\n')
