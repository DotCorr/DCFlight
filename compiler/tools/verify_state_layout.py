"""Compile one generated state layout and named-field DC Dart body for native targets."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.state_layout import Field,FieldType,RecordLayout


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--dcc',required=True);parser.add_argument('--dart',required=True);parser.add_argument('--prelude',required=True);parser.add_argument('--out',required=True);parser.add_argument('--java-home')
    args=parser.parse_args();out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
    layout=RecordLayout('LoginState',(Field('mode',FieldType.UINT32),Field('requestId',FieldType.UINT64),Field('consent',FieldType.BOOL),Field('username',FieldType.UTF8,96)))
    shutil.copy2(args.prelude,out/'prelude.dart');(out/'state.h').write_text(layout.c_header())
    body='''
@bare
u32 submit(u64 address) {
  final state = LoginState.fromAddress(address);
  if (state.usernameLength == u32(0)) return u32(0);
  if (state.usernameLength > state.usernameCapacity) return u32(0);
  if (state.consentFlag != u8(1)) return u32(0);
  final first = Pointer<u8>.fromAddress(state.usernameAddress).value;
  if (first == u8(0)) return u32(0);
  state.mode = u32(1);
  state.requestId = state.requestId + u64(1);
  return u32(1);
}
'''
    (out/'logic.dart').write_text("import 'prelude.dart';\n"+layout.dart()+body)
    env={**os.environ,'DCDART_DART':str(Path(args.dart).absolute())}
    for target in ('host','ios-simulator-arm64','ios-arm64','android-arm64'):
        subprocess.run([args.dcc,'build','--mode','bare','--target',target,'--prelude',out/'prelude.dart',out/'logic.dart','-o',out/(target+'.o'),'--emit-header',out/(target+'.h')],env=env,check=True)
    (out/'check.c').write_text('''#include "state.h"
#include "host.h"
#include <assert.h>
#include <stdio.h>
int main(){LoginStateOwner owner;LoginState_init(&owner);uint64_t address=(uintptr_t)&owner.state;
assert(submit(address)==0);assert(LoginState_set_username(&owner,(uint8_t*)"alice",5));assert(submit(address)==0);
LoginState_set_consent(&owner,true);assert(submit(address)==1);assert(owner.state.mode==1);assert(owner.state.requestId==1);
owner.state.requestId=UINT64_C(4294967296);assert(submit(address)==1);assert(owner.state.requestId==UINT64_C(4294967297));
LoginState_wipe(&owner);for(size_t i=0;i<sizeof(owner);i++)assert(((uint8_t*)&owner)[i]==0);puts("shared named-field transition and wide request ID passed");}
''')
    subprocess.run(['clang',out/'check.c',out/'host.o','-o',out/'check'],check=True);subprocess.run([out/'check'],check=True)
    undefined=subprocess.check_output(['nm','-u',out/'host.o'],text=True).strip()
    if undefined:raise RuntimeError('Unexpected state logic undefined symbols: '+undefined)
    (out/'Storage.swift').write_text(layout.swift_adapter())
    (out/'bridge.h').write_text('#include "state.h"\n#include "host.h"\n')
    (out/'main.swift').write_text('''let state=LoginStateStorage()
try state.setConsent(true)
let copied = try state.setUsername("alice"); precondition(copied)
let effect = try state.withAddress { submit($0) }; precondition(effect == 1)
try state.withAddress { _ in
    do { try state.close(); fatalError("closed while borrowed") } catch LoginStateStorage.Failure.borrowed {}
    do { try state.setConsent(false); fatalError("mutated while borrowed") } catch LoginStateStorage.Failure.borrowed {}
}
let oversized = try state.setUsername(String(repeating:"x",count:97)); precondition(!oversized)
try state.close();try state.close()
do { _ = try state.withAddress { $0 }; fatalError("used after close") } catch LoginStateStorage.Failure.closed {}
print("Swift state lifecycle passed")
''')
    subprocess.run(['swiftc','-import-objc-header',out/'bridge.h',out/'Storage.swift',out/'main.swift',out/'host.o','-o',out/'swift-check'],check=True)
    subprocess.run([out/'swift-check'],check=True)
    if args.java_home:
        jdk=Path(args.java_home);(out/'LoginStateStorage.java').write_text(layout.java_adapter('proof'))
        (out/'state-jni.c').write_text(layout.jni_adapter('proof')+'\n#include "host.h"\nJNIEXPORT jlong JNICALL Java_proof_LifecycleTest_step(JNIEnv *e,jclass c,jlong a){(void)e;(void)c;return submit((uint64_t)a); }\n')
        (out/'LifecycleTest.java').write_text('''package proof;
class LifecycleTest {
 static native long step(long address);
 public static void main(String[] args) {
  LoginStateStorage s=new LoginStateStorage();s.setConsent(true);
  if(!s.setUsername("alice") || s.withAddress(LifecycleTest::step)!=1)throw new AssertionError();
  if(s.setUsername("x".repeat(97)) || s.setUsername("\\ud800"))throw new AssertionError();
  s.withAddress(a->{try{s.close();throw new AssertionError();}catch(IllegalStateException ok){} try{s.setConsent(false);throw new AssertionError();}catch(IllegalStateException ok){} return a;});
  s.close();s.close();try{s.withAddress(a->a);throw new AssertionError();}catch(IllegalStateException ok){}
  System.out.println("JVM JNI state lifecycle passed");
 }
}''')
        subprocess.run(['clang','-dynamiclib',out/'state-jni.c',out/'host.o','-I'+str(jdk/'include'),'-I'+str(jdk/'include/darwin'),'-o',out/'libappstate.dylib'],check=True)
        subprocess.run([jdk/'bin/javac','-d',out/'classes',out/'LoginStateStorage.java',out/'LifecycleTest.java'],check=True)
        subprocess.run([jdk/'bin/java','-Djava.library.path='+str(out),'-cp',out/'classes','proof.LifecycleTest'],check=True)
    report={'recordBytes':layout.size,'targetsCompiled':['host','ios-simulator-arm64','ios-arm64','android-arm64'],'hostExecuted':True,'swiftLifecycleExecuted':True,'jniLifecycleExecuted':bool(args.java_home),'mobileExecuted':False,'undefinedSymbols':[],'handwrittenOffsetsInLogic':False}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

if __name__=='__main__':main()
