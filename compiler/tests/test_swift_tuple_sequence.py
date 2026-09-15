import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.swift_types import parse_type, spelling
from dcflight.platforms.ios_api import SDKCatalog
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence


class SwiftTupleSequenceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('dart'),'Dart authoring SDK required')
    def test_dart_projection_matches_sequence_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'main.dart'
            library=Path(__file__).resolve().parents[1]/'authoring/lib/dcflight.dart'
            source.write_text("import 'dart:convert';\nimport '"+library.as_uri()+"';\nvoid main() { print(jsonEncode(const NativeTupleElement(NativeRef('pair'),index:1,bind:'status').toJson())); }")
            output=subprocess.check_output(['dart',str(source)],text=True)
            step=json.loads(output)
            self.assertEqual({'project':{'ref':'pair','index':1},'bind':'status'},step)
            result=emit_sequence(None,{'platform':'ios','inputs':[{'name':'pair','type':'(String, Int32)'}],'steps':[step]})
            self.assertEqual('Int32',result['bindings'][0]['type'])

    def test_tuple_grammar_and_projection_guards(self):
        shape='(data: [String], status: Int32)?'
        self.assertEqual(parse_type(shape),parse_type(spelling(parse_type(shape))))
        for invalid in ('(Int)', '(x: Int, x: String)', '(named: Int) -> Void'):
            with self.assertRaises(ValueError): parse_type(invalid)
        for typ,index in [('String',0),('(String, Int32)?',0),('(String, Int32)',2),('(String, Int32)',-1),('(String, Int32)',True)]:
            with self.assertRaises(ValueError):
                emit_sequence(None,{'platform':'ios','inputs':[{'name':'pair','type':typ}],
                    'steps':[{'project':{'ref':'pair','index':index},'bind':'selected'}]})
        with self.assertRaises(ValueError):
            emit_sequence(None,{'platform':'ios','steps':[{'project':{'ref':'future','index':0},'bind':'selected'}]})

    @unittest.skipUnless(shutil.which('xcrun'),'Swift toolchain required')
    def test_async_tuple_result_projected_and_executed_natively(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);source=root/'Fixture.swift'
            source.write_text('public enum Fixture { public static func fetch() async throws -> (data: String, status: Int32) { ("native", 200) } }')
            subprocess.run(['xcrun','swiftc','-emit-module','-module-name','Fixture',str(source),'-emit-module-path',str(root/'Fixture.swiftmodule')],check=True,capture_output=True)
            target=json.loads(subprocess.check_output(['xcrun','swiftc','-print-target-info'],text=True))['target']['triple']
            sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            subprocess.run(['xcrun','swift-symbolgraph-extract','-module-name','Fixture','-I',tmp,'-output-dir',tmp,'-sdk',sdk,'-target',target],check=True,capture_output=True)
            api=SDKCatalog.from_symbolgraphs([root/'Fixture.symbols.json'],'Fixture')
            member=next(a for a in api.apis.values() if a.path[-1]=='fetch()')
            self.assertFalse(member.unsupported)
            database=root/'api.db'
            with Catalog(database,write=True) as catalog:
                catalog.import_records('ios','Fixture','26.2',[member.to_dict()],{'fixture':True})
            request={'platform':'ios','allowAsync':True,'allowThrows':True,'steps':[
                {'id':member.id,'bind':'pair'},
                {'project':{'ref':'pair','index':0},'bind':'data'},
                {'project':{'ref':'pair','index':1},'bind':'status'}]}
            emitted=emit_sequence(NativeAPI(database),request)
            self.assertEqual([member.id],emitted['apiIds'])
            self.assertEqual(['(data: String, status: Int32)','String','Int32'],[b['type'] for b in emitted['bindings']])
            main=root/'Main.swift'
            main.write_text('@main struct Main { static func main() async throws {\n'+emitted['source']+'\nprecondition(dcfLocal1 == "native" && dcfLocal2 == 200)\n} }')
            subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(source),str(main),'-o',str(root/'verify')],check=True,capture_output=True)
            subprocess.run([str(root/'verify')],check=True,capture_output=True,timeout=15)
            request['allowAsync']=False
            with self.assertRaisesRegex(ValueError,'async/throws'): emit_sequence(NativeAPI(database),request)
