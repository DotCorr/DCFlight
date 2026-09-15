import unittest
from dataclasses import dataclass,replace
from dcflight.backends.android_flow import AndroidFlow,NATIVE
from dcflight.backends.android_routed import quoted
from dcflight.ir import ScalarType,Reference,Literal
from dcflight.native_operation import OperationContract,OperationParameter
from test_android_flow import flow_fixture

from dcflight.flow_ir import NativeOperationEffect

class AndroidNativeOperationFlowTests(unittest.TestCase):
 def flow(self,kind=ScalarType.STRING):
  app=flow_fixture()
  contract=OperationContract('normalize',(OperationParameter('input',ScalarType.STRING),),kind,True)
  from types import SimpleNamespace
  values=dict(vars(app));values['native_operations']=(contract,)
  return AndroidFlow(SimpleNamespace(**values),quoted)
 def test_direct_call_is_validated_before_atomic_commit(self):
  source=self.flow().effect(NativeOperationEffect('normalize',(Reference('value',ScalarType.STRING),),'token','success','failure'))
  self.assertIn('effects.nativeString(NativeOperation_normalize.invoke(s_value))',source)
  self.assertIn('catch(error: Exception)',source)
  self.assertNotIn('Throwable',source)
  self.assertLess(source.index('catch(error: Exception)'),source.index('s_token = nativeResult'))
  self.assertLess(source.index('s_token = nativeResult'),source.index('f_success(navigate)'))
  self.assertIn('f_failure(navigate); return',source)
 def test_integer_and_boolean_are_native_scalar_results(self):
  for kind,target,expected in ((ScalarType.INT,'count','Int'),(ScalarType.BOOL,'enabled','Boolean')):
   source=self.flow(kind).effect(NativeOperationEffect('normalize',(Literal('abc',ScalarType.STRING),),target,'success','failure'))
   self.assertIn('val nativeResult: '+expected,source)
   self.assertIn('NativeOperation_normalize.invoke("abc")',source)
   self.assertNotIn('nativeString',source)
 def test_unknown_contract_wrong_target_and_arity_fail_closed(self):
  for effect in (NativeOperationEffect('missing',(),'token','success','failure'),NativeOperationEffect('normalize',(),'token','success','failure'),NativeOperationEffect('normalize',(Literal('x',ScalarType.STRING),),'count','success','failure')):
   with self.assertRaises(ValueError):self.flow().effect(effect)
 def test_string_result_null_unicode_and_byte_bound(self):
  start=NATIVE.index('fun nativeString(');source=NATIVE[start:NATIVE.index('fun string(',start)]
  for term in ('value?:throw','text.length>8388608','CodingErrorAction.REPORT','encoded.remaining()>8388608'):
   self.assertIn(term,source)

 def test_generated_effect_executes_on_host_jvm_when_configured(self):
  import os,tempfile,subprocess
  from pathlib import Path
  compiler=os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP')
  if not compiler:self.skipTest('Set DCFLIGHT_KOTLIN_COMPILER_CP and JAVA_HOME for host Kotlin execution')
  java=Path(os.environ['JAVA_HOME'])/'bin'
  effect=self.flow().effect(NativeOperationEffect('normalize',(Reference('value',ScalarType.STRING),),'token','success','failure'))
  start=NATIVE.index('fun nativeString(');decoder=NATIVE[start:NATIVE.index('fun string(',start)]
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory)
   (root/'NativeOperation_normalize.java').write_text(r'''public class NativeOperation_normalize { public static String invoke(String input) throws Throwable {switch(input){case "throw":throw new IllegalStateException();case "fatal":throw new AssertionError();case "null":return null;case "bad":return "\uD800";case "large":return "\u20AC".repeat(3000000);default:return input;}}}''')
   (root/'Checks.kt').write_text('class NativeEffects { '+decoder+' }\nclass Model { val effects=NativeEffects();var s_value="";var s_token="prior";var success=0;var failure=0;var successThrows=false;fun f_success(navigate:(String)->Unit){success++;if(successThrows)throw IllegalStateException("success")}\nfun f_failure(navigate:(String)->Unit){failure++}\nfun execute(navigate:(String)->Unit) { '+effect+' } }\n'+r'''fun main(){val m=Model();m.s_value="😀";m.execute{};check(m.s_token=="😀"&&m.success==1);for(value in listOf("throw","null","bad","large")){m.s_token="prior";m.s_value=value;val n=m.failure;m.execute{};check(m.s_token=="prior"&&m.failure==n+1)};m.s_value="fatal";val n=m.failure;var fatal=false;try{m.execute{}}catch(e:AssertionError){fatal=true};check(fatal&&m.failure==n);m.s_value="committed";m.successThrows=true;var successError=false;try{m.execute{}}catch(e:IllegalStateException){successError=true};check(successError&&m.s_token=="committed"&&m.failure==n);println("7 native effect behavior checks passed")}''')
   subprocess.run([str(java/'javac'),str(root/'NativeOperation_normalize.java')],check=True,capture_output=True)
   result=subprocess.run([str(java/'java'),'-cp',compiler,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',compiler+os.pathsep+str(root),'-d',str(root),str(root/'Checks.kt')],capture_output=True,text=True)
   self.assertEqual(0,result.returncode,result.stdout+result.stderr)
   result=subprocess.run([str(java/'java'),'-cp',str(root)+os.pathsep+compiler,'ChecksKt'],capture_output=True,text=True)
   self.assertEqual(0,result.returncode,result.stdout+result.stderr)
   self.assertIn('7 native effect behavior checks passed',result.stdout)
