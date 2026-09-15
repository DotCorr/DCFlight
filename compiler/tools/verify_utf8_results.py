#!/usr/bin/env python3
"""Execute actual DC Dart0.1.1 object through generated Swift and JNI facades."""
import json,os,sys,subprocess,hashlib
from pathlib import Path
import argparse,shutil
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--compiler',type=Path,default=Path(__file__).resolve().parents[1])
parser.add_argument('--toolchain',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args();repo=args.compiler.resolve();r=args.output.resolve()
if r.exists():parser.error('Use a fresh output directory')
r.mkdir(parents=True);sys.path.insert(0,str(repo))
from dcflight.dcdart import compile_logic
from dcflight.shared_logic import rewrite_imports,generate_logic
from dcflight.ir import ABIType,LogicFunction,LogicModule
from types import SimpleNamespace
import importlib

def fingerprint():
    paths=[Path(__file__).resolve(),Path(__file__).resolve().parents[1]/'tests/fixtures/shared_utf8_results.dart']
    for name in ('dcflight.ir','dcflight.validate','dcflight.registry','dcflight.frontends',
                 'dcflight.flow_ir','dcflight.shared_logic','dcflight.dcdart',
                 'dcflight.backends.ios_flow','dcflight.backends.android_flow',
                 'dcflight.backends.common'):
        paths.append(Path(importlib.import_module(name).__file__).resolve())
    return {str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(set(paths))}

sources_before=fingerprint()
cfg=json.loads(args.toolchain.read_text())
os.environ['PATH']=str(Path(cfg['dart']).parent)+os.pathsep+os.environ['PATH']
os.environ.update(CI='true',DART_SUPPRESS_ANALYTICS='true',CLANG_MODULE_CACHE_PATH=str(r/'clang-cache'),SWIFT_MODULECACHE_PATH=str(r/'swift-cache'),DCFLIGHT_DCC=cfg['dcc'],DCFLIGHT_ANDROID_CLANG=cfg['androidClang'])
(r/'fixture').mkdir()
shutil.copyfile(Path(__file__).resolve().parents[1]/'tests/fixtures/shared_utf8_results.dart',r/'fixture/logic.dart')
shutil.copyfile(repo/'examples/snap-shared/prelude.dart',r/'fixture/prelude.dart')
app=SimpleNamespace(id='com.example.utf8result',logic=LogicModule('logic.dart','prelude.dart',(LogicFunction('transform',(ABIType.UTF8,ABIType.UINT32),ABIType.UTF8,64),LogicFunction('empty',(),ABIType.UTF8,1))))
artifacts=generate_logic(app,r/'fixture/app.json',('ios','android'))
for name,artifact in artifacts.items():
 p=r/'native'/name;p.parent.mkdir(parents=True,exist_ok=True)
 content=artifact.content;p.write_bytes(content if isinstance(content,bytes) else content.encode())
source=r/'fixture/logic.dart';prelude=r/'fixture/prelude.dart';host=r/'host';host.mkdir(exist_ok=True)
staged=host/'logic.dart';staged.write_text(rewrite_imports(source.read_text(),source,prelude))
artifact=compile_logic(staged,host/'object','host',prelude=prelude,dcc=cfg['dcc'],nm='/opt/homebrew/opt/llvm/bin/llvm-nm')
report={'scope':'Generated native facades executing real DC Dart0.1.1 host object; Android mobile library separately cross-compiled/audited, ART execution not yet claimed','native':[]}
def run(cmd,name):
 result=subprocess.run([str(v) for v in cmd],capture_output=True,text=True,timeout=120)
 (host/(name+'.log')).write_text(result.stdout+'\n'+result.stderr)
 report['native'].append({'name':name,'command':list(map(str,cmd)),'exitCode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
 assert result.returncode==0,result.stderr
 return result.stdout
jdk=Path(cfg['javaHome']);java=r/'native/android/app/src/main/java/com/example/utf8result/SharedLogic.java';jni=r/'native/android/native-source/logic-jni.c'
run(['clang','-dynamiclib','-I'+str(jdk/'include'),'-I'+str(jdk/'include/darwin'),jni,artifact.object,'-o',host/'libapplogic.dylib'],'jni-build')
main=host/'Main.java';main.write_text('''import com.example.utf8result.SharedLogic;
public class Main {
 static void same(String value) { if(!SharedLogic.f_transform(value,0).equals(value)) throw new AssertionError("roundtrip"); }
 public static void main(String[] args) throws Exception {
  same(""); same("a\\0b"); same("é🌍"); same("a".repeat(64));
  if(!SharedLogic.f_empty().equals("")) throw new AssertionError("empty");
  for(int mode: new int[]{1,2,3}) { try { SharedLogic.f_transform("text",mode); throw new AssertionError("missing failure"); } catch(SharedLogic.InputFailure expected) {} }
  try { SharedLogic.f_transform("a".repeat(65),0); throw new AssertionError("capacity"); } catch(SharedLogic.InputFailure expected) {}
  try { SharedLogic.f_transform("\\ud800",0); throw new AssertionError("surrogate"); } catch(SharedLogic.InputFailure expected) {}
  String retained=SharedLogic.f_transform("oldé\\0🌍",0);
  java.util.concurrent.atomic.AtomicReference<Throwable> error=new java.util.concurrent.atomic.AtomicReference<>();
  java.util.ArrayList<Thread> threads=new java.util.ArrayList<>();
  for(int i=0;i<4;i++) { final int index=i; Thread t=new Thread(()->{try{for(int j=0;j<500;j++)same("thread"+index+"é🌍"+j);}catch(Throwable failure){error.compareAndSet(null,failure);}});threads.add(t);t.start(); }
  for(Thread t:threads)t.join(); if(error.get()!=null)throw new AssertionError(error.get());
  if(!retained.equals("oldé\\0🌍"))throw new AssertionError("retained result changed");
  System.out.print("PASS:JNI_UTF8_RESULT_2000_CONCURRENT_CALLS");
 }
}''')
run([jdk/'bin/javac','-d',host,java,main],'java-build')
assert run([jdk/'bin/java','-Djava.library.path='+str(host),'-cp',host,'Main'],'java-run')=='PASS:JNI_UTF8_RESULT_2000_CONCURRENT_CALLS'
swift=r/'native/ios/App/Generated/AppLogicUTF8.swift';swiftmain=host/'Main.swift'
swiftmain.write_text('''import Foundation
@main struct Check {
 static func same(_ value: String) { do { guard try AppLogicUTF8.f_transform(value,0)==value else { fatalError("roundtrip") } } catch { fatalError("unexpected error") } }
 static func main() throws {
  same("");same("a\\0b");same("é🌍");same(String(repeating:"a",count:64))
  guard try AppLogicUTF8.f_empty()=="" else { fatalError("empty") }
  for mode: UInt32 in [1,2,3] { do { _ = try AppLogicUTF8.f_transform("text",mode);fatalError("missing failure") } catch AppLogicInputFailure.invalidInput {} }
  do { _ = try AppLogicUTF8.f_transform(String(repeating:"a",count:65),0);fatalError("capacity") } catch AppLogicInputFailure.invalidInput {}
  let retained = try AppLogicUTF8.f_transform("oldé\\0🌍",0)
  DispatchQueue.concurrentPerform(iterations:4) { index in for j in 0..<500 { same("thread\\(index)é🌍\\(j)") } }
  guard retained=="oldé\\0🌍" else {fatalError("retained result changed")}
  print("PASS:SWIFT_UTF8_RESULT_2000_CONCURRENT_CALLS",terminator:"")
 }
}''')
run(['swiftc','-import-objc-header',r/'native/ios/Native/logic.h',swift,swiftmain,artifact.object,'-o',host/'swift-check'],'swift-build')
assert run([host/'swift-check'],'swift-run')=='PASS:SWIFT_UTF8_RESULT_2000_CONCURRENT_CALLS'
# Execute generated terminal effect bodies against the real shared object.
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.backends.ios_flow import logic_call_effect
from dcflight.backends.android_flow import AndroidFlow
from dcflight.backends.android_routed import quoted
flow_document={'version':2,'id':'com.example.utf8result','name':'Results','state':{'input':'firsté','mode':0,'output':'unchanged'},
 'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':'transform','parameters':['utf8','uint32'],'returns':'utf8','maxOutputBytes':64}]},
 'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Result','body':{'id':'label','type':'text','props':{'text':'Result'}}}],
 'flowActions':[{'id':'invoke','cases':[{'code':0,'effects':[{'op':'logicCall','function':'transform','arguments':[{'ref':'input'},{'ref':'mode'}],'target':'output','success':'done','failure':'failed'}]}]},{'id':'done','cases':[{'code':0,'effects':[]}]},{'id':'failed','cases':[{'code':0,'effects':[]}]}]}
