import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.android_api import JavaValue
from dcflight.native_api import NativeAPI, index_android


class AndroidArrayLiteralTests(unittest.TestCase):
    def test_array_types_bounds_and_injection(self):
        for value, typ in [([True], 'int[]'), ([128], 'byte[]'), ([None], 'int[]'),
                           ([2**63], 'long[]'), ([float('nan')], 'double[]'),
                           (['source();'], 'int[]'), ([1], 'java.util.List<java.lang.Integer>[]'),
                           (['😀'], 'char[]'), ([1]*4096, 'int[]')]:
            with self.assertRaises(ValueError): JavaValue.array(value,typ)
        self.assertEqual('new int[][] {new int[] {1}, null}', JavaValue.array([[1],None],'int[][]').source())
        values = [1,2]; literal = JavaValue.array(values,'int[]'); values.append(3)
        self.assertEqual('new int[] {1, 2}',literal.source())

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'Java toolchain required')
    def test_native_api_arrays_compile_and_execute(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); source=root/'sdk.txt'; db=root/'sdk.db'
            source.write_text('''package java.util {
              public class Arrays {
                method public static String toString(int[]);
                method public static String deepToString(java.lang.Object[]);
              }
            }
            package demo {
              public class Holder {
                field public static byte[] bytes;
              }
            }
            ''')
            index_android(db,source); api=NativeAPI(db)
            call=api.emit({'platform':'android','id':'java.util.Arrays#toString(int[])','arguments':[{'literal':[1,2,3]}]})['source']
            nested=api.emit({'platform':'android','id':'java.util.Arrays#deepToString(java.lang.Object[])',
                             'arguments':[{'array':[[1,2],None],'type':'int[][]'}]})['source']
            with self.assertRaises(ValueError):
                api.emit({'platform':'android','id':'java.util.Arrays#deepToString(java.lang.Object[])',
                          'arguments':[{'array':[1,2],'type':'int[]'}]})
            assignment=api.emit({'platform':'android','id':'demo.Holder#bytes','set':{'literal':[-128,127]}})['source']
            package=root/'demo';package.mkdir();holder=package/'Holder.java'
            holder.write_text('package demo; public class Holder { public static byte[] bytes; }')
            expressions=[JavaValue.array(v,t).source() for v,t in [
                ([[-1,2],None],'int[][]'), ([-2**63,2**63-1],'long[]'),
                ([1e-50,3.0],'float[]'), (['a','\n'],'char[]'),
                (['hello',None,'😀'],'java.lang.String[]')]]
            main=root/'Main.java'
            main.write_text('public class Main { public static void main(String[] args) {\n'
                +'if (!"[1, 2, 3]".equals('+call+')) throw new AssertionError();\n'
                +'if (!"[[1, 2], null]".equals('+nested+')) throw new AssertionError();\n'
                +assignment+'; if (demo.Holder.bytes[0] != -128) throw new AssertionError();\n'
                +'Object[] arrays = new Object[] {'+', '.join(expressions)+'};\n'
                +'if (((int[][])arrays[0])[1] != null || ((long[])arrays[1])[1] != Long.MAX_VALUE || ((float[])arrays[2])[0] != 0 || ((char[])arrays[3])[1] != 10 || !"😀".equals(((String[])arrays[4])[2])) throw new AssertionError();\n'
                +'} }')
            subprocess.run(['javac',str(holder),str(main)],check=True,capture_output=True)
            subprocess.run(['java','-cp',tmp,'Main'],check=True,capture_output=True,timeout=15)

    @unittest.skipUnless(shutil.which('dart'), 'Dart toolchain required')
    def test_dart_typed_array_authoring(self):
        library=(Path(__file__).parents[1]/'authoring/lib/dcflight.dart').as_uri()
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'value.dart'
            source.write_text("import 'dart:convert';\nimport '"+library+"';\nvoid main() { print(jsonEncode(const NativeArray([[1,2], null], type:'int[][]').toJson())); }\n")
            result=subprocess.check_output(['dart',str(source)],text=True)
            self.assertEqual({'array':[[1,2],None],'type':'int[][]'},json.loads(result))
