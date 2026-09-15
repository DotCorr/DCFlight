import os,shutil,subprocess,tempfile,unittest
from pathlib import Path
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_sequence import emit_sequence
SDK='''package java.lang {
 public final class Class<T> implements java.lang.invoke.TypeDescriptor.OfField<java.lang.Class<?>> {
 }
}
package java.lang.invoke {
 public interface TypeDescriptor.OfField<F extends java.lang.invoke.TypeDescriptor.OfField<F>> {
  method public abstract F arrayType();
 }
}
package java.util {
 public interface List<E> {
  method public abstract E get(int);
  method public abstract boolean add(E);
 }
 public class ArrayList<E> implements java.util.List<E> {
  ctor public ArrayList();
 }
}
package sample {
 public class Restricted<T extends java.lang.Number> {
  method public T get();
 }
}
'''
class NestedWildcardTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);source=self.root/'sdk';source.write_text(SDK);self.db=self.root/'catalog.sqlite';index_android(self.db,source);self.api=NativeAPI(self.db)
 def request(self,typ):return {'platform':'android','id':'java.util.List#get(int)','receiver':{'ref':'items','type':typ},'arguments':[{'literal':0}]}
 def test_nested_unbounded_argument_preserves_result(self):
  out=self.api.emit(self.request('java.util.List<java.lang.Class<?>>'));self.assertEqual(out['resultType'],'java.lang.Class<?>')
  inherited=self.api.emit(self.request('java.util.ArrayList<java.lang.Class<?>>'));self.assertEqual(inherited['resultType'],'java.lang.Class<?>')
 def test_capture_and_bounded_wildcards_stay_rejected(self):
  for typ in ('java.util.List<?>','java.util.List<? extends java.lang.Class<?>>','java.util.List<java.lang.Class<? extends java.lang.Number>>','java.util.List<java.lang.Class<?,?>>'):
   with self.subTest(typ=typ),self.assertRaises(ValueError):self.api.emit(self.request(typ))
 def test_owner_bound_is_not_erased(self):
  with self.assertRaisesRegex(ValueError,'bound'):self.api.emit({'platform':'android','id':'sample.Restricted#get()','receiver':{'ref':'v','type':'sample.Restricted<java.lang.Class<?>>'}})
 def sequence(self):return {'platform':'android','steps':[{'id':'java.util.ArrayList#<init>()','constructedType':'java.util.ArrayList<java.lang.Class<?>>','bind':'items'},{'id':'java.util.List#add(E)','receiver':{'ref':'items'},'arguments':[{'class':'java.lang.String'}]},{'id':'java.util.List#get(int)','receiver':{'ref':'items'},'arguments':[{'literal':0}],'bind':'value'}]}
 def test_constructor_and_sequence_retain_nested_type(self):
  out=emit_sequence(self.api,self.sequence());self.assertIn('new java.util.ArrayList<java.lang.Class<?>>()',out['source']);self.assertEqual(out['bindings'][-1]['type'],'java.lang.Class<?>')
  bad=self.sequence();bad['steps'][0]['constructedType']='java.util.ArrayList<?>'
  with self.assertRaises(ValueError):emit_sequence(self.api,bad)
  bad=self.sequence();bad['steps'][1]['arguments']=[{'literal':12}]
  with self.assertRaises(ValueError):emit_sequence(self.api,bad)
 def test_self_bound_inherited_class_wildcard(self):
  result=self.api.emit({'platform':'android','id':'java.lang.invoke.TypeDescriptor.OfField#arrayType()','receiver':{'ref':'value','type':'java.lang.Class<java.lang.String>'}})
  self.assertEqual(result['resultType'],'java.lang.Class<?>')
 def test_native_java_execution_and_negative_assignment(self):
  home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac');java=str(Path(home)/'bin/java') if home else shutil.which('java')
  if not javac or not java:self.skipTest('Configured JDK required')
  output=emit_sequence(self.api,self.sequence());emitted=output['source'];name=output['bindings'][-1]['nativeName'];src=self.root/'Probe.java';src.write_text('public class Probe { public static void main(String[] args){'+emitted+' if('+name+' != String.class)throw new AssertionError(); }}')
  result=subprocess.run([javac,'-Xlint:unchecked','-Werror',str(src)],capture_output=True,text=True,timeout=30);self.assertEqual(result.returncode,0,result.stderr)
  subprocess.run([java,'-cp',str(self.root),'Probe'],check=True,capture_output=True,timeout=30)
  src.write_text('class Probe { void invalid(java.util.List<java.lang.Class<?>> items){items.add(12);} }')
  result=subprocess.run([javac,str(src)],capture_output=True,text=True,timeout=30);self.assertNotEqual(result.returncode,0)
 def test_native_kotlin_preserves_java_generic_relationship(self):
  cp=os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP');home=os.environ.get('JAVA_HOME')
  if not cp or not home:self.skipTest('Configured Kotlin compiler and JDK required')
  java=Path(home)/'bin';request=self.request('java.util.List<java.lang.Class<?>>');result=self.api.emit(request)
  source=self.root/'Bridge.java';source.write_text('public class Bridge { public static '+result['resultType']+' first(java.util.List<java.lang.Class<?>> items) { return '+result['source']+'; }}')
  subprocess.run([str(java/'javac'),'-Xlint:unchecked','-Werror',str(source)],check=True,capture_output=True,timeout=30)
  kotlin=self.root/'Check.kt';kotlin.write_text('fun main(){ val values=java.util.ArrayList<Class<*>>();values.add(String::class.java);check(Bridge.first(values)==String::class.java) }')
  command=[str(java/'java'),'-cp',cp,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',cp+os.pathsep+str(self.root),'-d',str(self.root),str(kotlin)]
  result=subprocess.run(command,capture_output=True,text=True,timeout=60);self.assertEqual(result.returncode,0,result.stderr)
  subprocess.run([str(java/'java'),'-cp',cp+os.pathsep+str(self.root),'CheckKt'],check=True,capture_output=True,timeout=30)
  kotlin.write_text('fun main(){ Bridge.first(java.util.ArrayList<String>()) }')
  result=subprocess.run(command,capture_output=True,text=True,timeout=60);self.assertNotEqual(result.returncode,0)
