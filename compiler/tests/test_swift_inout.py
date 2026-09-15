import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference, Literal
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence


class SwiftInoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc') and shutil.which('xcrun'),'Swift toolchain required')
    def test_sdk_import_and_generated_sequence_mutate_native_value(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'Fixture.swift'
            source.write_text('public func increment(_ value: inout Int32) { value += 1 }\n'
                              'public func pair(_ a: inout Int32, _ b: inout Int32) { a += 1; b += 1 }\n')
            subprocess.run(['swiftc','-emit-library','-emit-module','-module-name','MutationFixture',str(source),
                            '-o',str(root/'libMutationFixture.dylib')],cwd=root,check=True,capture_output=True)
            sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            target=json.loads(subprocess.check_output(['swiftc','-print-target-info'],text=True))['target']['triple']
            subprocess.run(['xcrun','swift-symbolgraph-extract','-module-name','MutationFixture','-I',directory,
                            '-sdk',sdk,'-target',target,'-output-dir',directory],check=True,capture_output=True)
            imported=SDKCatalog.from_symbolgraphs([root/'MutationFixture.symbols.json'],'MutationFixture')
            increment=next(a for a in imported.apis.values() if a.path==('increment(_:)',))
            pair=next(a for a in imported.apis.values() if a.path==('pair(_:_:)',))
            self.assertTrue(increment.parameters[0].inout)
            self.assertEqual(increment,SDKCatalog.from_records([increment.to_dict()]).get(increment.id))
            for value in (Literal(1),Reference('value','Int32')):
                with self.assertRaisesRegex(ValueError,'mutable'):
                    imported.emit_call(increment.id,[value])
            mutable=Reference('value','Int32',mutable=True)
            with self.assertRaisesRegex(ValueError,'Overlapping'):
                imported.emit_call(pair.id,[mutable,mutable])
            database=root/'sdk.sqlite'
            with Catalog(database,write=True) as catalog:
                catalog.import_records('ios','MutationFixture','fixture',imported.records(),{})
            sequence=emit_sequence(NativeAPI(database),{'platform':'ios',
                'inputs':[{'name':'value','type':'Int32','mutable':True}],
                'steps':[{'id':increment.id,'arguments':[{'ref':'value'}]}]})
            main=root/'main.swift';main.write_text('import MutationFixture\nvar value: Int32 = 41\n'+sequence['source']+'\nprecondition(value == 42)\n')
            subprocess.run(['swiftc','-swift-version','6','-I',directory,'-L',directory,'-lMutationFixture',
                            str(main),'-o',str(root/'probe')],check=True,capture_output=True)
            subprocess.run([str(root/'probe')],check=True,capture_output=True)
