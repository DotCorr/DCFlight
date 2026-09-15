import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dcflight.dcdart import audit_object, compile_logic


class LogicAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.nm = shutil.which('llvm-nm') or '/opt/homebrew/opt/llvm/bin/llvm-nm'
        if not shutil.which('clang') or not Path(self.nm).exists():
            self.skipTest('native Clang and LLVM nm required')

    def tearDown(self):
        self.temp.cleanup()

    def compile_c(self, source):
        path = self.root / 'test.c'
        path.write_text(source)
        obj = self.root / 'test.o'
        subprocess.run(['clang', '-c', str(path), '-o', str(obj)], check=True)
        return obj

    def test_declared_native_calls_are_explicit(self):
        obj = self.compile_c('extern int native_value(void); int compute(void) { return native_value(); }')
        with self.assertRaisesRegex(ValueError, 'undeclared'):
            audit_object(obj, self.nm)
        self.assertEqual(audit_object(obj, self.nm, ['native_value'])['undefinedSymbols'], ['native_value'])

    def test_embedded_runtime_is_rejected_even_without_imports(self):
        obj = self.compile_c('int dc_heap[32]; int value(void) { return 1; }')
        with self.assertRaisesRegex(ValueError, 'prohibited'):
            audit_object(obj, self.nm)

    def test_runtime_import_cannot_be_allowlisted(self):
        obj = self.compile_c('extern int Dart_Initialize(void); int value(void) { return Dart_Initialize(); }')
        with self.assertRaisesRegex(ValueError, 'prohibited'):
            audit_object(obj, self.nm, ['Dart_Initialize'])

    def test_plain_native_object_passes(self):
        obj = self.compile_c('unsigned int increment(unsigned int value) { return value + 1; }')
        self.assertTrue(audit_object(obj, self.nm)['passed'])

    def test_unknown_target_is_not_silently_substituted(self):
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            compile_logic('unused', self.root, 'ios-fake', prelude='unused')


if __name__ == '__main__':
    unittest.main()
