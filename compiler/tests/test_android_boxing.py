import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import AndroidAPI, JavaValue

CATALOG = '''package java.lang {
 public class Number {
 }
 public class Integer extends java.lang.Number {
 }
}
package sample {
 public class Calls {
  method public static java.lang.String object(java.lang.Object);
  method public static long wide(long);
  method public static java.lang.String boxed(java.lang.Integer);
  field public long value;
 }
}'''


class BoxingTests(unittest.TestCase):
    def test_boxing_unboxing_and_widening(self):
        api = AndroidAPI(CATALOG)
        for actual, expected in [('int','java.lang.Integer'), ('int','java.lang.Object'),
                                 ('int','java.lang.Number'), ('java.lang.Integer','int'),
                                 ('java.lang.Integer','long'), ('java.lang.Character','double'),
                                 ('boolean','java.lang.Boolean'), ('java.lang.Boolean','boolean')]:
            with self.subTest(actual=actual, expected=expected):
                self.assertTrue(api.is_assignable(actual, expected))
        for actual, expected in [('int','java.lang.Long'), ('java.lang.Long','int'),
                                 ('java.lang.Integer','java.lang.Long'), ('java.lang.Object','int'),
                                 ('boolean','int'), ('java.lang.Boolean','long'),
                                 ('int[]','java.lang.Integer[]'), ('java.lang.Integer[]','long[]')]:
            with self.subTest(actual=actual, expected=expected):
                self.assertFalse(api.is_assignable(actual, expected))

    def test_explicit_null_cannot_be_unboxed(self):
        api = AndroidAPI(CATALOG)
        null = JavaValue('null', None, 'java.lang.Integer')
        with self.assertRaisesRegex(ValueError, 'explicit null'):
            api.emit('sample.Calls#wide(long)', [null])
        with self.assertRaisesRegex(ValueError, 'explicit null'):
            api.emit_set('sample.Calls#value', null, JavaValue.reference('target','sample.Calls'))

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_native_conversions_preserve_selected_overload(self):
        api = AndroidAPI(CATALOG)
        integer = JavaValue.reference('integer', 'int')
        wrapper = JavaValue.reference('wrapper', 'java.lang.Integer')
        boxed = api.emit('sample.Calls#boxed(java.lang.Integer)', [integer]).source
        obj = api.emit('sample.Calls#object(java.lang.Object)', [integer]).source
        wide = api.emit('sample.Calls#wide(long)', [wrapper]).source
        assignment = api.emit_set('sample.Calls#value', wrapper, JavaValue.reference('target','sample.Calls')).source
        source = '''package sample;
class Calls {
 public long value;
 public static String boxed(Integer value) { return "boxed:"+value; }
 public static String boxed(int value) { throw new AssertionError("wrong overload"); }
 public static String object(Object value) { return value.getClass().getName(); }
 public static String object(int value) { throw new AssertionError("wrong overload"); }
 public static long wide(long value) { return value; }
 public static long wide(Integer value) { throw new AssertionError("wrong overload"); }
}
public class Main { public static void main(String[] args) {
 int integer=42; Integer wrapper=Integer.valueOf(-2147483648); Calls target=new Calls();
 if (!"boxed:42".equals(BOXED)) throw new AssertionError();
 if (!"java.lang.Integer".equals(OBJECT)) throw new AssertionError();
 if (WIDE != -2147483648L) throw new AssertionError();
 ASSIGNMENT;
 if (target.value != -2147483648L) throw new AssertionError();
} }
'''.replace('BOXED',boxed).replace('OBJECT',obj).replace('WIDE',wide).replace('ASSIGNMENT',assignment)
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); path=root/'Main.java'; path.write_text(source)
            build=subprocess.run(['javac','-Xlint:unchecked','-Werror','-d',str(root),str(path)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run(['java','-cp',str(root),'sample.Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
