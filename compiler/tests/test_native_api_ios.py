import tempfile
from pathlib import Path
import unittest
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.platforms.ios_api import API, Parameter


class NativeAPIIOSTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'catalog.sqlite'
        records=[
            API('uuid-init','Foundation',('UUID','init()'),'constructor',(),'UUID',(),()).to_dict(),
            API('label-text','UIKit',('UILabel','text'),'property',(),'String?',(),(),writable=True,owner_kind='class').to_dict(),
            API('optional-save','Foundation',('Delegate','save()'),'method',(),'Void',(),(),optional_call=True).to_dict(),
        ]
        with Catalog(self.path,write=True) as catalog:
            catalog.import_records('ios','Fixture','26.2',records,{'test':True})
        self.api=NativeAPI(self.path)

    def test_search_get_emit(self):
        with Catalog(self.path) as catalog:
            self.assertEqual(catalog.search('UUID',platform='ios')['total'],1)
            self.assertEqual(catalog.get('ios','uuid-init')['api']['owner'],'UUID')
        out=self.api.emit({'platform':'ios','id':'uuid-init'})
        self.assertEqual(out['source'],'(`UUID`() as UUID)')
        self.assertEqual(out['imports'],['Foundation'])
        self.assertIsNone(out['runtimeDependency'])

    def test_property_assignment(self):
        out=self.api.emit({'platform':'ios','id':'label-text','receiver':{'ref':'label','type':'UILabel'},'set':{'literal':'Hello'}})
        self.assertEqual(out['source'],'`label`.`text` = "Hello"')
        with self.assertRaises(ValueError):
            self.api.emit({'platform':'ios','id':'label-text','receiver':{'ref':'label','type':'UILabel'},'set':{'literal':'Hello'},'allowAsync':'yes'})

    def test_coverage_export_is_compact_and_reproducible(self):
        import json
        from tools.export_sdk_coverage import export
        with Catalog(self.path,write=True) as catalog:
            catalog.record_evidence('ios','Fixture',['uuid-init'],'compiled',
                {'command':'swiftc','toolchain':'test','payload':'UNIQUE_PER_SYMBOL_PAYLOAD'})
        prefix=self.path.parent/'coverage'
        paths=export(self.path,prefix)
        first=Path(paths['json']).read_text()
        report=json.loads(first)
        self.assertNotIn('UNIQUE_PER_SYMBOL_PAYLOAD',first)
        self.assertEqual(report['platforms'][0]['compiled'],1)
        self.assertEqual(next(p for p in report['platforms'] if p['platform']=='windows')['indexed'],0)
        self.assertIn('Remaining gaps',Path(paths['markdown']).read_text())
        export(self.path,prefix)
        self.assertEqual(Path(paths['json']).read_text(),first)

    def test_optional_method(self):
        out=self.api.emit({'platform':'ios','id':'optional-save','receiver':{'ref':'delegate','type':'Delegate'}})
        self.assertEqual(out['source'],'(`delegate`.`save`?() as Void?)')

    def test_reject_invalid_request_values(self):
        for extra in [{'iosVersion':[True,0]},{'arguments':['raw source']},{'allowThrows':1}]:
            with self.assertRaises(ValueError): self.api.emit({'platform':'ios','id':'uuid-init',**extra})

class IOSDiscoveryTests(unittest.TestCase):
    def test_cxx_inventory_is_separate_from_swift_frameworks(self):
        from tools.sweep_ios_sdk import discover
        with tempfile.TemporaryDirectory() as directory:
            sdk=Path(directory)
            (sdk/'System/Library/Frameworks/Example.framework').mkdir(parents=True)
            (sdk/'usr/include/c++/v1').mkdir(parents=True)
            (sdk/'usr/include/c++/v1/module.modulemap').write_text('module std_vector { header "vector" }')
            entries={x['module']:x for x in discover(sdk)}
            self.assertFalse(entries['Example']['excluded'])
            self.assertTrue(entries['std_vector']['excluded'])
            self.assertEqual(entries['std_vector']['extractionAdapter'],'cxx-required')

if __name__=='__main__':unittest.main()
