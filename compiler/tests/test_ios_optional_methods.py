import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference


class OptionalMethodTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('xcrun'),'Apple Swift compiler required')
    def test_optional_method_nullable_result_matches_native_chaining(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);graph=root/'Fixture.symbols.json'
            symbol={'identifier':{'precise':'optionalDetail'},'kind':{'identifier':'swift.method'},
                    'pathComponents':['Values','detail()'],
                    'declarationFragments':[{'spelling':'optional func detail() -> String?'}],
                    'functionSignature':{'parameters':[],'returns':[{'spelling':'String?'}]}}
            graph.write_text(json.dumps({'symbols':[symbol]}))
            catalog=SDKCatalog.from_symbolgraphs([graph],'Foundation')
            member=catalog.get('optionalDetail')
            self.assertTrue(member.optional_call)
            loaded=SDKCatalog.from_records([member.to_dict()])
            emitted=loaded.emit_call(member.id,receiver=Reference('value','Values'))
            self.assertEqual('String?',emitted.result_type)
            source=root/'Check.swift'
            source.write_text('''import Foundation
@objc protocol Values { @objc optional func detail() -> String? }
final class Empty:NSObject,Values {}
final class Present:NSObject,Values {
 let text:String?;init(_ value:String?) { text=value }
 @objc func detail() -> String? { text }
}
func read(_ value:Values) -> String? { return '''+emitted.expression+''' }
@main struct Main { static func main() {
 precondition(read(Empty()) == nil)
 precondition(read(Present(nil)) == nil)
 precondition(read(Present("native")) == "native")
 print("OPTIONAL_METHOD_PASSED")
}}
''')
            build=subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(source),'-o',str(root/'check')],text=True,capture_output=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(root/'check')],capture_output=True,text=True,timeout=15)
            self.assertEqual(0,run.returncode,run.stderr)
            self.assertIn('OPTIONAL_METHOD_PASSED',run.stdout)

    @unittest.skipUnless(shutil.which('xcrun'),'Apple Swift compiler required')
    def test_optional_method_existential_result_uses_valid_swift_syntax(self):
        from dcflight.platforms.ios_api import API
        member=API('named','Foundation',('Provider','named()'),'method',(),'any Named',(),(),optional_call=True)
        emitted=SDKCatalog([member]).emit_call('named',receiver=Reference('value','Provider'))
        self.assertEqual('(any Named)?',emitted.result_type)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'Check.swift'
            source.write_text("""import Foundation
@objc protocol Named { var text:String { get } }
final class Value:NSObject,Named { @objc var text:String { "native" } }
@objc protocol Provider { @objc optional func named() -> any Named }
final class Empty:NSObject,Provider {}
final class Present:NSObject,Provider { @objc func named() -> any Named { Value() } }
func read(_ value:Provider) -> (any Named)? { return """+emitted.expression+""" }
@main struct Main { static func main() {
 precondition(read(Empty()) == nil)
 precondition(read(Present())?.text == "native")
}}
""")
            built=subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(source),'-o',str(root/'check')],text=True,capture_output=True)
            self.assertEqual(0,built.returncode,built.stderr)
            run=subprocess.run([str(root/'check')],text=True,capture_output=True,timeout=15)
            self.assertEqual(0,run.returncode,run.stderr)
