"""Execute the emitted worker and flow on a real Kotlin/JVM toolchain."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from types import SimpleNamespace
from dcflight.backends.android_flow import NATIVE_WORKER, NATIVE
from dcflight.ir import Reference, ScalarType
from dcflight.flow_ir import NativeOperationEffect
import test_android_native_operation_flow as operation_tests

class AndroidWorkerOperationTests(unittest.TestCase):
    def emitted(self):
        flow=operation_tests.AndroidNativeOperationFlowTests().flow()
        contract=flow.app.native_operations[0]
        flow.app.native_operations=(SimpleNamespace(**{**vars(contract),'execution':'worker'}),)
        return flow.effect(NativeOperationEffect('normalize',(Reference('value',ScalarType.STRING),),'token','success','failure'))

    def test_worker_snapshots_and_lifecycle(self):
        effect=self.emitted()
        self.assertIn('val nativeInput0 = s_value',effect)
        self.assertLess(effect.index('effects.assertNativeMain()'),effect.index('val nativeInput0'))
        self.assertIn('invoke(nativeInput0)',effect)
        self.assertNotIn('invoke(s_value)',effect)
        self.assertIn('operationWorker.cancel()',NATIVE)
        self.assertIn('operationWorker.close()',NATIVE)
        self.assertIn('operationMain.post',NATIVE)
        http_cancel=NATIVE[NATIVE.index('fun cancel()'):NATIVE.index('fun close()')]
        self.assertNotIn('operationWorker',http_cancel)
        self.assertNotIn('operationMain',http_cancel)
        from dcflight.flow_ir import CancelEffect
        self.assertIn('effects.cancelAll()',operation_tests.AndroidNativeOperationFlowTests().flow().effect(CancelEffect()))
        self.assertNotIn('catch(error:Throwable)',NATIVE_WORKER)

    def test_zero_argument_worker_has_no_empty_statement(self):
        flow=operation_tests.AndroidNativeOperationFlowTests().flow()
        contract=flow.app.native_operations[0]
        flow.app.native_operations=(SimpleNamespace(**{**vars(contract),'parameters':(),'execution':'worker'}),)
        source=flow.effect(NativeOperationEffect('normalize',(),'token','success','failure'))
        self.assertIn('NativeOperation_normalize.invoke()',source)
        self.assertNotIn('{ ;',source)

    def test_real_kotlin_worker_concurrency(self):
        compiler=os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP')
        if not compiler:self.skipTest('Set DCFLIGHT_KOTLIN_COMPILER_CP and JAVA_HOME for native JVM test')
        java=Path(os.environ['JAVA_HOME'])/'bin'
        start=NATIVE.index('fun nativeString(')
        decoder=NATIVE[start:NATIVE.index('fun string(',start)]
        source=NATIVE_WORKER+'\n'+r'''
object MainQueue {
 val owner=Thread.currentThread()
 val queue=java.util.concurrent.LinkedBlockingQueue<()->Unit>()
 fun checkMain(){check(Thread.currentThread()===owner)}
 fun next(){val action=queue.poll(5,java.util.concurrent.TimeUnit.SECONDS)?:error("completion timeout");action()}
 fun drain(){while(true){val action=queue.poll()?:break;action()}}
}
class NativeEffects {
 fun assertNativeMain(){MainQueue.checkMain()}
 val worker=NativeOperationWorker({ MainQueue.queue.put(it) },{MainQueue.checkMain()})
 fun <T> nativeOperation(op:()->T,ok:(T)->Unit,fail:()->Unit)=worker.submit(op,ok,fail)
 DECODER
}
class NativeNavigationPort:(String)->Unit {var alive=true;override fun invoke(value:String){}}
object NativeOperation_normalize {
 var operation:(String)->String={it}
 fun invoke(input:String):String {check(Thread.currentThread()!==MainQueue.owner);return operation(input)}
}
class Model {
 val effects=NativeEffects();var s_value="";var s_token="prior";var success=0;var failure=0
 var successThrows=false;var failureThrows=false
 fun f_success(navigate:(String)->Unit){MainQueue.checkMain();success++;if(successThrows)error("callback")}
 fun f_failure(navigate:(String)->Unit){MainQueue.checkMain();failure++;if(failureThrows)error("failure callback")}
 fun execute(navigate:(String)->Unit) { EFFECT }
}
fun waitFor(latch:java.util.concurrent.CountDownLatch){check(latch.await(5,java.util.concurrent.TimeUnit.SECONDS))}
fun main(){
 MainQueue.checkMain()
 val m=Model()
 try {
  // Scalar snapshot, worker invocation, and main-thread publication.
  m.s_value="snapshot";m.execute{};m.s_value="changed";MainQueue.next();check(m.s_token=="snapshot"&&m.success==1)
  // Keep an uncooperative operation running while replacing 100 queued calls.
  val entered=java.util.concurrent.CountDownLatch(1);val release=java.util.concurrent.CountDownLatch(1)
  NativeOperation_normalize.operation={input->if(input=="blocked"){entered.countDown();while(release.count>0){try{release.await()}catch(e:InterruptedException){}}};input}
  m.s_value="blocked";m.execute{};waitFor(entered)
  repeat(100){m.s_value="queued$it";m.execute{}}
  release.countDown()
  while(m.success<2)MainQueue.next()
  MainQueue.drain();check(m.s_token=="queued99"&&m.success==2&&m.failure==0)
  // Completed but unpublished result must also be invalidated.
  m.s_value="cancelled";m.execute{}
  val pending=MainQueue.queue.poll(5,java.util.concurrent.TimeUnit.SECONDS)?:error("pending timeout")
  m.effects.worker.cancel();pending();check(m.s_token=="queued99"&&m.success==2)
  // Exception preserves result; callback exceptions escape on main.
  NativeOperation_normalize.operation={throw IllegalArgumentException("native")}
  m.execute{};MainQueue.next();check(m.failure==1&&m.s_token=="queued99")
  m.failureThrows=true;m.execute{};var escaped=false;try{MainQueue.next()}catch(e:IllegalStateException){escaped=true};check(escaped);m.failureThrows=false
  NativeOperation_normalize.operation={it};m.s_value="committed";m.successThrows=true;m.execute{}
  escaped=false;try{MainQueue.next()}catch(e:IllegalStateException){escaped=true};check(escaped&&m.s_token=="committed"&&m.failure==2);m.successThrows=false
  // Fatal JVM errors reach the uncaught handler, never the authored failure flow.
  val fatal=java.util.concurrent.CountDownLatch(1)
  val prior=Thread.getDefaultUncaughtExceptionHandler()
  Thread.setDefaultUncaughtExceptionHandler {_,error->if(error is AssertionError)fatal.countDown() else prior?.uncaughtException(Thread.currentThread(),error)}
  try {NativeOperation_normalize.operation={throw AssertionError("fatal")};m.execute{};waitFor(fatal);MainQueue.drain();check(m.failure==2)} finally {Thread.setDefaultUncaughtExceptionHandler(prior)}
  // Closing invalidates a result already posted and rejects subsequent work.
  NativeOperation_normalize.operation={it};m.s_value="closed";m.execute{}
  val closing=MainQueue.queue.poll(5,java.util.concurrent.TimeUnit.SECONDS)?:error("close timeout")
  m.effects.worker.close();closing();val calls=m.success;m.execute{};MainQueue.drain();check(m.s_token=="committed"&&m.success==calls)
  println("9 actual Kotlin worker concurrency checks passed")
 }finally{m.effects.worker.close()}
}
'''
        source=source.replace('DECODER',decoder).replace('EFFECT',self.emitted())
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'Checks.kt').write_text(source)
            compiled=subprocess.run([str(java/'java'),'-cp',compiler,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',compiler,'-d',folder,str(root/'Checks.kt')],capture_output=True,text=True)
            self.assertEqual(0,compiled.returncode,compiled.stdout+compiled.stderr)
            run=subprocess.run([str(java/'java'),'-cp',folder+os.pathsep+compiler,'ChecksKt'],capture_output=True,text=True,timeout=40)
            self.assertEqual(0,run.returncode,run.stdout+run.stderr)
            self.assertIn('9 actual Kotlin worker concurrency checks passed',run.stdout)
