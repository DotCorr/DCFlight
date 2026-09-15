import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import AndroidAPI, JavaValue

SDK = '''package java.util {
 public interface Collection<E> {
 }
 public interface List<E> extends java.util.Collection<E> {
  method public boolean add(E);
  method public E get(int);
 }
 public class ArrayList<E> implements java.util.List<E> {
  ctor public ArrayList();
  ctor public ArrayList(java.util.Collection<? extends E>);
 }
}
package sample {
 public class Box<T extends java.lang.CharSequence> {
  ctor public Box(T);
  field public T value;
  method public static int number();
 }
 public abstract class Abstract<T> {
  ctor public Abstract();
 }
 public class Inner.Child<T> {
  ctor public Child();
 }
 class Hidden<T> {
  ctor public Hidden();
 }
 public class Generic<T> {
  ctor public <T> Generic(T);
  ctor public <R> Generic();
 }
 public class Overloaded<T> {
  ctor public Overloaded(T);
  ctor public Overloaded(java.lang.String);
 }
}'''

class TypedConstructorTests(unittest.TestCase):
    def setUp(self): self.api = AndroidAPI(SDK)

    def test_construct_and_use_typed_owner(self):
        owner = 'java.util.ArrayList<java.lang.String>'
        expression = self.api.emit('java.util.ArrayList#<init>()', constructed_type=owner)
        self.assertEqual(expression.java_type, owner)
        self.assertEqual(expression.source, 'new java.util.ArrayList<java.lang.String>()')
        receiver = JavaValue.reference('values', expression.java_type)
        self.assertEqual(self.api.emit('java.util.List#get(int)', [JavaValue.literal(0)], receiver).java_type, 'java.lang.String')
        box = self.api.emit('sample.Box#<init>(T)', [JavaValue.literal('value')], constructed_type='sample.Box<java.lang.String>')
        self.assertIn('(java.lang.String)', box.source)
        self.assertEqual(box.java_type, 'sample.Box<java.lang.String>')
        copy = self.api.emit('java.util.ArrayList#<init>(java.util.Collection<? extends E>)', [receiver], constructed_type=owner)
        self.assertIn('java.util.Collection<? extends java.lang.String>', copy.source)

    def test_reject_invalid_constructed_types_and_receivers(self):
        for value in ('java.util.ArrayList', 'java.util.ArrayList<?>', 'java.util.ArrayList<? extends java.lang.String>',
                      'java.util.ArrayList<int>', 'java.util.ArrayList<java.lang.String,java.lang.String>',
                      'java.util.List<java.lang.String>', 'java.util.ArrayList<java.lang.String>[]', 7):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.api.emit('java.util.ArrayList#<init>()', constructed_type=value)
        for member in ('sample.Box#value', 'sample.Box#number()', 'java.util.List#get(int)'):
            with self.subTest(member=member), self.assertRaises(ValueError):
                self.api.resolve_member(member, constructed_type='sample.Box<java.lang.String>')
        with self.assertRaisesRegex(ValueError, 'receiver'):
            self.api.resolve_member('java.util.ArrayList#<init>()', receiver_type='java.util.ArrayList<java.lang.String>', constructed_type='java.util.ArrayList<java.lang.String>')
        with self.assertRaisesRegex(ValueError, 'bound'):
            self.api.emit('sample.Box#<init>(T)', [JavaValue.literal(1)], constructed_type='sample.Box<java.lang.Integer>')
        with self.assertRaisesRegex(ValueError, 'Expected java.lang.String'):
            self.api.emit('sample.Box#<init>(T)', [JavaValue.literal(1)], constructed_type='sample.Box<java.lang.String>')

    def test_restrictions_survive_specialization(self):
        for member, owner in (('sample.Abstract#<init>()', 'sample.Abstract'), ('sample.Inner.Child#<init>()', 'sample.Inner.Child'), ('sample.Hidden#<init>()', 'sample.Hidden')):
            with self.subTest(member=member), self.assertRaises(ValueError):
                self.api.emit(member, constructed_type=owner+'<java.lang.String>')
        for member in ('sample.Generic#<init>(T)', 'sample.Generic#<init>()'):
            self.assertIn('generic constructor type parameters are unsupported', self.api.get(member).unsupported_reasons)
            with self.assertRaisesRegex(ValueError, 'generic constructor'):
                self.api.emit(member, constructed_type='sample.Generic<java.lang.String>')
        for member in ('sample.Overloaded#<init>(T)', 'sample.Overloaded#<init>(java.lang.String)'):
            with self.assertRaisesRegex(ValueError, 'collapses'):
                self.api.emit(member, [JavaValue.literal('x')], constructed_type='sample.Overloaded<java.lang.String>')
        self.assertEqual(self.api.emit('java.util.ArrayList#<init>()').source, 'new java.util.ArrayList()')

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_native_compilation_and_execution(self):
        owner = 'java.util.ArrayList<java.lang.String>'
        create = self.api.emit('java.util.ArrayList#<init>()', constructed_type=owner)
        receiver = JavaValue.reference('values', create.java_type)
        add = self.api.emit('java.util.List#add(E)', [JavaValue.literal('native')], receiver)
        copy = self.api.emit('java.util.ArrayList#<init>(java.util.Collection<? extends E>)', [receiver], constructed_type=owner)
        get = self.api.emit('java.util.List#get(int)', [JavaValue.literal(0)], JavaValue.reference('copied', copy.java_type))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); source = root/'Check.java'
            source.write_text('public class Check { public static void main(String[] args) { '+owner+' values = '+create.source+'; '+add.source+'; '+owner+' copied = '+copy.source+'; String result = '+get.source+'; if (!result.equals("native")) throw new AssertionError(); System.out.print("PASS"); }}')
            build = subprocess.run(['javac', '-Xlint:unchecked,rawtypes', '-Werror', '-d', str(root), str(source)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run(['java', '-cp', str(root), 'Check'], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout, 'PASS')
