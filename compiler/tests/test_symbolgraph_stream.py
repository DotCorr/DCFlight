import gzip
import json
from pathlib import Path
import tempfile
import unittest

from dcflight.symbolgraph import symbols, graph_paths
from dcflight.platforms.ios_api import SDKCatalog


class SymbolGraphStreamTests(unittest.TestCase):
    def test_discovery_does_not_silently_drop_compressed_graphs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, 'No symbol graphs'):
                graph_paths(root)
            plain = root / 'A.symbols.json'
            compressed = root / 'B.symbols.json.gz'
            plain.write_text('{"symbols":[]}')
            compressed.write_bytes(gzip.compress(b'{"symbols":[]}'))
            self.assertEqual([plain, compressed], graph_paths(root))
            (root / 'A.symbols.json.gz').write_bytes(gzip.compress(plain.read_bytes()))
            with self.assertRaisesRegex(ValueError, 'Duplicate plain/compressed'):
                graph_paths(root)

    def test_compressed_and_plain_catalogs_match(self):
        fixture = Path(__file__).parent / 'fixtures/apple.symbols.json'
        with tempfile.TemporaryDirectory() as directory:
            compressed = Path(directory) / 'API.symbols.json.gz'
            compressed.write_bytes(gzip.compress(fixture.read_bytes()))
            self.assertEqual(list(symbols(fixture)), list(symbols(compressed)))
            self.assertEqual(list(SDKCatalog.from_symbolgraphs([fixture], 'SwiftUI').records()),
                             list(SDKCatalog.from_symbolgraphs([compressed], 'SwiftUI').records()))

    def test_document_must_finish_validly_after_symbols(self):
        invalid = [
            '{"symbols":[]',
            '{"symbols":[],"symbols":[]}',
            '{"symbols":[{},]}',
            '{"symbols":[],}',
            '{"symbols":[null]}',
            '{"symbols":[]} false',
            '{"symbols":[],"metadata":{"a":1,"a":2}}',
            '{"metadata":{}}',
        ]
        with tempfile.TemporaryDirectory() as directory:
            for compressed in (False, True):
                path = Path(directory) / ('API.json.gz' if compressed else 'API.json')
                for source in invalid:
                    with self.subTest(compressed=compressed, source=source):
                        data = source.encode()
                        path.write_bytes(gzip.compress(data) if compressed else data)
                        with self.assertRaises(ValueError):
                            list(symbols(path))

    def test_chunk_boundaries_and_metadata_after_symbols(self):
        entries = [{'identifier': {'precise': str(i)}, 'text': 'é' * 1000} for i in range(200)]
        data = json.dumps({'symbols': entries, 'relationships': [], 'metadata': {'v': 1}})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'API.json.gz'
            path.write_bytes(gzip.compress((data + ' ' * 70000).encode()))
            self.assertEqual(entries, list(symbols(path)))
            path.write_bytes(gzip.compress((data + ' ' * 70000 + '{}').encode()))
            with self.assertRaisesRegex(ValueError, 'Trailing data'):
                list(symbols(path))

    def test_corrupt_gzip_footer_is_not_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'API.json.gz'
            path.write_bytes(gzip.compress(b'{"symbols":[]}')[:-4])
            with self.assertRaises((EOFError, OSError)):
                list(symbols(path))
