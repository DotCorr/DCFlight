import os
import shutil
import subprocess
import tempfile
import unittest
import uuid
import zipfile
from pathlib import Path

from dcflight.platforms.android_api import AndroidAPI, JavaValue


SDK = '''package sample {
 public class Plain {
  ctor public <T extends java.lang.CharSequence> Plain(T);
 }
 public class Box<T> {
  ctor public <T extends java.lang.CharSequence> Box(T);
 }
 public class Carrier<C> {
  ctor public <T extends C> Carrier(T);
 }
 public class Pair {
  ctor public <T extends java.lang.CharSequence, U extends T> Pair(T, U);
 }
 public class Empty {
  ctor public <T> Empty();
 }
 public class Ordinary {
  ctor public Ordinary();
 }
 public abstract class Abstract {
  ctor public <T> Abstract(T);
 }
 class Hidden {
  ctor public <T> Hidden(T);
 }
}'''


class GenericConstructorTests(unittest.TestCase):
    def setUp(self):
        self.api = AndroidAPI(SDK)

    def test_explicit_constructor_arguments_emit_native_java(self):
        result = self.api.emit('sample.Plain#<init>(T)', [JavaValue.literal('native')],
                               type_arguments=['java.lang.String'])
        self.assertEqual(result.java_type, 'sample.Plain')
        self.assertEqual(result.source,
                         'new <java.lang.String> sample.Plain((java.lang.String) ("native"))')
        empty = self.api.emit('sample.Empty#<init>()', type_arguments=['java.lang.String'])
        self.assertEqual(empty.source, 'new <java.lang.String> sample.Empty()')

    def test_constructor_variables_shadow_owner_variables(self):
        result = self.api.emit('sample.Box#<init>(T)', [JavaValue.literal('shadow')],
                               type_arguments=['java.lang.String'],
                               constructed_type='sample.Box<java.lang.Integer>')
        self.assertEqual(result.java_type, 'sample.Box<java.lang.Integer>')
        self.assertIn('new <java.lang.String> sample.Box<java.lang.Integer>', result.source)
        self.assertIn('(java.lang.String)', result.source)
        with self.assertRaises(ValueError):
            self.api.emit('sample.Box#<init>(T)',
                          [JavaValue.reference('number', 'java.lang.Integer')],
                          type_arguments=['java.lang.Integer'],
                          constructed_type='sample.Box<java.lang.String>')

    def test_bounds_can_reference_owner_and_constructor_parameters(self):
        result = self.api.emit('sample.Carrier#<init>(T)', [JavaValue.literal('bound')],
                               type_arguments=['java.lang.String'],
                               constructed_type='sample.Carrier<java.lang.CharSequence>')
        self.assertEqual(result.java_type, 'sample.Carrier<java.lang.CharSequence>')
        pair = self.api.emit('sample.Pair#<init>(T,U)',
                             [JavaValue.literal('a'), JavaValue.literal('b')],
                             type_arguments=['java.lang.CharSequence', 'java.lang.String'])
        self.assertIn('new <java.lang.CharSequence, java.lang.String> sample.Pair', pair.source)
        for owner in ('sample.Carrier<java.lang.Integer>', None):
            with self.subTest(owner=owner), self.assertRaises(ValueError):
                self.api.emit('sample.Carrier#<init>(T)', [JavaValue.literal('bad')],
                              type_arguments=['java.lang.String'], constructed_type=owner)
        with self.assertRaises(ValueError):
            self.api.emit('sample.Pair#<init>(T,U)',
                          [JavaValue.literal('a'), JavaValue.reference('number', 'java.lang.Integer')],
                          type_arguments=['java.lang.String', 'java.lang.Integer'])

    def test_invalid_arguments_and_existing_restrictions_stay_rejected(self):
        for types in (None, [], ['int'], ['?'], ['java.lang.String', 'java.lang.String'],
                      [7], 'java.lang.String', ['java.lang.Integer'], ['java.util.List<'],
                      ['java.lang.String; System.exit(1)'], ['java.lang.String'] * 33):
            with self.subTest(types=types), self.assertRaises(ValueError):
                self.api.emit('sample.Plain#<init>(T)', [JavaValue.literal('x')],
                              type_arguments=types)
        for member in ('sample.Abstract#<init>(T)', 'sample.Hidden#<init>(T)'):
            with self.subTest(member=member), self.assertRaises(ValueError):
                self.api.emit(member, [JavaValue.literal('x')], type_arguments=['java.lang.String'])
        with self.assertRaises(ValueError):
            self.api.emit('sample.Ordinary#<init>()', type_arguments=['java.lang.String'])
        with self.assertRaises(ValueError):
            self.api.emit('sample.Plain#<init>(T)', [JavaValue.literal('x')],
                          JavaValue.reference('receiver', 'sample.Plain'),
                          type_arguments=['java.lang.String'])

    def test_collapsed_generic_constructor_overloads_are_rejected(self):
        api = AndroidAPI('''package sample {
 public class Overloaded {
  ctor public <T> Overloaded(T);
  ctor public Overloaded(java.lang.String);
 }
 public class Crossed {
  ctor public <T> Crossed(T, java.lang.CharSequence);
  ctor public <U> Crossed(java.lang.CharSequence, U);
 }
}''')
        with self.assertRaisesRegex(ValueError, 'collapses'):
            api.emit('sample.Overloaded#<init>(T)', [JavaValue.literal('x')],
                     type_arguments=['java.lang.String'])
        for member in ('sample.Crossed#<init>(T,java.lang.CharSequence)',
                       'sample.Crossed#<init>(java.lang.CharSequence,U)'):
            with self.subTest(member=member), self.assertRaisesRegex(ValueError, 'collapses'):
                api.emit(member, [JavaValue.literal('a'), JavaValue.literal('b')],
                         type_arguments=['java.lang.CharSequence'])
        unrelated = api.emit('sample.Overloaded#<init>(T)',
                             [JavaValue.reference('number', 'java.lang.Integer')],
                             type_arguments=['java.lang.Integer'])
        self.assertIn('new <java.lang.Integer> sample.Overloaded', unrelated.source)

    def test_nested_bounds_substitute_every_type_argument(self):
        api = AndroidAPI('''package sample {
 public class Nested {
  ctor public <T, U extends java.util.List<T>> Nested(U);
 }
}''')
        result = api.emit('sample.Nested#<init>(U)',
                          [JavaValue.reference('items', 'java.util.List<java.lang.String>')],
                          type_arguments=['java.lang.String', 'java.util.List<java.lang.String>'])
        self.assertIn('(java.util.List<java.lang.String>)', result.source)
        with self.assertRaisesRegex(ValueError, 'bound'):
            api.emit('sample.Nested#<init>(U)',
                     [JavaValue.reference('items', 'java.util.List<java.lang.Integer>')],
                     type_arguments=['java.lang.String', 'java.util.List<java.lang.Integer>'])

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_varargs_overload_rejection_matches_native_compiler(self):
        api = AndroidAPI('''package sample {
 public class Variadic {
  ctor public <T> Variadic(java.util.List<T>, java.lang.String...);
  ctor public <V> Variadic(java.util.List<V>, V...);
 }
}''')
        member = 'sample.Variadic#<init>(java.util.List<T>,java.lang.String[])'
        with self.assertRaisesRegex(ValueError, 'overload may be ambiguous'):
            api.emit(member, [JavaValue.reference('items', 'java.util.List<java.lang.Object>'),
                              JavaValue.array([], 'java.lang.String[]')],
                     type_arguments=['java.lang.Object'])
        safe = api.emit(member, [JavaValue.reference('items', 'java.util.List<java.lang.Integer>'),
                                 JavaValue.array([], 'java.lang.String[]')],
                        type_arguments=['java.lang.Integer'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'sample').mkdir()
            fixture = root / 'sample' / 'Variadic.java'
            fixture.write_text('''package sample; public class Variadic {
 public final int selected;
 public <T> Variadic(java.util.List<T> x, String... y) { selected=1; }
 @SafeVarargs public <V> Variadic(java.util.List<V> x, V... y) { selected=2; }
}''')
            source = root / 'Check.java'
            source.write_text('public class Check { public static void main(String[] args) { '
                              'java.util.List<Integer> items = new java.util.ArrayList<Integer>(); '
                              f'sample.Variadic result = {safe.source}; '
                              'if (result.selected != 1) throw new AssertionError(); '
                              'System.out.print("PASS"); }}')
            build = subprocess.run(['javac', '-Xlint:unchecked,rawtypes', '-Werror', '-d', str(root),
                                    str(fixture), str(source)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run(['java', '-cp', str(root), 'Check'], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout, 'PASS')
            source.write_text('public class Check { public static void main(String[] args) { '
                              'new <Object> sample.Variadic((java.util.List<Object>) '
                              'new java.util.ArrayList<Object>(), (String[]) new String[] {}); }}')
            rejected = subprocess.run(['javac', '-XDrawDiagnostics', '-d', str(root),
                                       str(fixture), str(source)], capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn('compiler.err.ref.ambiguous', rejected.stderr)

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_generated_constructors_compile_and_execute_without_helpers(self):
        self._verify_generated_constructors()

    @unittest.skipUnless(os.environ.get('DCFLIGHT_ANDROID_SERIAL') and
                         os.environ.get('DCFLIGHT_ANDROID_SDK'),
                         'Explicit Android SDK and device serial required for ART execution')
    def test_generated_constructors_execute_on_android_art(self):
        self._verify_generated_constructors(android=True)

    def _verify_generated_constructors(self, android=False):
        plain = self.api.emit('sample.Plain#<init>(T)', [JavaValue.literal('native')],
                              type_arguments=['java.lang.String'])
        box = self.api.emit('sample.Box#<init>(T)', [JavaValue.literal('shadow')],
                            type_arguments=['java.lang.String'],
                            constructed_type='sample.Box<java.lang.Integer>')
        carrier = self.api.emit('sample.Carrier#<init>(T)', [JavaValue.literal('owner')],
                                type_arguments=['java.lang.String'],
                                constructed_type='sample.Carrier<java.lang.CharSequence>')
        pair = self.api.emit('sample.Pair#<init>(T,U)',
                             [JavaValue.literal('left'), JavaValue.literal('right')],
                             type_arguments=['java.lang.CharSequence', 'java.lang.String'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sample = root / 'sample'
            sample.mkdir()
            declarations = {
                'Plain': 'public class Plain { public final String value; public <T extends CharSequence> Plain(T x) { value=x.toString(); } }',
                'Box': 'public class Box<T> { public final String value; public <T extends CharSequence> Box(T x) { value=x.toString(); } }',
                'Carrier': 'public class Carrier<C> { public final C value; public <T extends C> Carrier(T x) { value=x; } }',
                'Pair': 'public class Pair { public final String value; public <T extends CharSequence, U extends T> Pair(T x, U y) { value=x.toString()+y.toString(); } }',
            }
            for name, declaration in declarations.items():
                (sample / (name + '.java')).write_text('package sample; ' + declaration)
            source = root / 'Check.java'
            source.write_text('public class Check { public static void main(String[] args) { '
                              f'{plain.java_type} p = {plain.source}; '
                              f'{box.java_type} b = {box.source}; '
                              f'{carrier.java_type} c = {carrier.source}; '
                              f'{pair.java_type} r = {pair.source}; '
                              'if (!p.value.equals("native") || !b.value.equals("shadow") || '
                              '!c.value.toString().equals("owner") || !r.value.equals("leftright")) '
                              'throw new AssertionError(); System.out.print("PASS"); }}')
            build = subprocess.run(['javac', '--release', '8', '-Xlint:unchecked,rawtypes', '-Werror', '-d', str(root),
                                    *map(str, sample.glob('*.java')), str(source)],
                                   capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run(['java', '-cp', str(root), 'Check'], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout, 'PASS')
            if android:
                self._execute_on_android(root)

    def _execute_on_android(self, root):
        sdk = Path(os.environ['DCFLIGHT_ANDROID_SDK'])
        serial = os.environ['DCFLIGHT_ANDROID_SERIAL']
        d8_candidates = sorted(sdk.glob('build-tools/*/d8'))
        self.assertTrue(d8_candidates, 'Android SDK has no d8 compiler')
        android_library = sdk / 'platforms/android-35/android.jar'
        self.assertTrue(android_library.is_file(), 'Android API 35 platform is required')
        dex = root / 'dex'
        dex.mkdir()
        convert = subprocess.run([str(d8_candidates[-1]), '--min-api', '26', '--lib',
                                  str(android_library), '--output', str(dex),
                                  *map(str, root.rglob('*.class'))], capture_output=True, text=True, timeout=120)
        self.assertEqual(convert.returncode, 0, convert.stderr)
        dex_files = list(dex.glob('*.dex'))
        self.assertTrue(dex_files, 'd8 produced no DEX output')
        archive = root / 'constructors.jar'
        with zipfile.ZipFile(archive, 'w') as jar:
            for path in dex_files:
                jar.write(path, path.name)
        adb = [str(sdk / 'platform-tools/adb'), '-s', serial]
        remote = '/data/local/tmp/dcflight-generic-' + uuid.uuid4().hex + '.jar'
        try:
            push = subprocess.run([*adb, 'push', str(archive), remote], capture_output=True, text=True, timeout=60)
            self.assertEqual(push.returncode, 0, push.stderr)
            execute = subprocess.run([*adb, 'shell', 'dalvikvm', '-cp', remote, 'Check'],
                                     capture_output=True, text=True, timeout=60)
            self.assertEqual(execute.returncode, 0, execute.stderr)
            self.assertEqual(execute.stdout.strip(), 'PASS')
        finally:
            cleanup = subprocess.run([*adb, 'shell', 'rm', '-f', remote],
                                     capture_output=True, text=True, timeout=60)
            self.assertEqual(cleanup.returncode, 0, cleanup.stderr)
