import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import AndroidAPI, JavaValue

SDK = '''package java.util {
  public interface List<E> {
    method public E get(int);
    method public boolean add(E);
    method public int size();
  }
  public class ArrayList<E> implements java.util.List<E> {
  }
}
package sample {
  public class Box<T> {
    field public T value;
    method public <R extends T> R choose(R);
    method public <T> T shadow(T);
  }
  public class Child<U> extends sample.Box<java.util.List<U>> {
  }
  public class Strings extends java.util.ArrayList<java.lang.String> {
  }
  public class Bounded<T extends java.lang.CharSequence> {
    method public T get();
  }
}'''

class OwnerGenericsTests(unittest.TestCase):
    def setUp(self): self.api = AndroidAPI(SDK)

    def test_direct_and_inherited_owner_types(self):
        for owner in ('java.util.List<java.lang.String>', 'java.util.ArrayList<java.lang.String>', 'sample.Strings'):
            receiver = JavaValue.reference('values', owner)
            result = self.api.emit('java.util.List#get(int)', [JavaValue.literal(0)], receiver)
            self.assertEqual(result.java_type, 'java.lang.String')
            self.assertIn('java.util.List<java.lang.String>', result.source)
            self.api.emit('java.util.List#add(E)', [JavaValue.literal('hello')], receiver)
            with self.assertRaises(ValueError):
                self.api.emit('java.util.List#add(E)', [JavaValue.literal(4)], receiver)

    def test_fields_nested_substitution_and_method_shadowing(self):
        receiver = JavaValue.reference('child', 'sample.Child<java.lang.String>')
        value = JavaValue.reference('values', 'java.util.List<java.lang.String>')
        self.assertEqual(self.api.emit_set('sample.Box#value', value, receiver).java_type, value.java_type)
        box = JavaValue.reference('box', 'sample.Box<java.lang.CharSequence>')
        result = self.api.emit('sample.Box#choose(R)', [JavaValue.literal('hello')], box, ['java.lang.String'])
        self.assertEqual(result.java_type, 'java.lang.String')
        self.assertEqual(self.api.emit('sample.Box#shadow(T)', [JavaValue.literal(4)], box, ['java.lang.Integer']).java_type, 'java.lang.Integer')
        with self.assertRaisesRegex(ValueError, 'bound'):
            self.api.emit('sample.Box#choose(R)', [JavaValue.literal(4)], box, ['java.lang.Integer'])

    def test_independent_wildcard_member_and_collapsed_overloads(self):
        receiver = JavaValue.reference('values', 'java.util.List<?>')
        self.assertEqual(self.api.emit('java.util.List#size()', receiver=receiver).java_type, 'int')
        api = AndroidAPI('''package sample {
          public class Overloaded<T> {
            method public T pick(T);
            method public java.lang.String pick(java.lang.String);
          }
        }''')
        with self.assertRaisesRegex(ValueError, 'collapses'):
            api.emit('sample.Overloaded#pick(T)', [JavaValue.literal('x')], JavaValue.reference('value', 'sample.Overloaded<java.lang.String>'))
        with self.assertRaisesRegex(ValueError, 'count'):
            self.api.emit('sample.Box#value', receiver=JavaValue.reference('value', 'sample.Box<java.util.List<java.lang.String,java.lang.String>>'))

    def test_invalid_owner_types_fail_before_emission(self):
        for owner in ('java.util.List', 'java.util.List<?>', 'java.util.List<? extends java.lang.String>', 'java.util.List<java.lang.String,java.lang.String>'):
            with self.subTest(owner=owner), self.assertRaises(ValueError):
                self.api.emit('java.util.List#get(int)', [JavaValue.literal(0)], JavaValue.reference('values', owner))
        with self.assertRaisesRegex(ValueError, 'bound'):
            self.api.emit('sample.Bounded#get()', receiver=JavaValue.reference('box', 'sample.Bounded<java.lang.Integer>'))
        self.assertEqual(self.api.emit('sample.Bounded#get()', receiver=JavaValue.reference('box', 'sample.Bounded<java.lang.String>')).java_type, 'java.lang.String')

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_native_javac_and_execution(self):
        receiver = JavaValue.reference('values', 'java.util.ArrayList<java.lang.String>')
        add = self.api.emit('java.util.List#add(E)', [JavaValue.literal('native')], receiver).source
        get = self.api.emit('java.util.List#get(int)', [JavaValue.literal(0)], receiver).source
        box = JavaValue.reference('box', 'sample.Box<java.lang.CharSequence>')
        choose = self.api.emit('sample.Box#choose(R)', [JavaValue.literal('chosen')], box, ['java.lang.String']).source
        put = self.api.emit_set('sample.Box#value', JavaValue.literal('field'), box).source
        read = self.api.emit('sample.Box#value', receiver=box).source
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root/'sample').mkdir()
            (root/'sample/Box.java').write_text('package sample; public class Box<T> { public T value; public <R extends T> R choose(R x) { return x; } }')
            source = root/'Check.java'
            source.write_text('public class Check { public static void main(String[] args) { java.util.ArrayList<String> values = new java.util.ArrayList<>(); sample.Box<CharSequence> box = new sample.Box<>(); '+add+'; String first = '+get+'; String chosen = '+choose+'; '+put+'; CharSequence field = '+read+'; if (!first.equals("native") || !chosen.equals("chosen") || !field.equals("field")) throw new AssertionError(); System.out.print("PASS"); }}')
            build = subprocess.run(['javac', '-Xlint:unchecked', '-Werror', '-d', str(root), str(source), str(root/'sample/Box.java')], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run(['java', '-cp', str(root), 'Check'], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout, 'PASS')
