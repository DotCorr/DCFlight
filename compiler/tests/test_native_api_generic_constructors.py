"""Generic constructors retain their types through catalog, sequence and Dart input."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dcflight.native_api import NativeAPI, index_android
from dcflight.native_sequence import emit_sequence


SDK = '''package sample {
 public class Packet<T> {
  ctor public <R extends T> Packet(R);
  method public T value();
 }
 public class Text {
  ctor public <R extends java.lang.CharSequence> Text(R);
 }
 public class Private {
  ctor private <R> Private(R);
 }
 public abstract class Abstract {
  ctor public <R> Abstract(R);
 }
 class Hidden {
  ctor public <R> Hidden(R);
 }
}'''


class NativeGenericConstructorIntegrationTests(unittest.TestCase):
    def setup_api(self, root):
        source = root / 'sdk.txt'
        source.write_text(SDK)
        database = root / 'sdk.sqlite'
        index_android(database, source)
        return NativeAPI(database)

    def request(self):
        return {'platform': 'android', 'id': 'sample.Packet#<init>(R)',
                'typeArguments': ['java.lang.String'],
                'constructedType': 'sample.Packet<java.lang.Object>',
                'arguments': [{'literal': 'hello'}]}

    def test_catalog_specializes_constructor_and_owner_separately(self):
        with tempfile.TemporaryDirectory() as directory:
            api = self.setup_api(Path(directory))
            result = api.emit(self.request())
            self.assertEqual('sample.Packet<java.lang.Object>', result['resultType'])
            self.assertEqual('new <java.lang.String> sample.Packet<java.lang.Object>((java.lang.String) ("hello"))',
                             result['source'])
            self.assertIsNone(result['compilerRuntimeDependency'])
            self.assertIsNone(result['runtimeDependency'])
            result = api.emit({'platform': 'android', 'id': 'sample.Text#<init>(R)',
                               'typeArguments': ['java.lang.String'],
                               'arguments': [{'literal': 'hello'}]})
            self.assertEqual('sample.Text', result['resultType'])

    def test_explicit_arguments_do_not_bypass_catalog_restrictions(self):
        with tempfile.TemporaryDirectory() as directory:
            api = self.setup_api(Path(directory))
            for owner in ('Private', 'Abstract', 'Hidden'):
                with self.subTest(owner=owner), self.assertRaisesRegex(ValueError, 'Unsupported API'):
                    api.emit({'platform': 'android', 'id': f'sample.{owner}#<init>(R)',
                              'typeArguments': ['java.lang.String'],
                              'arguments': [{'literal': 'hello'}]})

    def test_malformed_arguments_bounds_and_missing_owner_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            api = self.setup_api(Path(directory))
            for arguments in (None, [], ['int'], ['java.lang.String', 'java.lang.String']):
                with self.subTest(arguments=arguments), self.assertRaises(ValueError):
                    api.emit({**self.request(), 'typeArguments': arguments})
            request = self.request()
            del request['constructedType']
            with self.assertRaises(ValueError):
                api.emit(request)
            with self.assertRaises(ValueError):
                api.emit({**self.request(), 'arguments': [{'literal': 12}]})
            with self.assertRaisesRegex(ValueError, 'bound'):
                api.emit({'platform': 'android', 'id': 'sample.Text#<init>(R)',
                          'typeArguments': ['java.lang.Integer'],
                          'arguments': [{'literal': 12}]})

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_sequence_constructs_and_uses_native_instance_without_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            api = self.setup_api(root)
            constructor = self.request()
            del constructor['platform']
            sequence = emit_sequence(api, {'platform': 'android', 'steps': [
                {**constructor, 'bind': 'packet'},
                {'id': 'sample.Packet#value()', 'receiver': {'ref': 'packet'}, 'bind': 'value'},
            ]})
            self.assertIn('java.lang.Object dcfLocal1', sequence['source'])
            (root / 'sample').mkdir()
            packet = root / 'sample' / 'Packet.java'
            packet.write_text('package sample; public class Packet<T> { private final T value; '
                              'public <R extends T> Packet(R value) { this.value = value; } '
                              'public T value() { return value; } }')
            main = root / 'Main.java'
            main.write_text('public class Main { public static void main(String[] args) { '
                            + sequence['source']
                            + ' if (!dcfLocal1.equals("hello")) throw new AssertionError(); } }')
            compiled = subprocess.run(['javac', '-Xlint:unchecked', '-Werror', '-d', str(root),
                                       str(packet), str(main)], capture_output=True, text=True)
            self.assertEqual(0, compiled.returncode, compiled.stderr)
            executed = subprocess.run(['java', '-cp', str(root), 'Main'], capture_output=True, text=True)
            self.assertEqual(0, executed.returncode, executed.stderr)

    @unittest.skipUnless(shutil.which('dart'), 'Dart SDK required')
    def test_dart_native_call_serialization_reaches_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = Path(__file__).resolve().parents[1] / 'authoring/lib/dcflight.dart'
            source = root / 'main.dart'
            source.write_text("import 'dart:convert';\nimport '" + library.as_uri() + "';\n"
                              "void main() { print(jsonEncode(const NativeCall('sample.Packet#<init>(R)', "
                              "typeArguments: ['java.lang.String'], "
                              "constructedType: 'sample.Packet<java.lang.Object>', "
                              "arguments: [NativeLiteral('hello')]).toJson())); }\n")
            evaluated = subprocess.run([shutil.which('dart'), str(source)], capture_output=True, text=True)
            self.assertEqual(0, evaluated.returncode, evaluated.stderr)
            request = {'platform': 'android', **json.loads(evaluated.stdout)}
            self.assertEqual(self.request(), request)
            self.assertEqual('sample.Packet<java.lang.Object>', self.setup_api(root).emit(request)['resultType'])
