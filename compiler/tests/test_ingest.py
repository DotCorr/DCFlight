from pathlib import Path
import tempfile
import unittest
from dcflight.ingest import ingest

FIXTURES = Path(__file__).parent / 'fixtures'


class InventoryTests(unittest.TestCase):
    def test_android_preserves_overloads_and_provenance(self):
        source = FIXTURES / 'android-api.txt'
        data = ingest(source, 'android-api', 'fixture-35')
        self.assertEqual(7, len(data['symbols']))
        self.assertEqual(2, len([x for x in data['symbols'] if 'setText' in x['signature']]))
        self.assertTrue(all(x['status'] == 'unmapped' for x in data['symbols']))
        self.assertEqual(data, ingest(source, 'android-api', 'fixture-35'))

    def test_apple_keeps_precise_symbol_identity(self):
        data = ingest(FIXTURES / 'apple.symbols.json', 'apple-symbolgraph', 'fixture')
        self.assertEqual(2, len(data['symbols']))
        self.assertEqual('apple-symbolgraph:s:SwiftUI.Button', data['symbols'][0]['id'])

    def test_empty_input_is_not_success(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'empty.txt'
            path.write_text('no symbols here')
            with self.assertRaisesRegex(ValueError, 'No API symbols'):
                ingest(path, 'android-api', 'test')
