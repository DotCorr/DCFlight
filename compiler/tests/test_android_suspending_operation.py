"""Actual Kotlin completion scheduling for native operations with suspends=true."""
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from dcflight.backends.android_flow import NATIVE_WORKER,NATIVE
from dcflight.flow_ir import NativeOperationEffect
from dcflight.ir import Reference,ScalarType
import test_android_native_operation_flow as fixtures

class AndroidSuspendingOperationTests(unittest.TestCase):
    def effect(self,execution='main',suspends=True):
        flow=fixtures.AndroidNativeOperationFlowTests().flow()
        op=flow.app.native_operations[0]
        flow.app.native_operations=(SimpleNamespace(**{**vars(op),'execution':execution,'suspends':suspends}),)
        return flow.effect(NativeOperationEffect('normalize',(Reference('value',ScalarType.STRING),),'token','success','failure'))

    def test_execution_and_suspension_independent(self):
        self.assertIn('effects.nativeOperationMain(',self.effect())
        self.assertIn('val nativeInput0 = s_value',self.effect())
        self.assertIn('effects.nativeOperation(',self.effect('worker'))
        self.assertIn('effects.nativeOperation(',self.effect('worker',False))
        self.assertNotIn('nativeInput0',self.effect('main',False))
        self.assertNotIn('nativeOperationMain(',self.effect('main',False))
        self.assertIn('fun cancelAll() { operationWorker.cancel();cancel() }',NATIVE)

    def test_real_kotlin_deferred_main_and_mixed_cancellation(self):
        compiler=os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP')
        if not compiler:self.skipTest('Set DCFLIGHT_KOTLIN_COMPILER_CP and JAVA_HOME')
        java=Path(os.environ['JAVA_HOME'])/'bin'
        source=NATIVE_WORKER+'\n'+r'''
object Loop {
 val owner=Thread.currentThread();val queue=java.util.concurrent.LinkedBlockingQueue<()->Unit>()
 fun assertMain(){check(Thread.currentThread()===owner)}
 fun next(){(queue.poll(5,java.util.concurrent.TimeUnit.SECONDS)?:error("timeout"))()}
 fun drain(){while(true){val f=queue.poll()?:break;f()}}
}
class NativeEffects {
 val lane=NativeOperationWorker({Loop.queue.put(it)},{Loop.assertMain()})
 fun assertNativeMain(){Loop.assertMain()}
 fun nativeString(value:String)=value
 fun <T> nativeOperationMain(f:()->T,ok:(T)->Unit,bad:()->Unit)=lane.submitMain(f,ok,bad)
}
class NativeNavigationPort:(String)->Unit {var alive=true;override fun invoke(value:String){}}
object NativeOperation_normalize { var count=0;var op:(String)->String={it};fun invoke(value:String):String{Loop.assertMain();count++;return op(value)} }
class Model {
 val effects=NativeEffects();var s_value="";var s_token="prior";var ok=0;var bad=0;var callbackThrows=false
 fun f_success(navigate:(String)->Unit){Loop.assertMain();ok++;if(callbackThrows)error("callback")}
 fun f_failure(navigate:(String)->Unit){Loop.assertMain();bad++;if(callbackThrows)error("callback")}
 fun invoke(navigate:(String)->Unit){ EFFECT }
}
fun main(){
 Loop.assertMain();val m=Model();val lane=m.effects.lane
 try {
  m.s_value="snapshot";m.invoke{};m.s_value="changed";check(m.ok==0&&NativeOperation_normalize.count==0);Loop.next();check(m.s_token=="snapshot"&&m.ok==1)
  repeat(1000){m.s_value="value$it";m.invoke{}};check(Loop.queue.size==1);Loop.next();check(m.s_token=="value999"&&NativeOperation_normalize.count==2)
  m.invoke{};lane.cancel();Loop.next();check(m.ok==2)
  m.s_value="afterCancel";m.invoke{};Loop.next();check(m.s_token=="afterCancel")
  NativeOperation_normalize.op={throw IllegalArgumentException()};m.invoke{};Loop.next();check(m.bad==1&&m.s_token=="afterCancel")
  m.callbackThrows=true;m.invoke{};var escaped=false;try{Loop.next()}catch(e:IllegalStateException){escaped=true};check(escaped&&m.bad==2)
  NativeOperation_normalize.op={it};m.invoke{};escaped=false;try{Loop.next()}catch(e:IllegalStateException){escaped=true};check(escaped&&m.bad==2);m.callbackThrows=false
  NativeOperation_normalize.op={throw AssertionError()};m.invoke{};var fatal=false;try{Loop.next()}catch(e:AssertionError){fatal=true};check(fatal&&m.bad==2);NativeOperation_normalize.op={it}
  // A newer main invocation supersedes even a worker that ignores interruption.
  val entered=java.util.concurrent.CountDownLatch(1);val release=java.util.concurrent.CountDownLatch(1);val done=java.util.concurrent.CountDownLatch(1)
  lane.submit({entered.countDown();while(release.count>0){try{release.await()}catch(e:InterruptedException){}};done.countDown();"stale"},{error("stale worker")},{error("stale worker failure")})
  check(entered.await(5,java.util.concurrent.TimeUnit.SECONDS));m.s_value="newMain";m.invoke{};Loop.next();check(m.s_token=="newMain");release.countDown();check(done.await(5,java.util.concurrent.TimeUnit.SECONDS))
  // A newer worker supersedes pending main without executing its operation.
  val before=NativeOperation_normalize.count;m.invoke{};var workerDone=false
  lane.submit({check(Thread.currentThread()!==Loop.owner);"newWorker"},{Loop.assertMain();workerDone=true},{error("worker failed")})
  while(!workerDone)Loop.next();Loop.drain();check(NativeOperation_normalize.count==before)
  m.invoke{};lane.close();Loop.drain();m.invoke{};check(Loop.queue.isEmpty())
  println("10 actual Kotlin suspending operation checks passed")
 }finally{lane.close()}
}
'''
        source=source.replace('EFFECT',self.effect())
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'Checks.kt';path.write_text(source)
            compiled=subprocess.run([str(java/'java'),'-cp',compiler,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',compiler,'-d',folder,str(path)],capture_output=True,text=True)
            self.assertEqual(0,compiled.returncode,compiled.stdout+compiled.stderr)
            result=subprocess.run([str(java/'java'),'-cp',folder+os.pathsep+compiler,'ChecksKt'],capture_output=True,text=True,timeout=30)
            self.assertEqual(0,result.returncode,result.stdout+result.stderr)
            self.assertIn('10 actual Kotlin suspending operation checks passed',result.stdout)
