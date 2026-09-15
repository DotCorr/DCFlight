from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.swift_types import parse_type,spelling
from dcflight.platforms.ios_api import API,Parameter,SDKCatalog,Reference,Literal


class SwiftCFunctionTests(unittest.TestCase):
    def test_c_convention_roundtrip_and_rejections(self):
        for source in ('@convention(c) (Int32) -> Int32','(@convention(c) (Int32) -> Int32)?','[@convention(c) () -> Void]'):
            self.assertEqual(parse_type(source),parse_type(spelling(parse_type(source))))
        self.assertNotEqual(parse_type('@convention(c) (Int32) -> Int32'),parse_type('(Int32) -> Int32'))
        for source in ('@convention(swift) () -> Void','@convention(c) () async -> Void','@convention(c) () throws -> Void','@MainActor @convention(c) () -> Void','@convention(c) @convention(c) () -> Void','@convention(c);bad () -> Void'):
            with self.subTest(source=source),self.assertRaises(ValueError):parse_type(source)

    def test_typed_reference_must_preserve_calling_convention(self):
        typ='@convention(c) (Int32) -> Int32'
        member=API('invoke','NativeFixture',('invoke(_:_:)',),'function',(Parameter('_','callback',typ),Parameter('_','value','Int32')),'Int32',(),())
        sdk=SDKCatalog.from_records([member.to_dict()])
        with self.assertRaisesRegex(ValueError,'type mismatch'):
            sdk.emit_call('invoke',[Reference('callback','(Int32) -> Int32'),Literal(41)])
        self.assertIn('`callback`',sdk.emit_call('invoke',[Reference('callback',typ),Literal(41)]).expression)

    @unittest.skipUnless(shutil.which('swiftc') and shutil.which('clang'),'Native compilers required')
    def test_generated_swift_call_executes_real_c_callback(self):
        typ='@convention(c) (Int32) -> Int32'
        member=API('invoke','NativeFixture',('invoke(_:_:)',),'function',(Parameter('_','callback',typ),Parameter('_','value','Int32')),'Int32',(),())
        expression=SDKCatalog([member]).emit_call('invoke',[Reference('callback',typ),Literal(41)]).expression
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            (root/'fixture.h').write_text('#include <stdint.h>\nint32_t invoke(int32_t (*callback)(int32_t), int32_t value);\n')
            (root/'fixture.c').write_text('#include "fixture.h"\nint32_t invoke(int32_t (*callback)(int32_t), int32_t value) { return callback(value); }\n')
            (root/'module.modulemap').write_text('module NativeFixture { header "fixture.h" export * }\n')
            (root/'Check.swift').write_text('import NativeFixture\nlet callback: '+typ+' = { $0 + 1 }\nlet result = '+expression+'\nprecondition(result == 42)\nprint("native C callback passed")\n')
            for command in [['clang','-c',str(root/'fixture.c'),'-o',str(root/'fixture.o')],['swiftc','-swift-version','6','-I',str(root),str(root/'Check.swift'),str(root/'fixture.o'),'-o',str(root/'Check')]]:
                result=subprocess.run(command,capture_output=True,text=True)
                self.assertEqual(0,result.returncode,result.stderr)
            result=subprocess.run([str(root/'Check')],capture_output=True,text=True)
            self.assertEqual(0,result.returncode,result.stderr)
            self.assertIn('native C callback passed',result.stdout)
