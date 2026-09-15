from pathlib import Path
import tempfile
import unittest
from dcflight.catalog import Catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'sdk.sqlite'

    def tearDown(self):
        self.temp.cleanup()

    def test_search_is_bounded_and_preserves_exact_overloads(self):
        records = [{'id': 'method-' + str(i), 'name': 'setText', 'owner': 'android.widget.TextView',
                    'kind': 'method', 'emittable': i % 2 == 0} for i in range(40)]
        with Catalog(self.path, write=True) as catalog:
            catalog.import_records('android','framework','35',records,{'sourceSha256':'example'})
            results = catalog.search('textview settext', emittable_only=True, limit=5)
            self.assertEqual(20, results['total'])
            self.assertEqual(5, len(results['results']))
            self.assertEqual(5, results['nextOffset'])
            self.assertEqual('method-12',catalog.get('android','method-12')['api']['id'])
            self.assertEqual(0,catalog.search("' OR 1=1 --")['total'])
        with Catalog(self.path) as catalog:
            self.assertEqual(40,catalog.search()['total'])
            with self.assertRaises(ValueError):
                catalog.search(limit=101)

    def test_evidence_is_per_symbol_and_invalidated_on_reimport(self):
        records=[dict(id='a',name='API',emittable=True),dict(id='b',name='Generic',emittable=False)]
        with Catalog(self.path,write=True) as catalog:
            catalog.import_records('ios','Foundation','26.2',records,{})
            catalog.record_evidence('ios','Foundation',['a'],'compiled',{'command':'swiftc','toolchain':'Xcode26.2'})
            self.assertEqual(1,catalog.coverage()['sources'][0]['compiled'])
            self.assertEqual(1,len(catalog.get('ios','a')['evidence']))
            with self.assertRaises(ValueError):
                catalog.record_evidence('ios','Foundation',['b'],'compiled',{'command':'swiftc','toolchain':'Xcode26.2'})
            catalog.import_records('ios','Foundation','27',records,{})
            self.assertEqual(0,catalog.coverage()['sources'][0]['compiled'])

    def test_invalid_import_rolls_back_previous_catalog(self):
        with Catalog(self.path,write=True) as catalog:
            catalog.import_records('ios','test','1',[dict(id='a',name='Original')],{})
            with self.assertRaises(ValueError):
                catalog.import_records('ios','test','2',[dict(name='Missing ID')],{})
            self.assertEqual('Original',catalog.get('ios','a')['api']['name'])
            self.assertEqual('1',catalog.coverage()['sources'][0]['sdk'])

    def test_multiple_scopes_require_disambiguation(self):
        with Catalog(self.path,write=True) as catalog:
            for scope in ('one','two'):
                catalog.import_records('ios',scope,'1',[dict(id='same',name='Value')],{})
            with self.assertRaisesRegex(ValueError,'multiple scopes'):
                catalog.get('ios','same')
            self.assertEqual('two',catalog.get('ios','same','two')['scope'])
