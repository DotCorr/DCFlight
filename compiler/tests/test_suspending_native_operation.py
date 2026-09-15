from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_operation import emit_operation,lower_contract,schema
from dcflight.platforms.ios_api import API,Parameter


class SuspendingOperationTests(unittest.TestCase):
    def fixture(self, root):
        sdk=root/'api.txt'
        sdk.write_text('package sample {\n public class Native {\n method public static String echo(String);\n }\n}')
        db=root/'api.sqlite';index_android(db,sdk)
        record=API('echo','Fixture',('Native','echo(_:)'),'static_method',
                   (Parameter('_','input','String'),),'String',(),(),async_=True,throws=True)
        with Catalog(db,write=True) as catalog:catalog.import_records('ios','Fixture','test',[record.to_dict()],{'fixture':True})
        operation={'name':'echo','parameters':[{'name':'input','type':'string'}],'result':'string',
                   'execution':'worker','suspends':True,'throws':True,'implementations':{
                       'ios':{'steps':[{'id':'echo','arguments':[{'ref':'input'}],'bind':'result'}],'return':{'ref':'result'}},
                       'android':{'steps':[{'id':'sample.Native#echo(java.lang.String)','arguments':[{'ref':'input'}],'bind':'result'}],'return':{'ref':'result'}}}}
        return NativeAPI(db),operation

    def test_contract_schema_and_native_shapes(self):
        import jsonschema
        with tempfile.TemporaryDirectory() as folder:
            api,operation=self.fixture(Path(folder));jsonschema.validate(operation,schema())
            for execution in ('caller','main','worker'):
                operation['execution']=execution
                output=emit_operation(api,operation)
                self.assertTrue(lower_contract(operation).suspends)
                self.assertEqual('async',output['targets']['ios']['invocation'])
                self.assertEqual('sync',output['targets']['android']['invocation'])
                self.assertIn('async throws -> String',output['targets']['ios']['source'])
                self.assertIn('try await',output['targets']['ios']['source'])
                self.assertEqual(execution=='main','@MainActor' in output['targets']['ios']['source'])
            for invalid in ('true',1,None):
                operation['suspends']=invalid
                with self.assertRaises(ValueError):lower_contract(operation)
            operation['suspends']=False
            with self.assertRaises(ValueError):emit_operation(api,operation)
            operation['suspends']=True;operation['throws']=False
            with self.assertRaises(ValueError):emit_operation(api,operation)

    @unittest.skipUnless(shutil.which('xcrun'),'Swift toolchain required')
    def test_emitted_async_wrapper_executes_with_native_suspension_and_error(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);api,operation=self.fixture(root)
            fixture=root/'Fixture.swift';fixture.write_text('''import Foundation
public enum Native {
 public static func echo(_ input:String) async throws -> String {
  try await Task.sleep(nanoseconds:1_000_000)
  if input == "fail" { throw NSError(domain:"fixture",code:1) }
  return input
 }
}
''')
            subprocess.run(['xcrun','swiftc','-swift-version','6','-emit-library','-emit-module','-module-name','Fixture',str(fixture),'-o',str(root/'libFixture.dylib'),'-emit-module-path',str(root/'Fixture.swiftmodule')],check=True,capture_output=True)
            source=root/'Operation.swift';source.write_text(emit_operation(api,operation)['targets']['ios']['source'])
            runner=root/'Runner.swift';runner.write_text('''@main struct Runner {
 static func main() async throws {
  let result = try await NativeOperation_echo.invoke("snapshot")
  precondition(result == "snapshot")
  var failed=false
  do { _ = try await NativeOperation_echo.invoke("fail") } catch { failed=true }
  precondition(failed)
 }
}
''')
            binary=root/'check'
            subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library','-I',folder,'-L',folder,'-lFixture','-Xlinker','-rpath','-Xlinker',folder,str(source),str(runner),'-o',str(binary)],check=True,capture_output=True)
            subprocess.run([str(binary)],check=True,capture_output=True,timeout=15)

    def test_evaluated_dart_suspension_contract(self):
        from dcflight.evaluated_frontend import load_evaluated_operation
        dart=shutil.which('dart')
        if not dart:self.skipTest('Dart SDK required')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);api,operation=self.fixture(root)
            source=root/'operation.dart';source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeImplementation body(String id) => NativeImplementation(steps:[NativeCall(id,arguments:[NativeRef('input')],bind:'result')],result:NativeRef('result'));
NativeOperation buildOperation() => NativeOperation(name:'echo',parameters:[NativeParameter('input',NativeScalar.string)],result:NativeScalar.string,throwsErrors:true,suspends:true,execution:NativeExecution.worker,ios:body('echo'),android:body('sample.Native#echo(java.lang.String)'));
""")
            document=load_evaluated_operation(source,dart)
            self.assertTrue(document['suspends'])
            self.assertEqual(emit_operation(api,operation),emit_operation(api,document))
