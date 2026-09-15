from ios_sdk_fixture import fake_toolchain, write_sdk
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from dcflight import ios_verification as verifier

class TypeModuleVerificationTests(unittest.TestCase):
    def test_dependency_inputs_are_compiled_exported_and_hash_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);primary=root/'Primary';dependency=root/'Dependency'
            primary.mkdir();dependency.mkdir()
            symbol={'identifier':{'precise':'member'},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner','value'],
                    'declarationFragments':[{'spelling':'static var value: '},{'kind':'typeIdentifier','spelling':'OldName','preciseIdentifier':'type:renamed'},{'spelling':' { get }'}]}
            (primary/'Primary.symbols.json').write_text(json.dumps({'symbols':[symbol]}))
            nominal={'identifier':{'precise':'type:renamed'},'kind':{'identifier':'swift.struct'},'pathComponents':['New','Name'],'declarationFragments':[{'spelling':'struct Name'}]}
            graph=dependency/'Dependency.symbols.json';graph.write_text(json.dumps({'symbols':[nominal]}))
            output=root/'report.json';sources=[]
            def native(command,**kwargs):
                sources.append(Path(command[-1]).read_text())
                return SimpleNamespace(returncode=0,stdout='')
            with patch.object(verifier.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture-toolchain')),patch.object(verifier.subprocess,'run',side_effect=native):
                status=verifier.main(['--module','Primary='+str(primary),'--type-module','Dependency='+str(dependency),'--output',str(output)],progress=False)
            self.assertEqual(0,status)
            self.assertIn('import Dependency',sources[0]);self.assertIn('New.Name',sources[0])
            result=verifier.export_records({'Primary':primary},output,root/'records',type_modules={'Dependency':dependency})
            self.assertEqual(1,result['Primary']['native_tested'])
            record=json.loads((root/'records/Primary.jsonl').read_text())
            self.assertEqual(['Dependency'],record['requiredImports'])
            self.assertEqual('type:renamed',record['typeResolutions'][0]['id'])
            with self.assertRaisesRegex(ValueError,'Type dependency'):
                verifier.export_records({'Primary':primary},output,root/'missing')
            graph.write_text(json.dumps({'symbols':[nominal],'changed':True}))
            with self.assertRaisesRegex(ValueError,'Type dependency'):
                verifier.export_records({'Primary':primary},output,root/'changed',type_modules={'Dependency':dependency})
            self.assertFalse((root/'changed').exists())

    def test_duplicate_or_malformed_type_modules_rejected(self):
        for entries in (['Missing'],['Foo='],['Foo=a','Foo=b'],['bad;name=a']):
            with self.subTest(entries=entries),self.assertRaises(ValueError):
                verifier.parse_type_modules(entries)
