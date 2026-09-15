"""Nested Swift Optional stays typed and each authored guard removes one layer."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dcflight.native_sequence import emit_sequence
from dcflight.platforms.swift_types import (
    SwiftType, is_optional, make_optional, optional_inner, parse_type, spelling,
)


class SwiftNestedOptionalTests(unittest.TestCase):
    def test_canonical_optional_layers(self):
        self.assertEqual(SwiftType('String', optional=True), parse_type('Optional<String>'))
        expected = parse_type('String??')
        for text in ('Optional<String?>', 'Swift.Optional<Optional<String>>',
                     'Optional<String>?', 'Swift.Optional<Swift.Optional<String>>'):
            with self.subTest(text=text):
                self.assertEqual(expected, parse_type(text))
        self.assertEqual(parse_type('String?'), optional_inner(expected))
        self.assertEqual(parse_type('String'), optional_inner(optional_inner(expected)))
        self.assertIsNone(optional_inner(parse_type('String')))
        self.assertTrue(is_optional(expected))
        self.assertEqual(expected, make_optional(parse_type('String?')))
        self.assertNotEqual(expected, parse_type('String?'))

    def test_roundtrip_and_bounded_grammar(self):
        for text in ('String???', '[String??]??', '(String?, Int32)??',
                     '((Int32) async throws -> String?)??', '(any Error)??',
                     'Optional<@Sendable () -> String?>',
                     'Dictionary<String, Optional<[Int32?]>>??'):
            with self.subTest(text=text):
                value = parse_type(text)
                self.assertEqual(value, parse_type(spelling(value)))
        for text in ('Optional', 'Optional<String, Int32>', 'Optional<>',
                     'Swift.Optional', 'String' + '?' * 17,
                     'Optional<' * 18 + 'String' + '>' * 18,
                     '[' * 10 + 'String' + '?' * 10 + ']' * 10,
                     'any Error??'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_type(text)

    @staticmethod
    def sequence():
        return {'platform': 'ios', 'allowThrows': True,
                'inputs': [{'name': 'input', 'type': 'String??'}],
                'steps': [{'unwrap': {'ref': 'input'}, 'bind': 'outer', 'message': 'outer'},
                          {'unwrap': {'ref': 'outer'}, 'bind': 'inner', 'message': 'inner'}]}

    def test_unwrap_and_projection_require_each_layer(self):
        result = emit_sequence(None, self.sequence())
        self.assertEqual(['String?', 'String'], [item['type'] for item in result['bindings']])
        sequence = self.sequence()
        sequence['steps'].append({'unwrap': {'ref': 'inner'}, 'bind': 'extra', 'message': 'bad'})
        with self.assertRaisesRegex(ValueError, 'optional native type'):
            emit_sequence(None, sequence)
        for text in ('(String, Int32)?', '(String, Int32)??',
                     'Optional<Optional<(String, Int32)>>'):
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, 'nonoptional tuple'):
                emit_sequence(None, {'platform': 'ios', 'inputs': [{'name': 'pair', 'type': text}],
                                     'steps': [{'project': {'ref': 'pair', 'index': 0}, 'bind': 'value'}]})

    @unittest.skipUnless(shutil.which('xcrun'), 'Swift compiler required')
    def test_native_execution_distinguishes_outer_and_inner_nil(self):
        source = emit_sequence(None, self.sequence())['source']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'main.swift').write_text('''import Foundation
func checked(_ input: String??) throws -> String {
''' + source + '''
    return dcfLocal1
}
precondition(try! checked(.some(.some("native"))) == "native")
for (input, expected): (String??, String) in [(nil, "outer"), (.some(nil), "inner")] {
    do { _ = try checked(input); fatalError("guard did not fail") }
    catch { precondition((error as NSError).localizedDescription == expected) }
}
''')
            build = subprocess.run(['xcrun', 'swiftc', str(root / 'main.swift'), '-o', str(root / 'probe')], capture_output=True, text=True)
            self.assertEqual(0, build.returncode, build.stderr)
            run = subprocess.run([str(root / 'probe')], capture_output=True, text=True)
            self.assertEqual(0, run.returncode, run.stderr)
