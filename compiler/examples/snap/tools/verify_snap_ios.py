"""Run generated native Snap service/photo/policy code in an isolated signed host.

Requires an already booted iOS simulator, generated iOS project with compiled DC
Dart policy objects, Xcode, and the project's local service running. No UI taps or
production test hooks are used. Temporary accounts are deleted by the fixture.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
COMPILER=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(COMPILER))
from dcflight.backends.ios import PROJECT


def run(args,log=None):
    result=subprocess.run([str(a) for a in args],capture_output=True,text=True)
    if log:Path(log).write_text(result.stdout+result.stderr)
    if result.returncode:raise RuntimeError('Command failed: '+str(args[0])+'\n'+(result.stdout+result.stderr)[-6000:])
    return result.stdout.strip()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',required=True,type=Path,help='Generated ios directory')
    parser.add_argument('--simulator',required=True)
    parser.add_argument('--work-dir',type=Path,default=ROOT/'.build/snap-ios-integration')
    args=parser.parse_args();source=args.project.resolve();work=args.work_dir.resolve()
    project=work/'project';(project/'App').mkdir(parents=True,exist_ok=True);(project/'App.xcodeproj').mkdir(exist_ok=True)
    bundle='com.dotcorr.nativeintegration.snap'
    configuration=(source/'App/Generated/Social/Configuration.swift').read_text()
    if 'http://127.0.0.1:' not in configuration and 'http://localhost:' not in configuration:
        raise ValueError('Integration requires an explicit local-development service; production account creation refused')
    evidence={}
    for name in ('Service.swift','Configuration.swift','Camera.swift'):
        path=source/'App/Generated/Social'/name
        shutil.copy2(path,project/'App'/name);evidence[str(path.relative_to(source))]=hashlib.sha256(path.read_bytes()).hexdigest()
    shutil.copy2(ROOT/'tests/fixtures/snap_ios/IntegrationMain.swift',project/'App/IntegrationMain.swift')
    shutil.copytree(source/'Native',project/'Native',dirs_exist_ok=True)
    for name in ('logic.h','logic-simulator.o'):
        evidence['Native/'+name]=hashlib.sha256((source/'Native'/name).read_bytes()).hexdigest()
    info=plistlib.loads((project/'Native/ServiceInfo.plist').read_bytes());info['CFBundleName']='Native integration';info.pop('CFBundleURLTypes',None)
    (project/'Native/ServiceInfo.plist').write_bytes(plistlib.dumps(info))
    text=PROJECT.replace('__APP_ID__',bundle).replace('__APP_NAME__','"Native integration"').replace('GENERATE_INFOPLIST_FILE = YES;','GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Native/ServiceInfo.plist;')
    (project/'App.xcodeproj/project.pbxproj').write_text(text)
    run(['xcodebuild','-project',project/'App.xcodeproj','-scheme','App','-configuration','Debug','-sdk','iphonesimulator','-destination','platform=iOS Simulator,id='+args.simulator,'-derivedDataPath',work/'build','CODE_SIGN_IDENTITY=-','CODE_SIGNING_ALLOWED=YES','build'],work/'build.log')
    app=work/'build/Build/Products/Debug-iphonesimulator/App.app'
    subprocess.run(['xcrun','simctl','terminate',args.simulator,bundle],capture_output=True)
    run(['xcrun','simctl','install',args.simulator,app])
    container=Path(run(['xcrun','simctl','get_app_container',args.simulator,bundle,'data']))
    report=container/'Documents/integration-report.json';report.unlink(missing_ok=True)
    run(['xcrun','simctl','launch',args.simulator,bundle])
    deadline=time.monotonic()+180
    while not report.exists():
        if time.monotonic()>deadline:raise TimeoutError('Native integration report absent; see '+str(work/'build.log'))
        time.sleep(.5)
    result=json.loads(report.read_text());result['sourceSha256']=evidence
    result['fixtureSha256']=hashlib.sha256((ROOT/'tests/fixtures/snap_ios/IntegrationMain.swift').read_bytes()).hexdigest()
    result['simulator']=args.simulator;result['sdk']=run(['xcrun','--sdk','iphonesimulator','--show-sdk-version'])
    result['binarySha256']=hashlib.sha256((app/'App.debug.dylib').read_bytes()).hexdigest()
    (work/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    run(['xcrun','simctl','terminate',args.simulator,bundle])
    print(json.dumps({'passed':result['passedCount'],'failure':result['failure'],'cleanupFailures':result['cleanupFailures'],'report':str(work/'report.json')}))
    return 1 if result['failure'] or result['cleanupFailures'] else 0

if __name__=='__main__':sys.exit(main())
