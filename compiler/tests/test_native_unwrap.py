import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.native_sequence import emit_sequence


class NativeUnwrapTests(unittest.TestCase):
    def test_android_null_guard_requires_reference_and_failure_context(self):
        request={'platform':'android','allowThrows':True,'inputs':[{'name':'value','type':'java.lang.String'}],
                 'steps':[{'unwrap':{'ref':'value'},'bind':'present','message':'Missing value'}]}
        result=emit_sequence(None,request)
        self.assertEqual('java.lang.String',result['bindings'][0]['type'])
        self.assertIn('IllegalStateException',result['source'])
        request['inputs'][0]['type']='int'
        with self.assertRaisesRegex(ValueError,'reference type'): emit_sequence(None,request)
        request['inputs'][0]['type']='java.lang.String';request['allowThrows']=False
        with self.assertRaisesRegex(ValueError,'throws context'): emit_sequence(None,request)

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'Java toolchain required')
    def test_android_null_failure_and_value_success_execute(self):
        message='Missing "value"\ntry again'
        request={'platform':'android','allowThrows':True,'inputs':[{'name':'value','type':'java.lang.String'}],
                 'steps':[{'unwrap':{'ref':'value'},'bind':'present','message':message}]}
        emitted=emit_sequence(None,request)
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'Check.java'
            source.write_text('class Check { static String select(String value) {\n'+emitted['source']+'\nreturn dcfLocal0; }\npublic static void main(String[] args) {\n'
                +'if (!"native".equals(select("native"))) throw new AssertionError();\n'
                +'try { select(null); throw new AssertionError("null accepted"); } catch (IllegalStateException e) { if (!'+json.dumps(message)+'.equals(e.getMessage())) throw new AssertionError(); }\n} }')
            subprocess.run(['javac',str(source)],check=True,capture_output=True)
            subprocess.run(['java','-cp',tmp,'Check'],check=True,capture_output=True,timeout=15)

    def request(self,typ='(String, Int32)?'):
        return {'platform':'ios','allowThrows':True,'inputs':[{'name':'value','type':typ}],
                'steps':[{'unwrap':{'ref':'value'},'bind':'pair','message':'Missing "value"\ntry again'},
                         {'project':{'ref':'pair','index':0},'bind':'text'}]}

    def test_invalid_unwrap_context_and_type_rejected(self):
        for change in [lambda r:r.update(allowThrows=False),lambda r:r.update(allowThrows=1),
                       lambda r:r['inputs'][0].update(type='(String, Int32)'),
                       lambda r:r['steps'][0].update(unwrap={'ref':'missing'}),
                       lambda r:r['steps'][0].update(message='x'*4097),
                       lambda r:r['steps'][0].update(message='\ud800')]:
            request=self.request();change(request)
            with self.assertRaises(ValueError):emit_sequence(None,request)

    @unittest.skipUnless(shutil.which('xcrun'),'Swift toolchain required')
    def test_native_nil_failure_and_tuple_success(self):
        emitted=emit_sequence(None,self.request())
        self.assertEqual(['(String, Int32)','String'],[b['type'] for b in emitted['bindings']])
        self.assertEqual([],emitted['apiIds'])
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'main.swift'
            source.write_text('import Foundation\nfunc select(_ value:(String, Int32)?) throws -> String {\n'+emitted['source']+'\nreturn dcfLocal1\n}\n'+'''
            precondition(try! select(("native",200)) == "native")
            do { _ = try select(nil); fatalError("nil accepted") }
            catch { let value = error as NSError; precondition(value.domain == "NativeValue" && value.code == 1 && value.localizedDescription == "Missing \\\"value\\\"\\ntry again") }
            ''')
            binary=Path(tmp)/'verify'
            subprocess.run(['xcrun','swiftc','-swift-version','6',str(source),'-o',str(binary)],check=True,capture_output=True)
            subprocess.run([str(binary)],check=True,capture_output=True,timeout=15)

    @unittest.skipUnless(shutil.which('dart'),'Dart SDK required')
    def test_dart_unwrap_matches_closed_json_form(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'main.dart';library=Path(__file__).resolve().parents[1]/'authoring/lib/dcflight.dart'
            source.write_text("import 'dart:convert';\nimport '"+library.as_uri()+"';\nvoid main() { print(jsonEncode(const NativeUnwrap(NativeRef('url'),bind:'validURL',message:'Invalid URL').toJson())); }")
            value=json.loads(subprocess.check_output(['dart',str(source)],text=True))
            self.assertEqual({'unwrap':{'ref':'url'},'bind':'validURL','message':'Invalid URL'},value)
