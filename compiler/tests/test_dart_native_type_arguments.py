import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import jsonschema
from dcflight.evaluated_frontend import load_evaluated_operation
from dcflight.native_operation import schema,emit_operation
from dcflight.native_api import NativeAPI,index_android
from dcflight.catalog import Catalog
from dcflight.platforms.ios_api import API


class DartNativeTypeArgumentsTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('dart') and shutil.which('javac') and shutil.which('java'),'Dart and JDK required')
    def test_evaluated_dart_generic_class_argument_reaches_native_operation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'operation.dart'
            source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeOperation buildOperation() => NativeOperation(
 name:'typeName',result:NativeScalar.string,
 ios:NativeImplementation(steps:[NativeCall('fixtureName',bind:'text')],result:NativeRef('text')),
 android:NativeImplementation(steps:[NativeCall('sample.Calls#name(java.lang.Class<T>)',
   typeArguments:['java.lang.String'],arguments:[NativeClass('java.lang.String')],bind:'text')],result:NativeRef('text')));
""")
            document=load_evaluated_operation(source,shutil.which('dart'))
            jsonschema.validate(document,schema())
            step=document['implementations']['android']['steps'][0]
            self.assertEqual(['java.lang.String'],step['typeArguments'])
            self.assertEqual([{'class':'java.lang.String'}],step['arguments'])
            sdk=root/'sdk.txt';sdk.write_text('''package sample {
 public class Calls {
  method public static <T> java.lang.String name(java.lang.Class<T>);
 }
}''')
            db=root/'sdk.sqlite';index_android(db,sdk)
            record=API('fixtureName','Fixture',('Fixture','name()'),'static_method',(),'String',(),()).to_dict()
            with Catalog(db,write=True) as catalog:catalog.import_records('ios','Fixture','26.2',[record],{'fixture':True})
            emitted=emit_operation(NativeAPI(db),document)
            target=emitted['targets']['android'];native=root/target['fileName'];native.write_text(target['source'])
            self.assertIn('.<java.lang.String>name((java.lang.Class<java.lang.String>) (java.lang.String.class))',target['source'])
            self.assertIsNone(emitted['compilerRuntimeDependency'])
            calls=root/'Calls.java';calls.write_text('package sample; public class Calls { public static <T> String name(Class<T> type) { return type.getName(); } }')
            main=root/'Main.java';main.write_text('public class Main { public static void main(String[] args) { if(!NativeOperation_typeName.invoke().equals("java.lang.String")) throw new AssertionError(); } }')
            result=subprocess.run(['javac','-Xlint:unchecked','-Werror','-d',str(root),str(calls),str(native),str(main)],capture_output=True,text=True)
            self.assertEqual(0,result.returncode,result.stderr)
            result=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,result.returncode,result.stderr)
            step['typeArguments']=[]
            with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(document,schema())
