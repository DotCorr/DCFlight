#!/usr/bin/env python3
"""Run a separate Android instrumentation APK against generated Snap native code.

Uses disposable backend accounts and an isolated Keystore/prefs namespace. No UI
input is injected. Instrumentation stops the target process but does not clear its
data or persisted session. Camera2 captures use only offscreen ImageReader output.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import zipfile
from verify_android_device import run, sha, dex_classes


def verify(args):
    project=args.project.resolve();work=args.work_dir.resolve();work.mkdir(parents=True,exist_ok=True)
    package='com.dotcorr.snap';test_package='com.dotcorr.snapchecks'
    target=project/'android/app/build/outputs/apk/debug/app-debug.apk'
    java=project/'android/app/src/main/java/com/dotcorr/snap'
    classes=work/'target-signatures';classes.mkdir(exist_ok=True)
    sources=[java/(name+'.java') for name in ('ApiClient','SessionStore','SharedLogic','NativeCamera')]
    run([args.java_home/'bin/javac','-cp',args.sdk/'platforms/android-35/android.jar','-d',classes,*sources])
    jar=work/'target-signatures.jar';run([args.java_home/'bin/jar','cf',jar,'-C',classes,'.'])
    (work/'settings.gradle').write_text("pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name='SnapNativeChecks'\ninclude ':app'\n")
    (work/'build.gradle').write_text("plugins { id 'com.android.application' version '8.9.2' apply false }\n")
    app=work/'app';source=app/'src/main/java/com/dotcorr/snap';source.mkdir(parents=True,exist_ok=True)
    (app/'build.gradle').write_text("plugins { id 'com.android.application' }\nandroid { namespace 'com.dotcorr.snapchecks'; compileSdk 35; defaultConfig { applicationId 'com.dotcorr.snapchecks'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 } }\ndependencies { compileOnly files('../target-signatures.jar') }\n")
    (app/'src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Native Snap Tests"/><instrumentation android:name="com.dotcorr.snap.SnapChecks" android:targetPackage="com.dotcorr.snap" android:functionalTest="true"/></manifest>\n')
    (source/'SnapChecks.java').write_text((Path(__file__).parent/'fixtures/snap_android/SnapChecks.java').read_text())
    env=os.environ.copy();env.update(ANDROID_HOME=str(args.sdk),ANDROID_SDK_ROOT=str(args.sdk),JAVA_HOME=str(args.java_home))
    (work/'build.log').write_text(run([args.gradle,'-p',work,'--no-daemon',':app:assembleDebug'],env=env,timeout=600))
    apk=app/'build/outputs/apk/debug/app-debug.apk'
    with zipfile.ZipFile(apk) as archive:
        defined=[name for item in archive.namelist() if item.endswith('.dex') for name in dex_classes(archive.read(item))]
        if any(not name.startswith('Lcom/dotcorr/snap/SnapChecks') and name != 'Lcom/dotcorr/snapchecks/R;' for name in defined):raise ValueError('Test APK contains unexpected application code')
        if any(name.startswith('lib/') for name in archive.namelist()):raise ValueError('Test APK contains native libraries')
    report={'testApk':str(apk),'testApkSha256':sha(apk),'definedFixtureClasses':defined,'targetClassesBundled':False}
    if args.build_only:return report
    adb=[args.sdk/'platform-tools/adb','-s',args.serial]
    path=run(adb+['shell','pm','path',package]).strip().removeprefix('package:')
    installed=work/'installed-target.apk';run(adb+['pull',path,installed]);
    if sha(installed)!=sha(target):raise ValueError('Installed APK does not match generated project build')
    report['targetApkSha256']=sha(target)
    session_before=hashlib.sha256(run(adb+['exec-out','run-as',package,'cat','shared_prefs/session.xml']).encode()).hexdigest()
    run(adb+['install','-r',apk])
    output=run(adb+['shell','am','instrument','-w','-r',test_package+'/com.dotcorr.snap.SnapChecks'],timeout=300)
    (work/'instrumentation.txt').write_text(output)
    match=re.search(r'^INSTRUMENTATION_RESULT: resultJson=(.*)$',output,re.M)
    if not match:raise ValueError('No instrumentation result: '+output)
    result=json.loads(match[1]);report['instrumentation']=result;report['passed']=result.get('passed') is True and 'INSTRUMENTATION_CODE: -1' in output
    session_after=hashlib.sha256(run(adb+['exec-out','run-as',package,'cat','shared_prefs/session.xml']).encode()).hexdigest()
    report['existingSessionUnchanged']=session_before==session_after
    report['passed']=report['passed'] and report['existingSessionUnchanged']
    report['androidDeviceExecuted']=True;report['serial']=args.serial
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('project','work-dir','sdk','java-home','gradle','report'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--serial',default='emulator-5580');p.add_argument('--build-only',action='store_true');args=p.parse_args()
    try:r=verify(args)
    except Exception as error:r={'passed':False,'error':str(error)}
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
    return 0 if r.get('passed') or args.build_only and 'error' not in r else 1

if __name__=='__main__':sys.exit(main())
