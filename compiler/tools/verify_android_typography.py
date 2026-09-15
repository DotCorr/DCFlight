#!/usr/bin/env python3
"""Measure authored font metrics in native Compose; no UI gestures or screenshot claims."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.compiler import compile_app


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('work','sdk','java-home','gradle','serial','report'):p.add_argument('--'+name,required=True)
    args=p.parse_args();work=Path(args.work).absolute()
    if work.exists():raise ValueError('Use a fresh work directory')
    work.mkdir(parents=True);report=Path(args.report).absolute();report.parent.mkdir(parents=True,exist_ok=True)
    doc={'version':2,'id':'com.dotcorr.typographyprobe','name':'Typography measurement',
         'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
         'routes':[{'id':'home','title':'','body':{'id':'heading','type':'text','props':{'text':'Somewhere\nclose.'},'style':{'fontSize':40}}}]}
    source=work/'app.json';source.write_text(json.dumps(doc));native=work/'native';compile_app(source,native)
    generated=(native/'android/app/src/main/java/com/dotcorr/typographyprobe/AuthoredApplication.kt').read_text()
    assert 'style=LocalTextStyle.current.copy(lineHeight=TextUnit.Unspecified)' in generated
    gradle=native/'android/app/build.gradle'
    gradle.write_text(gradle.read_text()+"\nandroid { defaultConfig { testInstrumentationRunner 'com.dotcorr.typographyprobe.Measurement' } }\n")
    fixture=Path(__file__).parent/'fixtures/android_typography/Measurement.kt'
    destination=native/'android/app/src/androidTest/java/com/dotcorr/typographyprobe/Measurement.kt'
    destination.parent.mkdir(parents=True);destination.write_bytes(fixture.read_bytes())
    env={**os.environ,'JAVA_HOME':args.java_home,'ANDROID_HOME':args.sdk,'ANDROID_SDK_ROOT':args.sdk}
    env['PATH']=str(Path(args.java_home)/'bin')+os.pathsep+env['PATH']
    def run(command,name,cwd=work):
        result=subprocess.run([str(x) for x in command],cwd=cwd,env=env,capture_output=True,text=True,timeout=240)
        (work/name).write_text(result.stdout+result.stderr)
        if result.returncode:raise RuntimeError('Native verification failed: '+str(work/name))
        return result.stdout
    run([args.gradle,'--no-daemon',':app:assembleDebug',':app:assembleAndroidTest'],'build.log',native/'android')
    adb=[Path(args.sdk)/'platform-tools/adb','-s',args.serial]
    paths=['app/build/outputs/apk/debug/app-debug.apk','app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk']
    for index,path in enumerate(paths):run(adb+['install','-r',native/'android'/path],'install'+str(index)+'.log')
    output=run(adb+['shell','am','instrument','-w','com.dotcorr.typographyprobe.test/com.dotcorr.typographyprobe.Measurement'],'measurement.log')
    measurements=[line.split('measurement=',1)[1] for line in output.splitlines() if line.startswith('INSTRUMENTATION_RESULT: measurement=')]
    if 'INSTRUMENTATION_CODE: -1' not in output or len(measurements)!=1:raise RuntimeError('Native measurement did not pass: '+str(work/'measurement.log'))
    result={'passed':True,'measurement':json.loads(measurements[0]),'serial':args.serial,
            'fixtureSHA256':hashlib.sha256(fixture.read_bytes()).hexdigest(),
            'generatedSourceSHA256':hashlib.sha256(generated.encode()).hexdigest(),
            'scope':'Compose text measurement and generated style selection; not screenshot, touch-flow or cross-platform visual acceptance.'}
    report.write_text(json.dumps(result,indent=2));print(json.dumps(result))


if __name__=='__main__':main()
