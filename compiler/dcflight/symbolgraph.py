"""Read symbol graph entries incrementally instead of materializing the whole SDK graph."""
import gzip
import json
from pathlib import Path
from .frontends import unique_object


def graph_paths(directory):
    """Discover one plain or compressed file per graph; never silently omit gzip."""
    directory = Path(directory)
    paths = sorted([*directory.glob('*.symbols.json'), *directory.glob('*.symbols.json.gz')])
    if not paths:
        raise ValueError('No symbol graphs found in ' + str(directory))
    seen = set()
    for path in paths:
        name = path.name.removesuffix('.gz')
        if name in seen:
            raise ValueError('Duplicate plain/compressed symbol graph: ' + name)
        seen.add(name)
    return paths


class Reader:
    def __init__(self, stream, max_bytes=None):
        self.stream = stream
        self.max_bytes=max_bytes;self.bytes_read=0
        self.buffer = ''
        self.position = 0
        self.decoder = json.JSONDecoder(object_pairs_hook=unique_object)

    def more(self):
        chunk = self.stream.read(65536)
        if not chunk:
            raise ValueError('Unexpected end of symbol graph')
        self.account(chunk)
        self.buffer += chunk

    def account(self,chunk):
        self.bytes_read+=len(chunk.encode('utf8'))
        if self.max_bytes is not None and self.bytes_read>self.max_bytes:raise ValueError('Expanded symbol graph exceeds bound')

    def peek(self):
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace():
                self.position += 1
            if self.position < len(self.buffer):
                return self.buffer[self.position]
            self.buffer = ''
            self.position = 0
            self.more()

    def take(self, char):
        if self.peek() != char:
            raise ValueError('Expected ' + char + ' in symbol graph')
        self.position += 1

    def value(self):
        self.peek()
        self.buffer = self.buffer[self.position:]
        self.position = 0
        while True:
            try:
                value, end = self.decoder.raw_decode(self.buffer)
                self.position = end
                return value
            except json.JSONDecodeError:
                self.more()


def symbols(path, *, metadata=None, relationship_handler=None,max_bytes=None):
    """Stream plain/gzip UTF-8 graphs; exhaust the iterator before accepting input.

    Entries may precede a later document or gzip-integrity error. Catalog builders
    must finish iteration before publishing records as a successful import.
    """
    if metadata is not None and not isinstance(metadata,dict):
        raise ValueError('Symbol graph metadata output must be a dictionary')
    if relationship_handler is not None and not callable(relationship_handler):raise ValueError('Relationship handler must be callable')
    path = Path(path)
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', encoding='utf-8') as stream:
        reader = Reader(stream,max_bytes)
        reader.take('{')
        keys = set()
        while reader.peek() != '}':
            key = reader.value()
            if not isinstance(key, str) or key in keys:
                raise ValueError('Invalid or duplicate symbol graph key')
            keys.add(key)
            reader.take(':')
            if key == 'symbols':
                reader.take('[')
                while reader.peek() != ']':
                    symbol = reader.value()
                    if not isinstance(symbol, dict):
                        raise ValueError('Symbol graph entry must be an object')
                    yield symbol
                    if reader.peek() != ']':
                        reader.take(',')
                        if reader.peek() == ']':
                            raise ValueError('Trailing comma in symbols array')
                reader.take(']')
            elif key=='relationships' and relationship_handler is not None:
                reader.take('[')
                while reader.peek()!=']':
                    relationship=reader.value()
                    if not isinstance(relationship,dict):raise ValueError('Relationship must be an object')
                    relationship_handler(relationship)
                    if reader.peek()!=']':
                        reader.take(',')
                        if reader.peek()==']':raise ValueError('Trailing comma in relationships array')
                reader.take(']')
            else:
                value=reader.value()
                if key=='module' and metadata is not None: metadata['module']=value
            if reader.peek() != '}':
                reader.take(',')
                if reader.peek() == '}':
                    raise ValueError('Trailing comma in symbol graph')
        reader.take('}')
        if reader.buffer[reader.position:].strip():
            raise ValueError('Trailing data in symbol graph')
        for chunk in iter(lambda: stream.read(65536), ''):
            reader.account(chunk)
            if chunk.strip():
                raise ValueError('Trailing data in symbol graph')
        if 'symbols' not in keys:
            raise ValueError('Symbol graph has no symbols array')
