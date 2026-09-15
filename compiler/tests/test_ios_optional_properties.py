import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference, Literal, API, Parameter
from dcflight.platforms.swift_types import parse_type
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence
from dcflight.catalog import Catalog


def graph():
    return {'symbols':[{'identifier':{'precise':'optionalDetail'},'kind':{'identifier':'swift.property'},
        'pathComponents':['Values','detail'],
        'declarationFragments':[{'spelling':'optional var detail: String? { get set }'}]}]}


class OptionalPropertyTests(unittest.TestCase):
    def catalog(self, root):
        source=root/'fixture.symbols.json';source.write_text(json.dumps(graph()))
        return SDKCatalog.from_symbolgraphs([source],'Foundation')

    def test_descriptor_roundtrip_retains_nested_optionality_and_rejects_assignment(self):
        with tempfile.TemporaryDirectory() as folder:
            catalog=self.catalog(Path(folder));member=catalog.get('optionalDetail')
            self.assertTrue(member.optional_call);self.assertEqual('String?',member.result)
            loaded=SDKCatalog.from_records([member.to_dict()])
            result=loaded.emit_call(member.id,receiver=Reference('value','Values'))
            self.assertEqual(parse_type('String??'),parse_type(result.result_type))
            with self.assertRaisesRegex(ValueError,'Optional Objective-C property assignment'):
                loaded.emit_set(member.id,Literal(None),receiver=Reference('value','Values',mutable=True))

    @unittest.skipUnless(shutil.which('xcrun'),'Apple Swift compiler required')
    def test_native_missing_property_nil_value_and_present_value_are_distinct(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);catalog=self.catalog(root);db=root/'catalog.sqlite'
            with Catalog(db,write=True) as c:c.import_records('ios','Foundation','fixture',[catalog.get('optionalDetail').to_dict()],{'fixture':True})
            request={'platform':'ios','allowThrows':True,'inputs':[{'name':'value','type':'Values'}],
                'steps':[{'id':'optionalDetail','receiver':{'ref':'value'},'bind':'candidate'},
                         {'unwrap':{'ref':'candidate'},'bind':'implemented','message':'Missing property'},
                         {'unwrap':{'ref':'implemented'},'bind':'result','message':'Nil value'}]}
            emitted=emit_sequence(NativeAPI(db),request)
            result=next(b for b in emitted['bindings'] if b['name']=='result')
            source=root/'Check.swift'
            source.write_text('''import Foundation
@objc protocol Values { @objc optional var detail:String? { get set } }
final class Empty:NSObject,Values {}
final class Present:NSObject,Values { @objc var detail:String?; init(_ text:String?) { detail=text } }
func extract(_ value:Values) throws -> String {
'''+emitted['source']+'\nreturn '+result['nativeName']+'''
}
@main struct Main { static func main() throws {
 precondition(try extract(Present("native")) == "native")
 for (value,message):(Values,String) in [(Empty(),"Missing property"),(Present(nil),"Nil value")] {
  do { _ = try extract(value);fatalError("Expected failure") }
  catch let error as NSError { precondition(error.localizedDescription==message) }
 }
 print("OPTIONAL_PROPERTY_PASSED")
}}
'''.replace('precondition(try extract(Present("native")) == "native")','let text = try extract(Present("native"));precondition(text == "native")'))
            build=subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(source),'-o',str(root/'check')],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(root/'check')],capture_output=True,text=True,timeout=15)
            self.assertEqual(0,run.returncode,run.stderr);self.assertIn('OPTIONAL_PROPERTY_PASSED',run.stdout)
