"""JSON and a deliberately non-executing, const Dart constructor subset."""
import json
import re
from pathlib import Path
from .validate import Diagnostic


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Diagnostic("duplicate field: " + key)
        result[key] = value
    return result


def read_json(text):
    return json.loads(text, object_pairs_hook=unique_object,
                      parse_constant=lambda value: (_ for _ in ()).throw(Diagnostic("invalid JSON constant: " + value)))


TOKEN = re.compile(r'''\s+|//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|-?\d+|[A-Za-z_][A-Za-z0-9_]*|[{}\[\]():,;=]''')


class DartParser:
    def __init__(self, text):
        self.tokens = []
        offset = 0
        for match in TOKEN.finditer(text):
            if match.start() != offset:
                raise Diagnostic("unsupported Dart syntax at offset " + str(offset))
            token = match.group()
            offset = match.end()
            if not token.isspace() and not token.startswith(('//', '/*')):
                self.tokens.append(token)
        if offset != len(text):
            raise Diagnostic("unsupported Dart syntax at offset " + str(offset))
        self.i = 0

    def peek(self):
        return self.tokens[self.i] if self.i < len(self.tokens) else "<eof>"

    def take(self, expected=None):
        token = self.peek()
        if token == "<eof>" or (expected is not None and token != expected):
            raise Diagnostic("Dart: expected " + str(expected) + ", found " + token)
        self.i += 1
        return token

    def string(self, token):
        if '$' in token:
            raise Diagnostic("Dart interpolation is unsupported; use Ref")
        if token[0] == '"':
            return json.loads(token)
        # Single-quoted Dart strings support the same escapes, plus escaped apostrophes.
        body = token[1:-1].replace("\\'", "'").replace('"', '\\"')
        return json.loads('"' + body + '"')

    def value(self, depth=0):
        if depth > 120:
            raise Diagnostic("Dart nesting exceeds 120")
        token = self.take()
        if token == "const":
            return self.value(depth + 1)
        if token.startswith(('"', "'")):
            return self.string(token)
        if re.fullmatch(r"-?\d+", token):
            return int(token)
        if token in ("true", "false"):
            return token == "true"
        if token == '[':
            items = []
            while self.peek() != ']':
                items.append(self.value(depth + 1))
                if self.peek() != ']':
                    self.take(',')
            self.take(']')
            return items
        if token == '{':
            pairs = []
            while self.peek() != '}':
                key = self.value(depth + 1)
                if not isinstance(key, str):
                    raise Diagnostic("Dart map keys must be strings")
                self.take(':')
                pairs.append((key, self.value(depth + 1)))
                if self.peek() != '}':
                    self.take(',')
            self.take('}')
            return unique_object(pairs)
        if token not in ("App", "Node", "Action", "Ref"):
            raise Diagnostic("unsupported Dart constructor: " + token)
        self.take('(')
        pairs = []
        while self.peek() != ')':
            key = self.take()
            self.take(':')
            pairs.append((key, self.value(depth + 1)))
            if self.peek() != ')':
                self.take(',')
        self.take(')')
        result = unique_object(pairs)
        constructors = {
            'App': ({'version', 'id', 'name', 'state', 'actions', 'root'}, {'version', 'id', 'name', 'root'}),
            'Node': ({'id', 'type', 'props', 'children', 'action', 'style'}, {'id', 'type', 'props'}),
            'Action': ({'id', 'op', 'target', 'value'}, {'id', 'op'}),
            'Ref': ({'name'}, {'name'}),
        }
        allowed, required = constructors[token]
        if set(result) - allowed or not required <= set(result):
            raise Diagnostic('Invalid named arguments for ' + token)
        if token == 'Ref':
            if set(result) != {'name'}:
                raise Diagnostic("Ref requires name only")
            return {'ref': result['name']}
        return result

    def parse(self):
        if self.peek() == 'import':
            self.take('import')
            module = self.string(self.take())
            if module != 'package:dcflight_authoring/dcflight.dart':
                raise Diagnostic("Only the dcflight authoring import is supported")
            self.take(';')
        self.take('const')
        self.take('app')
        self.take('=')
        value = self.value()
        self.take(';')
        if self.peek() != '<eof>':
            raise Diagnostic("Dart: trailing executable declarations are unsupported")
        return value


def load(path):
    path = Path(path)
    text = path.read_text()
    return DartParser(text).parse() if path.suffix == '.dart' else read_json(text)
