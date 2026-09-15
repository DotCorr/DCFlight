import unittest
from pathlib import Path
import shutil
import subprocess
import tempfile
from dcflight.platforms.swift_types import parse_type, spelling
from dcflight.platforms.ios_api import _argument, Reference, Literal


class SwiftFunctionTypesTests(unittest.TestCase):
    def test_callback_attributes_are_structural(self):
        for value in ('@Sendable (Int) -> Int','@MainActor () -> Void',
                      '(@MainActor @Sendable () async throws -> String)?'):
            self.assertEqual(parse_type(value),parse_type(spelling(parse_type(value))))
        self.assertEqual(parse_type('@Sendable @MainActor () -> Void'),parse_type('@MainActor @Sendable () -> Void'))
        with self.assertRaises(ValueError):
            _argument(Reference('callback','() -> Void'),'@Sendable () -> Void')
        for invalid in ('@Sendable Int','@MainActor @MainActor () -> Void','@Sendable (() -> Void)?'):
            with self.assertRaises(ValueError):parse_type(invalid)

    @unittest.skipUnless(shutil.which('swiftc'),'Swift toolchain required')
    def test_native_sendability_is_enforced(self):
        callback=spelling(parse_type('@Sendable (Int) -> Int'))
        actor=spelling(parse_type('@MainActor @Sendable () async throws -> String'))
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'main.swift'
            source.write_text('typealias Callback = '+callback+'\ntypealias ActorCallback = '+actor+'\n'
                              'func invoke(_ callback: Callback) -> Int { callback(21) }\n'
                              'precondition(invoke { $0 * 2 } == 42)\n')
            command=['swiftc','-swift-version','6',str(source),'-o',str(root/'probe')]
            subprocess.run(command,check=True,capture_output=True)
            subprocess.run([str(root/'probe')],check=True,capture_output=True)
            source.write_text('typealias Callback = '+callback+'\nfinal class Box { var value=1 }\n'
                              'func unsafe(_ box: Box) -> Callback { { _ in box.value } }\n')
            rejected=subprocess.run(command,text=True,capture_output=True)
            self.assertNotEqual(0,rejected.returncode)
            self.assertIn('non-sendable',rejected.stderr.lower())
    def test_structural_function_types_and_roundtrip(self):
        for value in ('() -> Void', '(Int) -> String', '(Int, String?) async throws -> [String]',
                      '((Int) -> Int)?', '[(Int) -> Int]', '(Int) -> (String) -> Bool',
                      '((Int) -> Int, Bool) -> (Int, String)'):
            with self.subTest(value=value):
                parsed=parse_type(value)
                self.assertEqual(parsed,parse_type(spelling(parsed)))
        self.assertNotEqual(parse_type('(Int) -> String?'),parse_type('((Int) -> String)?'))
        self.assertNotEqual(parse_type('() throws -> Int'),parse_type('() -> Int'))
        self.assertEqual('`callback`',_argument(Reference('callback','(Int)->String'),'(Int) -> String'))
        with self.assertRaises(ValueError):
            _argument(Literal('raw source'),'(Int) -> String')

    def test_invalid_functions_remain_rejected(self):
        for value in ('(named: Int) -> Int','() throws async -> Int','() async',
                      '@UnknownActor () -> Void','() rethrows -> Void','() ->',
                      '() -> Int; print(1)','(inout Int) -> Int','() -> ' * 18 + 'Int'):
            with self.subTest(value=value),self.assertRaises(ValueError):
                parse_type(value)
