import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dcflight.platforms.ios_api import SDKCatalog
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence


class EscapingParameterTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc') and shutil.which('xcrun'), 'Swift toolchain required')
    def test_real_swift_alias_preserves_escaping_and_executes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            source=root/'Fixture.swift'
            source.write_text('public typealias Handler = (Int) -> Int\n'
                              'public func keep(_ handler: @escaping Handler) -> Handler { handler }\n'
                              'public func apply(_ handler: Handler) -> Int { handler(4) }\n')
            subprocess.run(['swiftc','-emit-library','-emit-module','-module-name','CallbackFixture',str(source),
                            '-o',str(root/'libCallbackFixture.dylib')],cwd=root,check=True,capture_output=True)
            target=json.loads(subprocess.check_output(['swiftc','-print-target-info'],text=True))['target']['triple']
            sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            subprocess.run(['xcrun','swift-symbolgraph-extract','-module-name','CallbackFixture','-I',directory,
                            '-target',target,'-sdk',sdk,'-output-dir',directory],check=True,capture_output=True)
            catalog=SDKCatalog.from_symbolgraphs([root/'CallbackFixture.symbols.json'],'CallbackFixture')
            keep=next(a for a in catalog.apis.values() if a.path==('keep(_:)',))
            apply=next(a for a in catalog.apis.values() if a.path==('apply(_:)',))
            self.assertTrue(keep.parameters[0].escaping)
            self.assertFalse(apply.parameters[0].escaping)
            self.assertEqual(keep,SDKCatalog.from_records([keep.to_dict()]).get(keep.id))
            invalid=keep.to_dict();invalid['parameters'][0]['escaping']='true'
            with self.assertRaisesRegex(ValueError,'escaping'):
                SDKCatalog.from_records([invalid])
            database=root/'sdk.sqlite'
            with Catalog(database,write=True) as indexed:
                indexed.import_records('ios','CallbackFixture','fixture',catalog.records(),{})
            request={'platform':'ios','inputs':[{'name':'handler','type':keep.parameters[0].type},
                                              {'name':'unused','type':keep.parameters[0].type}],
                     'steps':[{'id':keep.id,'scope':'CallbackFixture','arguments':[{'ref':'handler'}],'bind':'saved'}]}
            sequence=emit_sequence(NativeAPI(database),request)
            self.assertTrue(sequence['inputContracts'][0]['escaping'])
            self.assertFalse(sequence['inputContracts'][1]['escaping'])
            annotation='@escaping ' if sequence['inputContracts'][0]['escaping'] else ''
            immediate=emit_sequence(NativeAPI(database),{'platform':'ios',
                'inputs':[{'name':'handler','type':apply.parameters[0].type}],
                'steps':[{'id':apply.id,'arguments':[{'ref':'handler'}],'bind':'answer'}]})
            self.assertFalse(immediate['inputContracts'][0]['escaping'])
            main=root/'main.swift'
            main.write_text('import CallbackFixture\nfunc forward(_ handler: '+annotation+'Handler) -> Handler { '
                            +sequence['source']+'; return '+sequence['bindings'][0]['nativeName']+' }\n'
                            'func immediate(_ handler: '+apply.parameters[0].type+') -> Int { '
                            +immediate['source']+'; return '+immediate['bindings'][0]['nativeName']+' }\n'
                            'precondition(immediate { $0 * 2 } == 8)\n'
                            'let saved = forward { $0 * 2 }; precondition(saved(21) == 42); print("callback-ok")\n')
            command=['swiftc','-I',directory,'-L',directory,'-lCallbackFixture',str(main),'-o',str(root/'probe')]
            subprocess.run(command,check=True,capture_output=True)
            self.assertEqual('callback-ok',subprocess.check_output([str(root/'probe')],text=True).strip())
            main.write_text(main.read_text().replace('@escaping ',''))
            rejected=subprocess.run(command,capture_output=True,text=True)
            self.assertNotEqual(0,rejected.returncode)
            self.assertIn('non-escaping',rejected.stderr)
