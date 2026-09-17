"""Run generated shared Snap model + native DC Dart against an isolated real backend."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import socket
import sqlite3
import subprocess
import sys
import time
import urllib.request
import uuid
ROOT=Path(__file__).resolve().parents[1]
COMPILER=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(COMPILER))
from dcflight.evaluated_frontend import load_evaluated
from dcflight.compiler import compile_app
from dcflight.audit import audit


def main():
    p=argparse.ArgumentParser();p.add_argument('--dcc',required=True);p.add_argument('--dart',required=True);p.add_argument('--out',required=True);p.add_argument('--simulator')
    a=p.parse_args();out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
    with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    base=f'http://127.0.0.1:{port}';source=ROOT/'shared/app.dart'
    source_evidence={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,source.with_name('logic.dart'))}
    data=load_evaluated(source,dart=a.dart);data['transport']['baseUrl']=base
    data['id']='com.dotcorr.flowtest'+uuid.uuid4().hex[:12]
    if not a.simulator:raise ValueError('Snap uses UIKit; pass --simulator for actual native execution')
    env={**os.environ,'DCDART_DART':str(Path(a.dart).absolute()),'DCFLIGHT_DCC':str(Path(a.dcc).absolute()),'SNAP_DATABASE':str(out/'backend.sqlite3')}
    os.environ.update({key:env[key] for key in ('DCDART_DART','DCFLIGHT_DCC')})
    generated=out/'generated'
    compile_app(source,generated,targets=('ios',),document=data)
    source_audit=audit(generated)
    if not source_audit['passed']:raise RuntimeError('Generated project audit failed')
    (out/'source-audit.json').write_text(json.dumps(source_audit,indent=2))
    # Consume the compiler's real ABI wrappers, header and AOT object. The
    # execution harness must never reconstruct application calling conventions.
    native_names=['AppModel.swift','NativeEffects.swift','AppLogicConversions.swift','AppLogicUTF8.swift','NativeMedia.swift','NativeDevice.swift']
    native_names=[name for name in native_names if (generated/'ios/App/Generated'/name).is_file()]
    for name in native_names:shutil.copy2(generated/'ios/App/Generated'/name,out/name)
    shutil.copy2(generated/'ios/Native/logic.h',out/'logic.h')
    shutil.copy2(generated/'ios/Native/logic-simulator.o',out/'logic.o')
    result=out/'report.json';result.unlink(missing_ok=True)
    fixture=(ROOT/'tests/fixtures/snap_shared/FlowMain.swift').read_text().replace('__BASE__',base).replace('__USERNAME__','verify'+uuid.uuid4().hex[:16]).replace('__REPORT__',str(result))
    (out/'FlowMain.swift').write_text(fixture)
    bundle=out/'SharedFlow.app';binary=bundle/('SharedFlow' if a.simulator else 'Contents/MacOS/SharedFlow');binary.parent.mkdir(parents=True,exist_ok=True)
    (bundle/('Info.plist' if a.simulator else 'Contents/Info.plist')).write_bytes(plistlib.dumps({'CFBundleIdentifier':data['id'],'CFBundleExecutable':'SharedFlow','CFBundlePackageType':'APPL','CFBundleName':'Shared flow verification','CFBundleVersion':'1'}))
    command=['swiftc','-parse-as-library','-import-objc-header',out/'logic.h',*[out/name for name in native_names],out/'FlowMain.swift',out/'logic.o','-o',binary]
    if a.simulator:
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        command[1:1]=['-sdk',sdk,'-target','arm64-apple-ios17.0-simulator']
    build=subprocess.run(command,capture_output=True,text=True);(out/'build.log').write_text(build.stdout+build.stderr)
    if build.returncode:raise RuntimeError('Native fixture compilation failed; inspect '+str(out/'build.log'))
    if a.simulator:
        from dcflight.backends.ios import PROJECT
        project=out/'project';(project/'App').mkdir(parents=True,exist_ok=True);(project/'Native').mkdir(exist_ok=True);(project/'App.xcodeproj').mkdir(exist_ok=True)
        for name in native_names:shutil.copy2(out/name,project/'App'/name)
        fixture=fixture.replace('URL(fileURLWithPath:"'+str(result)+'")','FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("flow-report.json")')
        (project/'App/FlowMain.swift').write_text(fixture)
        shutil.copy2(out/'logic.h',project/'Native/logic.h');shutil.copy2(out/'logic.o',project/'Native/logic-simulator.o')
        (project/'Native/Logic.xcconfig').write_text('SWIFT_OBJC_BRIDGING_HEADER = $(SRCROOT)/Native/logic.h\nARCHS = arm64\nOTHER_LDFLAGS = $(inherited) "$(SRCROOT)/Native/logic-simulator.o"\n')
        (project/'App.xcodeproj/project.pbxproj').write_text(PROJECT.replace('__APP_ID__',data['id']).replace('__APP_NAME__','"Shared flow test"'))
        build=subprocess.run(['xcodebuild','-project',project/'App.xcodeproj','-scheme','App','-configuration','Debug','-sdk','iphonesimulator','-destination','platform=iOS Simulator,id='+a.simulator,'-derivedDataPath',out/'build','CODE_SIGN_IDENTITY=-','CODE_SIGNING_ALLOWED=YES','build'],capture_output=True,text=True)
        (out/'xcode-build.log').write_text(build.stdout+build.stderr)
        if build.returncode:raise RuntimeError('Signed simulator build failed; inspect xcode-build.log')
        bundle=out/'build/Build/Products/Debug-iphonesimulator/App.app'
        subprocess.run(['xcrun','simctl','install',a.simulator,bundle],check=True,capture_output=True)
        container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.simulator,data['id'],'data'],text=True).strip())
        simulator_result=container/'Documents/flow-report.json';simulator_result.unlink(missing_ok=True)
    else:subprocess.run(['codesign','--force','--sign','-',bundle],check=True,capture_output=True)
    with (out/'backend.log').open('w') as log:
        backend=subprocess.Popen([sys.executable,'-m','uvicorn','snap_service.main:create_app','--factory','--host','127.0.0.1','--port',str(port),'--no-access-log','--log-level','error'],cwd=ROOT/'server',env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        for _ in range(80):
            try:
                with urllib.request.urlopen(base+'/health',timeout=1) as r:
                    if r.status==200:break
            except OSError:time.sleep(.1)
        else:raise RuntimeError('Isolated backend did not start')
        if a.simulator:
            execution=subprocess.run(['xcrun','simctl','launch',a.simulator,data['id']],capture_output=True,text=True,timeout=30)
            for _ in range(360):
                if simulator_result.exists():shutil.copy2(simulator_result,result);break
                time.sleep(.5)
        else:execution=subprocess.run([binary],capture_output=True,text=True,timeout=180)
        (out/'native.log').write_text(execution.stdout+execution.stderr)
        if not result.exists():raise RuntimeError('Native report absent; inspect native.log')
        report=json.loads(result.read_text())
        with sqlite3.connect(out/'backend.sqlite3') as database:
            remaining=database.execute('SELECT count(*) FROM users').fetchone()[0]
        report['remainingTestAccounts']=remaining
        if remaining:report['passed']=False
        report['sourceSha256']=source_evidence
        report['scope']='Actual iOS simulator generated model execution; no UI input' if a.simulator else 'Host-native generated model execution, not mobile UI execution';result.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
        if not report['passed']:raise RuntimeError('Native shared flow assertions failed')
    finally:
        backend.terminate();backend.wait(timeout=10)
        if a.simulator:
            subprocess.run(['xcrun','simctl','terminate',a.simulator,data['id']],capture_output=True)
            subprocess.run(['xcrun','simctl','uninstall',a.simulator,data['id']],capture_output=True)

if __name__=='__main__':main()
