import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from dataclasses import asdict
from pathlib import Path

from dcflight.modules import export as exporter
from dcflight.modules.manifest import read_manifest, digest
from dcflight.native_api import NativeAPI
from dcflight.platforms.android_api import AndroidAPI

if os.environ.get('DCFLIGHT_TEST_EXPORT_MODULE'):
    spec = importlib.util.spec_from_file_location('dcflight.modules._staged_export',
                                                 os.environ['DCFLIGHT_TEST_EXPORT_MODULE'])
    exporter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(exporter)


class InnerClassMetadataTests(unittest.TestCase):
    def test_only_own_exact_inner_class_entry_controls_flags(self):
        verbose = '''Classfile exact.class
public class demo.Outer$Good
InnerClasses:
  public static #1= #2 of #3; // Good=class demo/Outer$Good of class demo/Outer
  public static #4= #5 of #3; // Other=class demo/Outer$Other of class demo/Outer
'''
        self.assertEqual(exporter._inner_class_declarations(verbose),
                         {'demo.Outer$Good': ('demo.Outer', ('public', 'static'))})
        self.assertEqual(exporter._inner_class_declarations(verbose.replace('Good=class', 'Wrong=class')), {})
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            exporter._inner_class_declarations(verbose + verbose.replace('public static #1', 'public #1'))

    def test_missing_metadata_or_enclosing_class_stays_rejected(self):
        text = '''public class demo.Outer$Good {
 public demo.Outer$Good();
 public static int number();
}
'''
        for entries in ({}, {'demo.Outer$Good': ('demo.Outer', ('public', 'static'))}):
            converted, _ = exporter._convert(text, inner_classes=entries)
            api = AndroidAPI(converted)
            for member in ('demo.Outer.Good#<init>()', 'demo.Outer.Good#number()'):
                with self.subTest(entries=entries, member=member), self.assertRaises(ValueError):
                    api.emit(member)


@unittest.skipUnless(shutil.which('javac') and shutil.which('javap') and shutil.which('java'),
                     'JDK required for nested bytecode integration')
class StaticNestedExportTests(unittest.TestCase):
    def test_locked_nested_bytecode_exports_access_and_static_semantics(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'demo/Outer.java'
            source.parent.mkdir()
            source.write_text('''package demo;
public class Outer {
 public static class Good { public Good() {} public int value() { return 7; } }
 public static class Generic<T> { public final T value; public Generic(T v) { value=v; } }
 public class Inner { public Inner() {} }
 private static class Hidden { public Hidden() {} public static class Child { public Child() {} public static int value() { return 9; } } }
 static class Package { public Package() {} public static class Child { public Child() {} } }
 protected static class Protected { public Protected() {} }
 public interface Face { class Child { public Child() {} } }
}
''')
            build = subprocess.run(['javac', '--release', '8', str(source)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            archive = root / 'fixture.jar'
            with zipfile.ZipFile(archive, 'w') as jar:
                for path in source.parent.glob('*.class'):
                    jar.write(path, path.relative_to(root))
            manifest = {'schemaVersion': 1, 'id': 'nested', 'version': '1.0.0',
                        'platform': 'android', 'package': 'demo:nested', 'revision': '1.0.0'}
            manifest_path = root / 'module.json'
            manifest_path.write_text(json.dumps(manifest))
            lock = {'schemaVersion': 1, 'module': asdict(read_manifest(manifest_path)),
                    'manifestSha256': digest(manifest_path),
                    'artifacts': [{'path': archive.name, 'sha256': digest(archive)}]}
            lock_path = root / 'module.lock.json'
            lock_path.write_text(json.dumps(lock))
            catalog = root / 'catalog.db'
            report = exporter.export_android(lock_path, catalog, javap=shutil.which('javap'))
            self.assertGreater(report['provenance']['innerClassEntriesVerified'], 2)
            api = NativeAPI(catalog)
            def emit(identity, **kwargs):
                return api.emit({'platform': 'android', 'scope': report['scope'], 'id': identity, **kwargs})
            good = emit('demo.Outer.Good#<init>()')
            self.assertEqual(good['source'], 'new demo.Outer.Good()')
            face = emit('demo.Outer.Face.Child#<init>()')
            generic = emit('demo.Outer.Generic#<init>(T)', constructedType='demo.Outer.Generic<java.lang.String>',
                           arguments=[{'literal': 'native'}])
            for identity in ('demo.Outer.Inner#<init>(demo.Outer)',
                             'demo.Outer.Hidden#<init>()', 'demo.Outer.Hidden.Child#<init>()',
                             'demo.Outer.Hidden.Child#value()', 'demo.Outer.Package#<init>()',
                             'demo.Outer.Package.Child#<init>()', 'demo.Outer.Protected#<init>()'):
                with self.subTest(identity=identity), self.assertRaises(ValueError):
                    emit(identity)
            check = root / 'Check.java'
            check.write_text('public class Check { public static void main(String[] args) { '
                             f'demo.Outer.Good good = {good["source"]}; '
                             f'demo.Outer.Face.Child face = {face["source"]}; '
                             f'demo.Outer.Generic<String> generic = {generic["source"]}; '
                             'if (good.value()!=7 || face==null || !generic.value.equals("native")) '
                             'throw new AssertionError(); System.out.print("PASS"); }}')
            compiled = subprocess.run(['javac', '--release', '8', '-Xlint:unchecked,rawtypes', '-Werror',
                                       '-cp', str(archive), str(check)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            executed = subprocess.run(['java', '-cp', str(root) + os.pathsep + str(archive), 'Check'],
                                      capture_output=True, text=True)
            self.assertEqual(executed.returncode, 0, executed.stderr)
            self.assertEqual(executed.stdout, 'PASS')
