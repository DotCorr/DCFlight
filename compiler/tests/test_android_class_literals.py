import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import JavaValue
from dcflight.native_api import NativeAPI,index_android


class ClassLiteralTests(unittest.TestCase):
    def test_structured_class_types_and_invalid_forms(self):
        for name, expected in [('String','java.lang.String'),('int','java.lang.Integer'),
                               ('void','java.lang.Void'),('int[]','int[]'),('String[][]','java.lang.String[][]')]:
            with self.subTest(name=name):
                self.assertEqual('java.lang.Class<'+expected+'>',JavaValue.class_literal(name).java_type)
        for name in ('java.util.List<java.lang.String>','T','void[]','java.lang.String;run()',None):
            with self.subTest(name=name),self.assertRaises(ValueError):JavaValue.class_literal(name)
        with self.assertRaises(ValueError):JavaValue('class','java.lang.String','java.lang.Class<java.lang.Integer>')

    def test_catalog_generic_class_parameter(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'api.txt';source.write_text('''package sample {
 public class Calls {
  method public static <T> T value(java.lang.Class<T>);
 }
}''')
            db=root/'api.sqlite';index_android(db,source)
            result=NativeAPI(db).emit({'platform':'android','id':'sample.Calls#value(java.lang.Class<T>)','typeArguments':['java.lang.String'],'arguments':[{'class':'java.lang.String'}]})
            self.assertEqual('java.lang.String',result['resultType'])
            self.assertIn('(java.lang.Class<java.lang.String>) (java.lang.String.class)',result['source'])

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'JDK required')
    def test_native_class_literals_preserve_exact_types(self):
        names=('java.lang.String','boolean','byte','char','short','int','long','float','double','void','int[]','java.lang.String[][]')
        lines=[]
        for index,name in enumerate(names):
            value=JavaValue.class_literal(name)
            lines.append(value.java_type+' value'+str(index)+'='+value.source()+'; if(value'+str(index)+' != '+name+'.class) throw new AssertionError();')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'Main.java';source.write_text('public class Main { public static void main(String[] args) { '+' '.join(lines)+' } }')
            result=subprocess.run(['javac','-Xlint:unchecked','-Werror',str(source)],capture_output=True,text=True)
            self.assertEqual(0,result.returncode,result.stderr)
            result=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,result.returncode,result.stderr)
