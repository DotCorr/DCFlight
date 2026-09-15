import importlib.util,json,os,sys,tempfile,unittest,subprocess,shutil
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from dcflight.ir import ABIType,LogicFunction,LogicModule
from dcflight import shared_logic as staged
UTF8=ABIType.UTF8
def function(parameters,returns=ABIType.UINT32):return SimpleNamespace(name='inspect',parameters=tuple(parameters),returns=returns)

class UTF8GeneratorTests(unittest.TestCase):
 def test_physical_header_expansion_has_one_pair_per_logical_string(self):
  f=function([UTF8,ABIType.UINT32,UTF8,ABIType.UINT64])
  self.assertEqual(('uint64_t','uint32_t','uint32_t','uint64_t','uint32_t','uint64_t'),staged.abi_parameters(f))
  self.assertEqual('uint32_t inspect(uint64_t a0, uint32_t a1, uint32_t a2, uint64_t a3, uint32_t a4, uint64_t a5);',staged.abi_declaration(f))
  with self.assertRaisesRegex(ValueError,'results'):staged.abi_declaration(function([UTF8],UTF8))
 def test_facades_validate_before_call_and_preserve_string_lifetime(self):
  f=function([UTF8,ABIType.UINT32,UTF8])
  swift=staged.swift_utf8_wrapper(f,'native_inspect')
  self.assertIn('_ a0: String, _ a1: UInt32, _ a2: String',swift)
  self.assertLess(swift.rindex('guard total'),swift.index('let b0'))
  self.assertLess(swift.index('b0.withUnsafeBufferPointer'),swift.index('b2.withUnsafeBufferPointer'))
  self.assertIn('p0.isEmpty ? UInt64(0)',swift)
  java,jni=staged.android_utf8_wrapper(f,'com.example.app')
  self.assertIn('f_inspect(String a0, int a1, String a2)',java)
  self.assertLess(java.rindex('utf8Length('),java.index('getBytes('))
  self.assertIn('private static native int n_inspect(byte[] a0, int a1, byte[] a2)',java)
  self.assertEqual(2,jni.count('ReleaseByteArrayElements'))
  self.assertIn('JNI_ABORT',jni)
  self.assertLess(jni.rindex('valid_utf8('),jni.index('result = inspect('))
  self.assertNotIn('GetStringUTF',jni)
 def test_call_expression_uses_fallible_swift_facade_only_for_utf8(self):
  f=function([UTF8,ABIType.UINT32]);app=SimpleNamespace(logic=SimpleNamespace(functions=[f]));action=SimpleNamespace(function='inspect',arguments=['text','count'])
  result=staged.call_expression(app,action,'ios',lambda x,p:'model.s_'+x)
  self.assertEqual('try AppLogicUTF8.signed(try AppLogicUTF8.f_inspect(self.s_text, try AppLogicUTF8.unsigned(self.s_count)))',result)
  self.assertEqual('SharedLogic.f_inspect(this.s_text, this.s_count)',staged.call_expression(app,action,'android',lambda x,p:'model.s_'+x))
 def test_swift_uint32_conversion_failures_throw_instead_of_trapping(self):
  swiftc=shutil.which('swiftc')
  if not swiftc:self.skipTest('swiftc unavailable')
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);source=root/'main.swift';binary=root/'proof'
   source.write_text('enum AppLogicInputFailure: Error { case invalidInput }\nenum AppLogicUTF8 {\n'+staged.SWIFT_UTF8_HELPERS+'}\n'+"""
var calls = 0
func native(_ value: UInt32) -> UInt32 { calls += 1; return value }
do {
    _ = try AppLogicUTF8.signed(native(try AppLogicUTF8.unsigned(-1)))
    fatalError("negative input accepted")
} catch AppLogicInputFailure.invalidInput {}
precondition(calls == 0)
do {
    _ = try AppLogicUTF8.signed(UInt32.max)
    fatalError("overflow result accepted")
} catch AppLogicInputFailure.invalidInput {}
precondition(try AppLogicUTF8.unsigned(0) == 0)
precondition(try AppLogicUTF8.signed(UInt32(Int32.max)) == Int32.max)
print("fallible uint32 conversions passed")
""".replace('precondition(try AppLogicUTF8.unsigned(0) == 0)','let zero = try AppLogicUTF8.unsigned(0); precondition(zero == 0)').replace('precondition(try AppLogicUTF8.signed(UInt32(Int32.max)) == Int32.max)','let maximum = try AppLogicUTF8.signed(UInt32(Int32.max)); precondition(maximum == Int32.max)'))
   built=subprocess.run([swiftc,'-module-cache-path',str(root/'cache'),str(source),'-o',str(binary)],capture_output=True,text=True)
   self.assertEqual(0,built.returncode,built.stderr)
   executed=subprocess.run([str(binary)],capture_output=True,text=True)
   self.assertEqual(0,executed.returncode,executed.stderr)
   self.assertIn('passed',executed.stdout)
