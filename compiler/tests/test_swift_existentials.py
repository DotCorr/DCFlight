from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.swift_types import parse_type,spelling
from dcflight.platforms.ios_api import API,Parameter,SDKCatalog,Reference,Literal,_descriptor


class SwiftExistentialTests(unittest.TestCase):
    def test_structural_existential_optional_and_nested_types(self):
        for source in ('any Named','any Module.Named','(any Named)?','[any Named]','[String: (any Named)?]','(any Named) -> (any Named)?'):
            with self.subTest(source=source):self.assertEqual(parse_type(source),parse_type(spelling(parse_type(source))))
        self.assertNotEqual(parse_type('any Named'),parse_type('Named'))
        for source in ('any Named?','any (Named, Named)','any any Named','any Named; fatalError()','any Named & Other'):
            with self.subTest(source=source),self.assertRaises(ValueError):parse_type(source)

    def test_import_and_exact_reference_contract(self):
        symbol={'identifier':{'precise':'name'},'kind':{'identifier':'swift.func'},'pathComponents':['name(_:)'],
                'declarationFragments':[{'spelling':'func name(_ value: any Named) -> String'}],
                'functionSignature':{'parameters':[{'name':'value','declarationFragments':[{'spelling':'value: any Named'}]}],'returns':[{'spelling':'String'}]}}
        member=_descriptor(symbol,'Fixture');self.assertFalse(member.unsupported)
        sdk=SDKCatalog.from_records([member.to_dict()])
        self.assertIn('`value`',sdk.emit_call('name',[Reference('value','any Named')]).expression)
        for typ in ('Named','Any','any Other'):
            with self.subTest(typ=typ),self.assertRaisesRegex(ValueError,'type mismatch'):
                sdk.emit_call('name',[Reference('value',typ)])

    @unittest.skipUnless(shutil.which('swiftc'),'Swift compiler required')
    def test_native_protocol_dispatch_and_optional_nil(self):
        member=API('name','Fixture',('name(_:)',),'function',(Parameter('_','value','any Named'),),'String',(),())
        optional=API('optionalName','Fixture',('optionalName(_:)',),'function',(Parameter('_','value','(any Named)?'),),'String',(),())
        sdk=SDKCatalog([member,optional])
        call=sdk.emit_call('name',[Reference('value','any Named')]).expression
        empty=sdk.emit_call('optionalName',[Literal(None)]).expression
        source='''protocol Named { var name: String { get } }
struct Person: Named { var name: String }
func name(_ value: any Named) -> String { value.name }
func optionalName(_ value: (any Named)?) -> String { value?.name ?? "none" }
let value: any Named = Person(name: "native protocol")
'''+ 'let result = '+call+'\nlet empty = '+empty+'''
precondition(result == "native protocol" && empty == "none")
print("native existential dispatch passed")
'''
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'Check.swift';exe=Path(folder)/'Check';path.write_text(source)
            build=subprocess.run(['swiftc','-swift-version','6',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
            self.assertIn('native existential dispatch passed',run.stdout)