flow_app=lower(flow_document,Registry());effect=flow_app.flow_actions[0].cases[0].effects[0]
swift_effect=logic_call_effect(effect,flow_app);kotlin_effect=AndroidFlow(flow_app,quoted).effect(effect)
flow_swift=host/'Flow.swift'
flow_swift.write_text('''import Foundation
final class Model {
 var s_input="firsté"; var s_mode:Int32=0; var s_output="unchanged"; var successes=0;var failures=0
 func f_done(_ navigate:(String)->Void) {successes += 1}
 func f_failed(_ navigate:(String)->Void) {failures += 1}
 func invoke(_ navigate:(String)->Void) {\n'''+swift_effect+'''\n}
}
@main struct FlowCheck {
 static func main() {
  let model=Model();model.invoke{_ in}
  guard model.s_output=="firsté",model.successes==1,model.failures==0 else {fatalError("success")}
  for mode:Int32 in [1,2,3] {model.s_mode=mode;model.s_input="replacement";model.invoke{_ in};guard model.s_output=="firsté",model.successes==1,model.failures==Int(mode) else {fatalError("atomic failure")}}
  model.s_mode=0;model.invoke{_ in};guard model.s_output=="replacement",model.successes==2,model.failures==3 else {fatalError("recovery")}
  print("PASS:SWIFT_TERMINAL_FLOW_ATOMIC_FAILURE",terminator:"")
 }
}''')
run(['swiftc','-import-objc-header',r/'native/ios/Native/logic.h',swift,flow_swift,artifact.object,'-o',host/'swift-flow-check'],'swift-flow-build')
assert run([host/'swift-flow-check'],'swift-flow-run')=='PASS:SWIFT_TERMINAL_FLOW_ATOMIC_FAILURE'
flow_kotlin=host/'Flow.kt'
flow_kotlin.write_text('''import com.example.utf8result.SharedLogic
class Model {
 var s_input="firsté";var s_mode=0;var s_output="unchanged";var successes=0;var failures=0
 fun f_done(navigate:(String)->Unit) {successes++}
 fun f_failed(navigate:(String)->Unit) {failures++}
 fun invoke(navigate:(String)->Unit) {\n'''+kotlin_effect+'''\n}
}
fun main() {
 val model=Model();model.invoke{}
 check(model.s_output=="firsté" && model.successes==1 && model.failures==0)
 for(mode in 1..3){model.s_mode=mode;model.s_input="replacement";model.invoke{};check(model.s_output=="firsté" && model.successes==1 && model.failures==mode)}
 model.s_mode=0;model.invoke{};check(model.s_output=="replacement" && model.successes==2 && model.failures==3)
 print("PASS:KOTLIN_TERMINAL_FLOW_ATOMIC_FAILURE")
}''')
gradle_lib=Path(cfg['gradle']).resolve().parent.parent/'lib'
stdlib=next(gradle_lib.glob('kotlin-stdlib-2*.jar'))
run([jdk/'bin/java','-cp',str(gradle_lib/'*'),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-classpath',str(stdlib)+os.pathsep+str(host),'-d',host/'kotlin',flow_kotlin],'kotlin-flow-build')
assert run([jdk/'bin/java','-Djava.library.path='+str(host),'-cp',str(host/'kotlin')+os.pathsep+str(host)+os.pathsep+str(stdlib),'FlowKt'],'kotlin-flow-run')=='PASS:KOTLIN_TERMINAL_FLOW_ATOMIC_FAILURE'

report['generatorSourcesStart']=sources_before;report['generatorSourcesEnd']=fingerprint();report['compilerUnchanged']=report['generatorSourcesStart']==report['generatorSourcesEnd'];report['generatedNativeSources']={str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (r/'native').rglob('*') if p.is_file() and p.suffix in ('.c','.h','.java','.swift')};report['mobileBuilds']=json.loads((r/'native/.dcflight/logic.json').read_text());report['objectSHA256']=hashlib.sha256(artifact.object.read_bytes()).hexdigest();report['provenance']=json.loads(artifact.provenance.read_text());(r/'native-execution.json').write_text(json.dumps(report,indent=2)+'\n');assert report['compilerUnchanged'], 'Generator or harness changed during native verification';print('PAIRED_HOST_NATIVE_EXECUTION_PASS')
