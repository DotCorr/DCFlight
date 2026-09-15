from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.android_api import AndroidAPI, JavaValue


class AndroidWideningTests(unittest.TestCase):
    def test_scalar_widening_and_boxing_do_not_convert_array_elements(self):
        api=AndroidAPI('')
        allowed={'byte':{'short','int','long','float','double'},
                 'short':{'int','long','float','double'},'char':{'int','long','float','double'},
                 'int':{'long','float','double'},'long':{'float','double'},'float':{'double'}}
        for actual in ('byte','short','char','int','long','float','double','boolean'):
            for expected in ('byte','short','char','int','long','float','double','boolean'):
                with self.subTest(actual=actual,expected=expected):
                    self.assertEqual(actual==expected or expected in allowed.get(actual,set()),api.is_assignable(actual,expected))
                    self.assertEqual(actual==expected,api.is_assignable(actual+'[]',expected+'[]'))
                    self.assertEqual(actual==expected,api.is_assignable(actual+'[][]',expected+'[][]'))
            self.assertTrue(api.is_assignable(actual,'java.lang.Object'))
            self.assertFalse(api.is_assignable(actual+'[]','java.lang.Object[]'))

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'Java toolchain required')
    def test_selected_long_overload_preserved_for_int_input(self):
        api=AndroidAPI('''package java.lang {
          public final class Math {
            method public static long abs(long);
          }
        }''')
        call=api.emit('java.lang.Math#abs(long)',[JavaValue.reference('value','int')]).source
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'Main.java'
            source.write_text('public class Main { public static void main(String[] args) { int value=Integer.MIN_VALUE; '
                              'long result='+call+'; if (result != 2147483648L) throw new AssertionError(result); } }')
            subprocess.run(['javac',str(source)],check=True,capture_output=True)
            subprocess.run(['java','-cp',directory,'Main'],check=True,capture_output=True)
