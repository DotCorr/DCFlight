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


def contract(execution='main',throws=True):
    return OperationContract('async'+execution,(OperationParameter('code',ScalarType.INT),),ScalarType.STRING,throws,execution,True)


def effect(execution='main'):
    return NativeOperationEffect('async'+execution,(Reference('input',ScalarType.INT),),'output','ok','failed')


class IOSSuspendingOperationTests(unittest.TestCase):
    def model(self):
        from test_ios_routed import fixture
        operation=contract()
        flows=(FlowAction('run',None,(),(FlowCase(0,(effect(),)),)),
               FlowAction('stop',None,(),(FlowCase(0,(CancelEffect(),)),)),
               FlowAction('ok',None,(),(FlowCase(0,(SetEffect('accepted',Literal(True,ScalarType.BOOL)),)),)),
               FlowAction('failed',None,(),(FlowCase(0,(SetEffect('accepted',Literal(False,ScalarType.BOOL)),)),)))
        states=(State('input',Literal(0,ScalarType.INT)),State('output',Literal('',ScalarType.STRING)),State('accepted',Literal(False,ScalarType.BOOL)))
        app=dataclasses.replace(fixture(),states=states,flow_actions=flows,native_operations=(operation,))
        return generate(app,Registry())['ios/App/Generated/AppModel.swift'].content

    def test_context_suspension_and_generation_are_independent(self):
        for context in ('main','worker'):
            source=native_operation_effect(effect(context),contract(context))
            self.assertIn('try await NativeOperation_async'+context+'.invoke',source)
            self.assertIn('Task.detached' if context=='worker' else 'Task { @MainActor @Sendable',source)
            work=source.split('let nativeWork =',1)[1].split('nativeWorkerTask = Task',1)[0]
            self.assertNotIn('self.',work)
            self.assertIn('withTaskCancellationHandler',source)
            self.assertLess(source.index('catch { outcome'),source.index('self.f_ok'))
        no_throw=native_operation_effect(effect(),contract(throws=False))
        self.assertIn('= await NativeOperation_asyncmain.invoke',no_throw)
        self.assertNotIn('try await NativeOperation_asyncmain.invoke',no_throw)
        model=self.model()
        self.assertIn('deinit { nativeWorkerTask?.cancel()',model)
        self.assertIn('nativeWorkerGeneration &+= 1; nativeWorkerTask?.cancel(); nativeWorkerTask = nil',model)

    @unittest.skipUnless(shutil.which('xcrun'),'Swift6 SDK required')
    def test_generated_model_compiles_with_main_actor_async_operation(self):
        source=self.model()+'''
final class NativeHTTPTransport { func close() {} }
enum NativeEffectFailure: Error { case responseLimit }
@MainActor enum NativeOperation_asyncmain {
 static func invoke(_ value:Int32) async throws -> String { try await Task.sleep(nanoseconds:1);return String(value) }
}
'''
        result=subprocess.run(['xcrun','swiftc','-swift-version','6','-emit-sil','-o','/dev/null','-'],input=source,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)

    @unittest.skipUnless(shutil.which('xcrun'),'Swift6 SDK required')
    def test_native_compiler_rejects_non_sendable_actor_crossing(self):
        source=self.model()+"""
final class NativeHTTPTransport { func close() {} }
enum NativeEffectFailure: Error { case responseLimit }
final class NonSendableNativeReference { var text="reference" }
actor NativeService { let owned=NonSendableNativeReference();func load() -> NonSendableNativeReference { owned } }
@MainActor enum NativeOperation_asyncmain {
 static func invoke(_ value:Int32) async throws -> String {
  let reference = await NativeService().load()
  return reference.text
 }
}
"""
        result=subprocess.run(['xcrun','swiftc','-swift-version','6','-emit-sil','-o','/dev/null','-'],input=source,text=True,capture_output=True)
        self.assertNotEqual(result.returncode,0,result.stderr)
        self.assertIn('non-sendable',result.stderr.lower())

    @unittest.skipUnless(shutil.which('xcrun'),'Swift6 SDK required')
    def test_native_suspension_error_cancellation_staleness_and_weak_lifetime(self):
        main=native_operation_effect(effect(),contract())
        background=native_operation_effect(effect('worker'),contract('worker'))
        source='''import Foundation
actor Probe {
 var starts=0,cancellations=0
 func start(){starts += 1}
 func cancelled(){cancellations += 1}
 func counts()->(Int,Int){(starts,cancellations)}
}
let probe=Probe()
enum NativeEffectFailure: Error { case responseLimit }
@MainActor enum NativeOperation_asyncmain {
 static func invoke(_ code:Int32) async throws -> String {
  MainActor.preconditionIsolated();await probe.start()
  do { try await Task.sleep(nanoseconds:120_000_000) } catch {
   await probe.cancelled()
   if code != 1 { throw error }
  }
  MainActor.preconditionIsolated()
  if code == -1 { throw NativeEffectFailure.responseLimit }
  if code == 9 { return String(repeating:"é",count:4_194_305) }
  return "main"+String(code)
 }
}
func assertWorker() { precondition(!Thread.isMainThread) }
enum NativeOperation_asyncworker {
 static func invoke(_ code:Int32) async throws -> String {
  assertWorker();await probe.start();try await Task.sleep(nanoseconds:10_000_000);assertWorker()
  return "worker"+String(code)
 }
}
@MainActor final class Model {
 var s_input:Int32=0;var s_output="original";var successes=0;var failures=0;var chain=false
 var nativeWorkerGeneration:UInt64=0;var nativeWorkerTask:Task<Void,Never>?
 deinit { nativeWorkerTask?.cancel() }
 func f_ok(_ navigate:@escaping (String)->Void) {
  MainActor.preconditionIsolated();successes += 1
  if chain { chain=false;s_input=8;worker(navigate) }
 }
 func f_failed(_ n:(String)->Void) { MainActor.preconditionIsolated();failures += 1 }
 func stop() { nativeWorkerGeneration &+= 1;nativeWorkerTask?.cancel();nativeWorkerTask=nil }
 func run(_ navigate:@escaping (String)->Void) {
'''+main+'''
 }
 func worker(_ navigate:@escaping (String)->Void) {
'''+background+'''
 }
}
@main struct Check {
 @MainActor static func pause(_ ms:UInt64) async { try? await Task.sleep(nanoseconds:ms*1_000_000) }
 @MainActor static func until(_ test:()->Bool) async {
  let deadline=Date().addingTimeInterval(3)
  while !test() { precondition(Date()<deadline);await pause(5) }
 }
 @MainActor static func started(after:Int) async {
  let deadline=Date().addingTimeInterval(3)
  while await probe.counts().0 <= after { precondition(Date()<deadline);await pause(5) }
 }
 @MainActor static func main() async {
  let m=Model();m.s_input=4;let starts=await probe.counts().0;m.run({_ in});m.s_input=99
  await started(after:starts);precondition(m.s_output=="original")
  await until { m.successes==1 };precondition(m.s_output=="main4")
  m.s_input = -1;m.run({_ in});await until { m.failures==1 };precondition(m.s_output=="main4")
  m.s_input=9;m.run({_ in});await until { m.failures==2 };precondition(m.s_output=="main4")
  m.s_input=1;let staleStarts=await probe.counts().0;m.run({_ in});await started(after:staleStarts)
  m.s_input=2;m.worker({_ in});await until { m.successes==2 };await pause(150)
  precondition(m.s_output=="worker2" && m.failures==2 && m.successes==2)
  let before=await probe.counts();m.s_input=3;m.run({_ in});await started(after:before.0);m.stop();await pause(150)
  let after=await probe.counts();precondition(after.1>before.1 && m.successes==2 && m.failures==2)
  var disposable:Model?=Model();weak var weakModel=disposable;let counts=await probe.counts()
  disposable!.run({_ in});await started(after:counts.0);disposable=nil;precondition(weakModel==nil)
  await pause(150);let cancelled=await probe.counts();precondition(cancelled.1>counts.1)
  m.chain=true;m.s_input=5;m.run({_ in});await until { m.successes==4 };precondition(m.s_output=="worker8")
 }
}
'''
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'main.swift';binary=Path(d)/'check';path.write_text(source)
            compiled=subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(path),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(compiled.returncode,0,compiled.stderr)
            run=subprocess.run([str(binary)],capture_output=True,text=True,timeout=15)
            self.assertEqual(run.returncode,0,run.stderr)
