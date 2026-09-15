"""Read symbol graph entries incrementally instead of materializing the whole SDK graph."""
import json
from .frontends import unique_object


class Reader:
    def __init__(self, stream):
        self.stream = stream
        self.buffer = ''
        self.position = 0
        self.decoder = json.JSONDecoder(object_pairs_hook=unique_object)

    def more(self):
        chunk = self.stream.read(65536)
        if not chunk:
            raise ValueError('Unexpected end of symbol graph')
        self.buffer += chunk

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


def symbols(path):
    with path.open() as stream:
        reader = Reader(stream)
        reader.take('{')
        while reader.peek() != '}':
            key = reader.value()
            reader.take(':')
            if key == 'symbols':
                reader.take('[')
                while reader.peek() != ']':
                    yield reader.value()
                    if reader.peek() != ']':
                        reader.take(',')
                reader.take(']')
                return
            reader.value()
            if reader.peek() != '}':
                reader.take(',')
        raise ValueError('Symbol graph has no symbols array')
