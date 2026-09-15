import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import jsonschema
from dcflight.evaluated_frontend import load_evaluated_operation
from dcflight.native_operation import schema, emit_operation
from dcflight.native_api import NativeAPI, index_android
from dcflight.catalog import Catalog
from dcflight.platforms.ios_api import API

SDK = '''package java.util {
 public class ArrayList<E> {
  ctor public ArrayList();
  method public boolean add(E);
  method public E get(int);
 }
}'''


class DartTypedConstructorTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('dart') and shutil.which('javac') and shutil.which('java'),'Dart and JDK required')
    def test_dart_constructs_typed_object_and_native_operation_executes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'operation.dart'
            source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeOperation buildOperation() => NativeOperation(
 name:'typedCollection',result:NativeScalar.string,
 ios:NativeImplementation(steps:[NativeCall('fixtureName',bind:'text')],result:NativeRef('text')),
 android:NativeImplementation(steps:[
   NativeCall('java.util.ArrayList#<init>()',constructedType:'java.util.ArrayList<java.lang.String>',bind:'items'),
   NativeCall('java.util.ArrayList#add(E)',receiver:NativeRef('items'),arguments:[NativeLiteral('typed native value')]),
   NativeCall('java.util.ArrayList#get(int)',receiver:NativeRef('items'),arguments:[NativeLiteral(0)],bind:'text')
 ],result:NativeRef('text')));
""")
            document=load_evaluated_operation(source,shutil.which('dart'))
            jsonschema.validate(document,schema())
            step=document['implementations']['android']['steps'][0]
            self.assertEqual('java.util.ArrayList<java.lang.String>',step['constructedType'])
            sdk=root/'sdk.txt';sdk.write_text(SDK);db=root/'sdk.sqlite';index_android(db,sdk)
            record=API('fixtureName','Fixture',('Fixture','name()'),'static_method',(),'String',(),()).to_dict()
            with Catalog(db,write=True) as catalog:catalog.import_records('ios','Fixture','26.2',[record],{'fixture':True})
            emitted=emit_operation(NativeAPI(db),document)
            target=emitted['targets']['android'];native=root/target['fileName'];native.write_text(target['source'])
            self.assertIn('new java.util.ArrayList<java.lang.String>()',target['source'])
            self.assertIsNone(emitted['compilerRuntimeDependency'])
            main=root/'Main.java';main.write_text('public class Main { public static void main(String[] args) { if(!NativeOperation_typedCollection.invoke().equals("typed native value")) throw new AssertionError(); } }')
            compiled=subprocess.run(['javac','-Xlint:unchecked','-Werror','-d',str(root),str(native),str(main)],capture_output=True,text=True)
            self.assertEqual(0,compiled.returncode,compiled.stderr)
            run=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
            step['constructedType']=None
            with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(document,schema())

    def test_catalog_constructor_options_reject_invalid_combinations(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);sdk=root/'sdk.txt';sdk.write_text(SDK);db=root/'sdk.sqlite';index_android(db,sdk);api=NativeAPI(db)
            request={'platform':'android','id':'java.util.ArrayList#<init>()','constructedType':'java.util.ArrayList<java.lang.String>'}
            self.assertEqual('java.util.ArrayList<java.lang.String>',api.emit(request)['resultType'])
            for patch in ({'constructedType':None},{'constructedType':'java.util.ArrayList<?>'},
                          {'receiver':{'ref':'items','type':'java.util.ArrayList<java.lang.String>'}},
                          {'set':{'literal':'no'}},{'id':'java.util.ArrayList#get(int)','arguments':[{'literal':0}]}):
                with self.subTest(patch=patch),self.assertRaises(ValueError):api.emit({**request,**patch})
