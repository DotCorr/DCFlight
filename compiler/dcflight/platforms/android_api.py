"""Development-time Android metalava catalog and typed, direct Java call emission.

Catalog coverage is not device-tested coverage. No catalog or helper ships in apps.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
import hashlib
import json
from pathlib import Path
import re

_IDENT = re.compile(r"^[A-Za-z_$][A-Za-z0-9_$]*$")
_TYPE = re.compile(r"^(?:[A-Za-z_$][A-Za-z0-9_$]*\.)*[A-Za-z_$][A-Za-z0-9_$]*(?:\[\])*$")
_KEYWORDS = set("abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null".split())
_PRIMITIVES = set("boolean byte char short int long float double void".split())
_JAVA_LANG = set("String CharSequence Object Class Boolean Byte Character Short Integer Long Float Double Number Throwable Exception RuntimeException Error Enum Iterable Comparable Cloneable AutoCloseable Runnable StringBuilder StringBuffer Void".split())
_MODIFIERS = set("public protected private static final abstract default synchronized native strictfp transient volatile deprecated".split())


def _identifier(value: str) -> str:
    if not isinstance(value, str) or not _IDENT.fullmatch(value) or value in _KEYWORDS:
        raise ValueError(f"Invalid Java identifier: {value!r}")
    return value


def _type(value: str) -> str:
    value = value.strip().replace("...", "[]")
    base = value.replace("[]", "")
    if base in _JAVA_LANG:
        value = "java.lang." + value
    return value


def _safe_type(value: str) -> bool:
    return bool(_TYPE.fullmatch(value)) and all(p not in _KEYWORDS or p in _PRIMITIVES for p in value.replace("[]", "").split("."))


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
    def null(cls, java_type: str) -> JavaValue:
        return cls('null', None, _type(java_type))

    def source(self) -> str:
        if self.kind == 'reference': return str(self.value)
        if self.kind == 'null': return f'({self.java_type}) null'
        return json.dumps(self.value, ensure_ascii=True)


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

    def is_assignable(self, actual: str, expected: str) -> bool:
        if actual == expected: return True
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
            tail = re.split(r'\b(?:extends|implements)\b', declaration, maxsplit=1)
            if len(tail) == 2:
                for candidate in re.findall(r'(?<![\w.])(?:[a-zA-Z_$][\w$]*\.)+[a-zA-Z_$][\w$]*(?![\w.<])', tail[1]):
                    pending.append(candidate)
        return False

    def records(self) -> list[dict]:
        return [{
            'id': m.id, 'name': m.name, 'kind': m.kind, 'owner': m.owner,
            'platform': 'android', 'module': m.owner.rsplit('.', 1)[0],
            'parameters': [{'type': p.java_type, 'java_type': p.java_type, 'nullability': p.nullability, 'annotations': list(p.annotations)} for p in m.parameters],
            'resultType': m.java_type, 'emittable': m.emittable, 'supported': m.emittable,
            'unsupportedReasons': list(m.unsupported_reasons),
            'availability': {'sdkSnapshot': m.api_level, 'minimumApi': None, 'annotations': list(m.annotations)},
            'static': m.static, 'nativeTested': False,
        } for m in self.members.values()]

    def search(self, query: str, limit: int = 50) -> list[Member]:
        if not 1 <= limit <= 10000: raise ValueError('limit must be 1..10000')
        return [m for m in self.members.values() if query.casefold() in m.id.casefold()][:limit]

    def get(self, member_id: str) -> Member:
        try: return self.members[member_id]
        except KeyError: raise ValueError(f'Unknown Android API: {member_id}') from None

    def stats(self) -> dict:
        return {'api_level': self.api_level, 'source_sha256': self.source_sha256, 'classes_indexed': len(self.classes), 'members_indexed': len(self.members), 'members_emittable': sum(m.emittable for m in self.members.values()), 'members_unsupported': sum(not m.emittable for m in self.members.values()), 'declarations_unparsed': len(self.unparsed), 'members_native_tested': 0}

    def emit(self, member_id: str, arguments: list[JavaValue] | tuple[JavaValue, ...] = (), receiver: JavaValue | None = None) -> NativeExpression:
        member = self.get(member_id)
        if not member.emittable: raise ValueError('; '.join(member.unsupported_reasons))
        if len(arguments) != len(member.parameters): raise ValueError('Argument count mismatch')
        emitted = []
        for value, param in zip(arguments, member.parameters):
            if not isinstance(value, JavaValue): raise ValueError('Expected structured JavaValue')
            if not self.is_assignable(value.java_type, param.java_type): raise ValueError(f'Expected {param.java_type}, got {value.java_type}; use an explicitly typed reference')
            if value.kind == 'null' and param.nullability == 'nonnull': raise ValueError('Null passed to nonnull parameter')
            emitted.append(f'({param.java_type}) ({value.source()})')
        if member.kind == 'ctor' or member.static:
            if receiver is not None: raise ValueError('Static members and constructors do not accept a receiver')
            target = member.owner
        else:
            if not isinstance(receiver, JavaValue) or receiver.kind != 'reference' or not self.is_assignable(receiver.java_type, member.owner):
                raise ValueError(f'Receiver must be a reference of type {member.owner}')
            target = f'(({member.owner}) {receiver.source()})'
        if member.kind == 'ctor': source = f'new {target}({", ".join(emitted)})'
        elif member.kind in ('field', 'enum_constant'): source = f'{target}.{member.name}'
        else: source = f'{target}.{member.name}({", ".join(emitted)})'
        return NativeExpression(source, member.java_type, member.id)

    def export(self, path: str | Path):
        Path(path).write_text(json.dumps({'statistics': self.stats(), 'classes': self.classes, 'members': [asdict(x) for x in self.members.values()], 'unparsed': self.unparsed}, indent=2) + '\n')
