import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dcflight.platforms.swift_types import parse_type
from dcflight.platforms.ios_api import SDKCatalog, Literal, Reference, _argument


class SwiftCollectionTypeTests(unittest.TestCase):
    def test_dart_collection_authoring_matches_json_and_rejects_invalid_values(self):
        dart = shutil.which('dart')
        if not dart:
            self.skipTest('Dart authoring SDK unavailable')
        library = Path(__file__).resolve().parents[1] / 'authoring/lib/dcflight.dart'
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'collections.dart'
            source.write_text("import 'dart:convert';\nimport '" + library.as_uri() + "';\n" + '''
            void main() {
              print(jsonEncode(const NativeLiteral({'numbers': [1, null, 3]}).toJson()));
              for (final bad in [double.nan, {1: 'bad'}, List.filled(4096, 1)]) {
                var rejected = false;
                try { NativeLiteral(bad).toJson(); } on ArgumentError { rejected = true; }
                if (!rejected) throw StateError('Invalid native literal accepted');
              }
            }
            ''')
            result = subprocess.run([str(dart), str(source)], check=True, capture_output=True, text=True, timeout=30)
            value = json.loads(result.stdout)
            self.assertEqual({'literal': {'numbers': [1, None, 3]}}, value)
            self.assertEqual('["numbers": [1, nil, 3]]', _argument(Literal(value['literal']), '[String: [Int32?]]'))

    def test_structured_types_and_equivalent_collection_spellings(self):
        self.assertEqual(parse_type('[String: [Int32?]]?'),
                         parse_type('Swift.Dictionary<String, Swift.Array<Int32?>>?'))
        self.assertNotEqual(parse_type('[Int32?]'), parse_type('[Int32]?'))
        self.assertEqual('`values`', _argument(Reference('values', 'Array<String>'), '[String]'))
        with self.assertRaisesRegex(ValueError, 'type mismatch'):
            _argument(Reference('values', '[Int32]'), '[String]')

    def test_literal_element_validation_and_empty_dictionary(self):
        self.assertEqual('[:]', _argument(Literal({}), '[String: Int32]'))
        self.assertEqual('["a": [1, nil]]', _argument(Literal({'a': [1, None]}), '[String: [Int32?]]'))
        for raw, expected in [([True], '[Int32]'), ([None], '[String]'),
                              ({'a': 1}, '[String: String]'), ([2**40], '[Int32]')]:
            with self.assertRaises(ValueError):
                _argument(Literal(raw), expected)

    def test_type_injection_and_unbounded_inputs_rejected(self):
        for value in ['[String]; fatalError()', 'Array<String> /*x*/', '() -> String; fatalError()',
                      '[String', 'Dictionary<String>', 'Array<>', 
                      'Array<String, Int>', '[' * 18 + 'Int' + ']' * 18]:
            with self.assertRaises(ValueError, msg=value):
                parse_type(value)
        with self.assertRaisesRegex(ValueError, '4096'):
            _argument(Literal([1] * 4096), '[Int]')

    @unittest.skipUnless(shutil.which('xcrun'), 'Swift toolchain required')
    def test_actual_symbolgraph_collections_compile_and_execute(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'Collections.swift'
            source.write_text('''public struct Collections {
                public static func echo(_ values: [String]) -> [String] { values }
                public static func count(_ values: [String: [Int32?]]) -> Int32 {
                    Int32(values["numbers"]!.count)
                }
            }''')
            subprocess.run(['xcrun', 'swiftc', '-emit-module', '-module-name', 'Collections',
                str(source), '-emit-module-path', str(root/'Collections.swiftmodule')], check=True, capture_output=True)
            target = json.loads(subprocess.check_output(['xcrun','swiftc','-print-target-info'], text=True))['target']['triple']
            sdk = subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'], text=True).strip()
            subprocess.run(['xcrun','swift-symbolgraph-extract','-module-name','Collections','-I',tmp,
                '-output-dir',tmp,'-target',target,'-sdk',sdk], check=True, capture_output=True)
            api = SDKCatalog.from_symbolgraphs([root/'Collections.symbols.json'], 'Collections')
            methods = {a.path[-1]: a for a in api.apis.values()}
            self.assertFalse(methods['echo(_:)'].unsupported)
            echo = api.emit_call(methods['echo(_:)'].id, [Literal(['hello', 'world'])]).expression
            count = api.emit_call(methods['count(_:)'].id, [Literal({'numbers': [1, None, 3]})]).expression
            caller = root / 'main.swift'
            caller.write_text('let values = ' + echo + '\nprecondition(values == ["hello", "world"])\nprecondition(' + count + ' == 3)\n')
            executable = root / 'verify'
            subprocess.run(['xcrun','swiftc','-swift-version','6',str(source),str(caller),'-o',str(executable)],
                           check=True, capture_output=True)
            subprocess.run([str(executable)], check=True, capture_output=True, timeout=15)
