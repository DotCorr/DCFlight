from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.android_api import AndroidAPI,JavaValue,_safe_type

CATALOG='''package java.util {
 public interface Collection<E> {
 }
 public interface List<E> extends java.util.Collection<E> {
 }
 public class ArrayList<E> implements java.util.List<E> {
 }
 public class Collections {
  method public static int frequency(java.util.Collection<?>, java.lang.Object);
 }
}
package sample {
 public class StringList extends java.util.ArrayList<java.lang.String> {
 }
 public class NamedStringList extends sample.StringList {
 }
 public class RawList extends java.util.ArrayList {
 }
 public class Pair<K,V> implements java.util.List<V> {
 }
 public class Nested<T> extends sample.Pair<java.lang.String,java.util.List<T>> {
 }
 public class Loop<T> extends sample.Loop<T> {
 }
}'''


class GenericInheritanceTests(unittest.TestCase):
    def test_fixed_parent_arguments_without_generic_owner(self):
        api=AndroidAPI(CATALOG)
        for actual in ('sample.StringList','sample.NamedStringList'):
            for expected in ('java.util.List<java.lang.String>','java.util.Collection<?>','java.util.Collection<? extends java.lang.CharSequence>'):
                with self.subTest(actual=actual,expected=expected):
                    self.assertTrue(api.is_assignable(actual,expected))
            self.assertFalse(api.is_assignable(actual,'java.util.List<java.lang.Integer>'))
        for actual in ('sample.RawList','java.util.ArrayList','sample.StringList<java.lang.String>'):
            with self.subTest(actual=actual):
                self.assertFalse(api.is_assignable(actual,'java.util.List<java.lang.String>'))

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'JDK required')
    def test_fixed_parent_native_call_without_unchecked_conversion(self):
        api=AndroidAPI(CATALOG)
        call=api.emit('java.util.Collections#frequency(java.util.Collection<?>,java.lang.Object)',[JavaValue.reference('items','sample.StringList'),JavaValue.reference('needle','java.lang.String')]).source
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);path=root/'Main.java'
            path.write_text('package sample; class StringList extends java.util.ArrayList<String> {} public class Main { public static void main(String[] args) { StringList items=new StringList(); items.add("yes"); items.add("no"); items.add("yes"); String needle="yes"; int count='+call+'; if(count!=2)throw new AssertionError(count); } }')
            build=subprocess.run(['javac','-Xlint:unchecked','-Werror','-d',str(root),str(path)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run(['java','-cp',str(root),'sample.Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)

    def test_declared_parent_arguments_and_invariance(self):
        api=AndroidAPI(CATALOG)
        for actual,expected in [
            ('java.util.ArrayList<java.lang.String>','java.util.List<java.lang.String>'),
            ('java.util.ArrayList<java.lang.String>','java.util.Collection<?>'),
            ('java.util.ArrayList<java.lang.String>','java.util.Collection<? extends java.lang.CharSequence>'),
            ('sample.Pair<java.lang.String,java.lang.Integer>','java.util.List<java.lang.Integer>'),
            ('sample.Nested<java.lang.String>','java.util.Collection<java.util.List<java.lang.String>>')]:
            with self.subTest(actual=actual,expected=expected):self.assertTrue(api.is_assignable(actual,expected))
        for actual,expected in [
            ('java.util.ArrayList<java.lang.String>','java.util.List<java.lang.Object>'),
            ('java.util.ArrayList<java.lang.String>','java.util.Collection<java.lang.Integer>'),
            ('sample.Pair<java.lang.String,java.lang.Integer>','java.util.List<java.lang.String>'),
            ('sample.Unknown<java.lang.String>','java.util.List<java.lang.String>'),
            ('sample.Loop<java.lang.String>','java.util.List<java.lang.String>')]:
            with self.subTest(actual=actual,expected=expected):self.assertFalse(api.is_assignable(actual,expected))
        self.assertFalse(_safe_type('java.util.List<'*1000+'java.lang.String'+'>'*1000))

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'JDK required')
    def test_native_collection_call_preserves_generic_interface(self):
        api=AndroidAPI(CATALOG)
        call=api.emit('java.util.Collections#frequency(java.util.Collection<?>,java.lang.Object)',[JavaValue.reference('items','java.util.ArrayList<java.lang.String>'),JavaValue.reference('needle','java.lang.String')]).source
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);path=root/'Main.java'
            path.write_text('public class Main { public static void main(String[] args) { java.util.ArrayList<String> items=new java.util.ArrayList<>(); items.add("yes"); items.add("no"); items.add("yes"); String needle="yes"; int count='+call+'; if(count!=2)throw new AssertionError(count); } }')
            build=subprocess.run(['javac','-Xlint:unchecked','-Werror',str(path)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
