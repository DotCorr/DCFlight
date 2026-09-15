import json
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.platforms.ios_api import API,Parameter
from dcflight.native_operation import emit_operation,schema
from dcflight.compiler import compile_app
from dcflight.audit import audit


class TupleOperationIntegrationTests(unittest.TestCase):
    def test_tuple_projection_survives_shared_operation_and_app_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);database=root/'sdk.db';android=root/'android.txt'
            android.write_text('package java.lang {\n public class Integer {\n method public static int sum(int, int);\n }\n}\n')
            index_android(database,android)
            member=API('checked-add','Swift',('Int32','addingReportingOverflow(_:)'),'method',
                       (Parameter('_','rhs','Int32'),),'(partialValue: Int32, overflow: Bool)',(),())
            with Catalog(database,write=True) as catalog:
                catalog.import_records('ios','Swift','6',[member.to_dict()],{'fixture':'reviewed standard-library signature'})
            operation={'name':'wrappedAdd','execution':'main','parameters':[{'name':'a','type':'int'},{'name':'b','type':'int'}],'result':'int',
                'implementations':{'ios':{'steps':[{'id':'checked-add','receiver':{'ref':'a'},'arguments':[{'ref':'b'}],'bind':'pair'},
                    {'project':{'ref':'pair','index':0},'bind':'sum'}],'return':{'ref':'sum'}},
                'android':{'steps':[{'id':'java.lang.Integer#sum(int,int)','arguments':[{'ref':'a'},{'ref':'b'}],'bind':'sum'}],'return':{'ref':'sum'}}}}
            import jsonschema
            jsonschema.validate(operation,schema())
            result=emit_operation(NativeAPI(database),operation)
            if not shutil.which('dart'): self.skipTest('Dart authoring SDK required')
            dart_source=root/'operation.dart'
            dart_source.write_text("import 'package:dcflight_authoring/dcflight.dart';\n"+'''NativeOperation buildOperation() => const NativeOperation(
              name:'wrappedAdd',execution:NativeExecution.main,
              parameters:[NativeParameter('a',NativeScalar.int),NativeParameter('b',NativeScalar.int)],result:NativeScalar.int,
              ios:NativeImplementation(steps:[NativeCall('checked-add',receiver:NativeRef('a'),arguments:[NativeRef('b')],bind:'pair'),NativeTupleElement(NativeRef('pair'),index:0,bind:'sum')],result:NativeRef('sum')),
              android:NativeImplementation(steps:[NativeCall('java.lang.Integer#sum(int,int)',arguments:[NativeRef('a'),NativeRef('b')],bind:'sum')],result:NativeRef('sum')));
            ''')
            from dcflight.evaluated_frontend import load_evaluated_operation
            authored=load_evaluated_operation(dart_source,shutil.which('dart'))
            self.assertEqual(result,emit_operation(NativeAPI(database),authored))
            document={'version':2,'id':'com.example.tuple','name':'Tuple contract','state':{'answer':0,'phase':''},'sdkCatalog':str(database),
                'nativeOperations':[operation],'root':{'id':'nav','type':'navigationStack','props':{'initialRoute':'home'}},
                'routes':[{'id':'home','title':'Tuple','body':{'id':'label','type':'text','props':{'text':'Native operation'}}}],
                'initialAction':'calculate','flowActions':[
                    {'id':'calculate','cases':[{'code':0,'effects':[{'op':'nativeOperation','operation':'wrappedAdd','arguments':[20,22],'target':'answer','success':'accepted','failure':'rejected'}]}]},
                    {'id':'accepted','cases':[{'code':0,'effects':[{'op':'set','target':'phase','value':'done'}]}]},
                    {'id':'rejected','cases':[{'code':0,'effects':[{'op':'set','target':'phase','value':'failed'}]}]}]}
            compile_app(root/'app.json',root/'native',document=document)
            self.assertTrue(audit(root/'native')['passed'])
            swift=root/'native/ios/App/Generated/Operations/NativeOperation_wrappedAdd.swift'
            java=root/'native/android/app/src/main/java/com/example/tuple/NativeOperation_wrappedAdd.java'
            self.assertIn('`dcfLocal0`.0',swift.read_text())
            self.assertEqual(['checked-add'],result['targets']['ios']['apiIds'])
            if not shutil.which('javac') or not shutil.which('xcrun'): self.skipTest('Native toolchains required')
            main=root/'Main.swift';main.write_text('@main struct Main { @MainActor static func main() { precondition(NativeOperation_wrappedAdd.invoke(20,22)==42); precondition(NativeOperation_wrappedAdd.invoke(Int32.max,1)==Int32.min) } }')
            subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(swift),str(main),'-o',str(root/'verify')],check=True,capture_output=True)
            subprocess.run([str(root/'verify')],check=True,capture_output=True)
            check=root/'Check.java';check.write_text('class Check { public static void main(String[] args) { if(com.example.tuple.NativeOperation_wrappedAdd.invoke(20,22)!=42 || com.example.tuple.NativeOperation_wrappedAdd.invoke(Integer.MAX_VALUE,1)!=Integer.MIN_VALUE) throw new AssertionError(); } }')
            subprocess.run(['javac','-d',tmp,str(java),str(check)],check=True,capture_output=True)
            subprocess.run(['java','-cp',tmp,'Check'],check=True,capture_output=True)
