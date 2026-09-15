import dataclasses
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.ir import Reference,ScalarType,State,Literal
from dcflight.flow_ir import NativeOperationEffect,FlowAction,FlowCase,CancelEffect,SetEffect
from dcflight.native_operation import OperationContract,OperationParameter
from dcflight.backends.ios_flow import native_operation_effect
from dcflight.backends.ios_routed import generate
from dcflight.registry import Registry


def worker():
    return OperationContract('worker',(OperationParameter('code',ScalarType.INT),),ScalarType.STRING,True,'worker')


def invocation():
    return NativeOperationEffect('worker',(Reference('input',ScalarType.INT),),'output','ok','failed')


class IOSWorkerOperationTests(unittest.TestCase):
    def test_snapshot_weak_publication_and_model_lifecycle(self):
        source=native_operation_effect(invocation(),worker())
        self.assertLess(source.index('Int32(exactly: self.s_input)'),source.index('Task.detached'))
        detached=source.split('Task.detached',1)[1].split('nativeWorkerTask = Task',1)[0]
        self.assertNotIn('self',detached)
        self.assertIn('withTaskCancellationHandler',source)
        self.assertIn('[weak self]',source)
        self.assertLess(source.index('catch { outcome'),source.index('self.f_ok'))
        self.assertIn('nativeGeneration == self.nativeWorkerGeneration',source)
        model=self.model()
        self.assertIn('deinit { nativeWorkerTask?.cancel();',model)
        self.assertIn('nativeWorkerGeneration &+= 1; nativeWorkerTask?.cancel(); nativeWorkerTask = nil',model)

    def model(self):
        from test_ios_routed import fixture
        flows=(FlowAction('run',None,(),(FlowCase(0,(invocation(),)),)),
               FlowAction('stop',None,(),(FlowCase(0,(CancelEffect(),)),)),
               FlowAction('ok',None,(),(FlowCase(0,(SetEffect('accepted',Literal(True,ScalarType.BOOL)),)),)),
               FlowAction('failed',None,(),(FlowCase(0,(SetEffect('accepted',Literal(False,ScalarType.BOOL)),)),)))
        states=(State('input',Literal(0,ScalarType.INT)),State('output',Literal('',ScalarType.STRING)),State('accepted',Literal(False,ScalarType.BOOL)))
        app=dataclasses.replace(fixture(),states=states,flow_actions=flows,native_operations=(worker(),))
        return generate(app,Registry())['ios/App/Generated/AppModel.swift'].content

    def test_http_flow_does_not_cancel_worker(self):
        from test_ios_flow import flow_fixture
        app=dataclasses.replace(flow_fixture(),native_operations=(worker(),))
        source=generate(app,Registry())['ios/App/Generated/AppModel.swift'].content
        request=source.split('func f_load(',1)[1].split('@MainActor func',1)[0]
        self.assertIn('requestTask?.cancel()',request)
        self.assertNotIn('nativeWorkerTask?.cancel()',request)
        cancellation=source.split('func f_stop(',1)[1]
        self.assertIn('nativeWorkerTask?.cancel()',cancellation)

    @unittest.skipUnless(shutil.which('xcrun'),'Swift6 SDK required')
    def test_actual_generated_model_swift6_typechecks(self):
        source=self.model()+'''
final class NativeHTTPTransport { func close() {} }
enum NativeEffectFailure: Error { case responseLimit }
enum NativeOperation_worker { static func invoke(_ value:Int32) throws -> String { String(value) } }
'''
        result=subprocess.run(['xcrun','swiftc','-swift-version','6','-typecheck','-'],input=source,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr+"\n"+"\n".join(str(i+1)+": "+line for i,line in enumerate(source.splitlines())))

    @unittest.skipUnless(shutil.which('xcrun'),'Swift6 SDK required')
    def test_native_execution_latest_cancel_weak_lifetime_and_responsiveness(self):
        code=native_operation_effect(invocation(),worker())
        source='''import Foundation
import Darwin
enum NativeEffectFailure: Error { case responseLimit }
final class Probe: @unchecked Sendable {
 private let lock=NSLock();private var starts=0;private var cancels=0
 let gate=DispatchSemaphore(value:0)
 func start() { lock.lock();starts += 1;lock.unlock() }
 func cancel() { lock.lock();cancels += 1;lock.unlock() }
 var counts:(Int,Int) { lock.lock();defer { lock.unlock() };return (starts,cancels) }
}
let probe=Probe()
enum NativeOperation_worker {
 static func invoke(_ code:Int32) throws -> String {
  precondition(!Thread.isMainThread);probe.start()
  if code == -1 { throw NativeEffectFailure.responseLimit }
  if code == 9 { return String(repeating:"é",count:4_194_305) }
  if code == 4 { precondition(probe.gate.wait(timeout:.now()+3) == .success);return String(code) }
  if code == 1 { usleep(150_000);return String(code) }
  let ticks = code == 2 ? 5 : 150
  for _ in 0..<ticks { if Task.isCancelled { probe.cancel();throw CancellationError() };usleep(1000) }
  return String(code)
 }
}
@MainActor final class Model {
 var s_input:Int=0;var s_output="original";var successes=0;var failures=0
 var nativeWorkerGeneration:UInt64=0;var nativeWorkerTask:Task<Void,Never>?
 deinit { nativeWorkerTask?.cancel() }
 func f_ok(_ n:(String)->Void) { MainActor.preconditionIsolated();successes += 1 }
 func f_failed(_ n:(String)->Void) { MainActor.preconditionIsolated();failures += 1 }
 func stop() { nativeWorkerGeneration &+= 1;nativeWorkerTask?.cancel();nativeWorkerTask=nil }
 func run(_ navigate:@escaping (String)->Void) {
'''+code+'''
 }
}
@main struct Check {
 @MainActor static func pause(_ ms:UInt64) async { try? await Task.sleep(nanoseconds:ms*1_000_000) }
 @MainActor static func until(_ condition:()->Bool) async {
  let deadline=Date().addingTimeInterval(3)
  while !condition() { precondition(Date()<deadline);await pause(5) }
 }
 @MainActor static func main() async {
  let m=Model();m.s_input=4
  m.run({_ in});m.s_input=99
  await until { probe.counts.0==1 };precondition(m.s_output=="original");probe.gate.signal()
  await until { m.successes==1 };precondition(m.s_output=="4")
  m.s_input = -1;m.run({_ in});await until { m.failures==1 };precondition(m.s_output=="4")
  m.s_input=9;m.run({_ in});await until { m.failures==2 };precondition(m.s_output=="4")
  m.s_input=1;m.run({_ in});await pause(10);m.s_input=2;m.run({_ in});await pause(200)
  precondition(m.s_output=="2" && m.successes==2 && m.failures==2)
  m.s_input=3;m.run({_ in});await pause(15);let old=probe.counts.1;m.stop();await pause(180)
  precondition(m.s_output=="2" && m.successes==2 && m.failures==2 && probe.counts.1>old)
  m.s_input=Int(Int32.max)+1;let starts=probe.counts.0;m.run({_ in});await pause(10)
  precondition(m.failures==3 && starts==probe.counts.0)
  var disposable:Model?=Model();weak var weakModel=disposable;disposable!.s_input=3
  disposable!.run({_ in});await pause(15);let cancelled=probe.counts.1;disposable=nil
  precondition(weakModel==nil);await pause(100);precondition(probe.counts.1>cancelled)
 }
}
'''
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'main.swift';binary=Path(d)/'check';path.write_text(source)
            compiled=subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(path),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(compiled.returncode,0,compiled.stderr)
            result=subprocess.run([str(binary)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stderr+"\n"+"\n".join(str(i+1)+": "+line for i,line in enumerate(source.splitlines())))
