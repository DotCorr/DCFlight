import gzip
import json
from pathlib import Path
import tempfile
import unittest

from dcflight.symbolgraph import symbols
from dcflight.platforms.ios_api import SDKCatalog
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI


def member(identity):
    return {'identifier':{'precise':identity},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner',identity],
            'declarationFragments':[{'spelling':'static var '+identity+': Int { get }'}]}


class BystanderImportTests(unittest.TestCase):
    def test_streamed_late_metadata_plain_and_gzip(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);data={'symbols':[member('value')],'module':{'name':'Foundation','bystanders':['Dispatch']}}
            for compressed in [False,True]:
                path=root/('graph.symbols.json'+('.gz' if compressed else ''));raw=json.dumps(data).encode();path.write_bytes(gzip.compress(raw) if compressed else raw)
                metadata={};self.assertEqual([member('value')],list(symbols(path,metadata=metadata)))
                self.assertEqual(data['module'],metadata['module'])
                self.assertEqual(('Dispatch',),SDKCatalog.from_symbolgraphs([path],'Foundation').get('value').required_imports)
    def test_graph_scoped_imports_reach_native_api_without_scope_wide_leak(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);ordinary=root/'ordinary.json';overlay=root/'overlay.json'
            ordinary.write_text(json.dumps({'symbols':[member('plain')]}));overlay.write_text(json.dumps({'symbols':[member('overlay')],'module':{'bystanders':['SwiftUI']}}))
            catalog=SDKCatalog.from_symbolgraphs([ordinary,overlay],'MapKit')
            self.assertEqual((),catalog.get('plain').required_imports);self.assertEqual(('SwiftUI',),catalog.get('overlay').required_imports)
            database=root/'sdk.sqlite'
            with Catalog(database,write=True) as db:db.import_records('ios','Fixture','fixture',catalog.records(),{'fixture':True})
            native=NativeAPI(database)
            self.assertEqual(['MapKit','SwiftUI'],native.emit({'platform':'ios','id':'overlay'})['imports'])
            self.assertEqual(['MapKit'],native.emit({'platform':'ios','id':'plain'})['imports'])
    def test_malformed_module_and_bystanders_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/'graph.json'
            for module in [None,[],{'bystanders':'SwiftUI'},{'bystanders':[None]},{'bystanders':['SwiftUI; bad()']},{'bystanders':['A']*33}]:
                path.write_text(json.dumps({'symbols':[member('value')],'module':module}))
                with self.subTest(module=module),self.assertRaises(ValueError):SDKCatalog.from_symbolgraphs([path],'Foundation')
            path.write_text(json.dumps({'symbols':[member('value')],'module':{'bystanders':['SwiftUI']}})+' garbage')
            with self.assertRaisesRegex(ValueError,'Trailing data'):SDKCatalog.from_symbolgraphs([path],'Foundation')


if __name__=='__main__':unittest.main()
