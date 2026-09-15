import dataclasses
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from dcflight.ir import Literal,Reference,ScalarType
from dcflight.native_operation import OperationContract,OperationParameter
from dcflight.backends.ios_flow import native_operation_effect


def effect(arguments=(),target='output'):
    return SimpleNamespace(operation='demo',arguments=arguments,target=target,success='ok',failure='failed')


class IOSNativeOperationEffectTests(unittest.TestCase):
    def contract(self,result=ScalarType.STRING,parameters=(),throws=False):
        return OperationContract('demo',parameters,result,throws)

    def test_direct_call_literals_and_checked_range(self):
        params=(OperationParameter('number',ScalarType.INT),OperationParameter('text',ScalarType.STRING))
        source=native_operation_effect(effect((Reference('count',ScalarType.INT),Literal('model.s_\\(attack())',ScalarType.STRING))),self.contract(parameters=params,throws=True))
        self.assertIn('Int32(exactly: self.s_count)',source)
        self.assertIn('model.s_\\\\(attack())',source)
        self.assertIn('try NativeOperation_demo.invoke(nativeArgument0, nativeArgument1)',source)
        self.assertLess(source.index('guard nativeResult.utf8.count'),source.index('self.s_output = nativeResult'))
        self.assertIn('catch { self.f_failed(navigate); return }',source)
        plain=native_operation_effect(effect(),self.contract(ScalarType.BOOL))
        self.assertNotIn('try ',plain);self.assertNotIn('catch',plain)

    def test_routed_model_integration(self):
        from test_ios_routed import fixture
        from dcflight.ir import State
        from dcflight.flow_ir import FlowAction,FlowCase,NativeOperationEffect,SetEffect
        from dcflight.backends.ios_routed import generate
        from dcflight.registry import Registry
        operation=dataclasses.replace(self.contract(),execution='main')
        states=(State('output',Literal('',ScalarType.STRING)),State('accepted',Literal(False,ScalarType.BOOL)))
        flows=(FlowAction('run',None,(),(FlowCase(0,(NativeOperationEffect('demo',(),'output','ok','failed'),)),)),
               FlowAction('ok',None,(),(FlowCase(0,(SetEffect('accepted',Literal(True,ScalarType.BOOL)),)),)),
               FlowAction('failed',None,(),(FlowCase(0,(SetEffect('accepted',Literal(False,ScalarType.BOOL)),)),)))
        app=dataclasses.replace(fixture(),states=states,flow_actions=flows,native_operations=(operation,))
        model=generate(app,Registry())['ios/App/Generated/AppModel.swift'].content
        self.assertIn('@MainActor func f_run',model)
        self.assertIn('let nativeResult = NativeOperation_demo.invoke()',model)
        self.assertIn('self.s_output = nativeResult',model)
        self.assertNotIn('operationRegistry',model)

    @unittest.skipUnless(shutil.which('xcrun'),'Native Swift required')
    def test_native_atomic_success_throw_oversize_and_int_range(self):
        string=native_operation_effect(effect(),self.contract(throws=True))
        integer=native_operation_effect(effect((Reference('count',ScalarType.INT),),target='number'),self.contract(ScalarType.INT,(OperationParameter('number',ScalarType.INT),)))
        source='''import Foundation
enum Problem: Error { case test }
enum NativeOperation_demo {
 static var mode=0
 static func invoke() throws -> String {
  if mode==1 { throw Problem.test }
  if mode==2 { return String(repeating:"é",count:4_194_305) }
  return "okay"
 }
 static func invoke(_ value:Int32)->Int32 { value }
}
final class Model {
 var s_output="before",s_number:Int32=7,s_count:Int=0
 var success=0,failure=0
 func f_ok(_ n:(String)->Void) { success += 1 }
 func f_failed(_ n:(String)->Void) { failure += 1 }
 func run(_ navigate:(String)->Void) {
'''+string+'''
 }
 func integer(_ navigate:(String)->Void) {
'''+integer+'''
 }
}
let m=Model()
m.run({_ in});precondition(m.s_output=="okay" && m.success==1)
m.s_output="retained";NativeOperation_demo.mode=1;m.run({_ in});precondition(m.s_output=="retained" && m.failure==1)
NativeOperation_demo.mode=2;m.run({_ in});precondition(m.s_output=="retained" && m.failure==2)
m.s_count=Int(Int32.max)+1;m.integer({_ in});precondition(m.s_number==7 && m.failure==3)
m.s_count=Int(Int32.min);m.integer({_ in});precondition(m.s_number==Int32.min && m.success==2)
'''
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'main.swift';binary=Path(d)/'check';path.write_text(source)
            result=subprocess.run(['xcrun','swiftc',str(path),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            subprocess.run([str(binary)],check=True,capture_output=True)
