#!/usr/bin/env python3
"""Execute generated native Android camera resources using an offscreen surface."""
import argparse,json,os,re,subprocess,hashlib
from pathlib import Path

def run(args,**kw):
 try:return subprocess.check_output([str(a) for a in args],stderr=subprocess.STDOUT,text=True,**kw)
 except subprocess.CalledProcessError as error:
  print(error.output);raise
def main():
 p=argparse.ArgumentParser()
 for k in ('project','work','sdk','java-home','gradle'):p.add_argument('--'+k,type=Path,required=True)
 p.add_argument('--serial',default='emulator-5580');a=p.parse_args();w=a.work;w.mkdir(parents=True,exist_ok=True)
 (w/'settings.gradle').write_text("pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name='DeviceChecks'\ninclude ':app'\n")
 (w/'build.gradle').write_text("plugins { id 'com.android.application' version '8.9.2' apply false }\n")
 d=w/'app/src/main/java/com/dotcorr/devicechecks';d.mkdir(parents=True,exist_ok=True)
 (w/'app/build.gradle').write_text("plugins { id 'com.android.application' }\nandroid { namespace 'com.dotcorr.devicechecks'; compileSdk 35; defaultConfig { applicationId 'com.dotcorr.devicechecks'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 } }\n")
 (w/'app/src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Native camera resource checks"/><instrumentation android:name="com.dotcorr.devicechecks.DeviceChecks" android:targetPackage="com.dotcorr.snapshared" android:functionalTest="true"/></manifest>')
 (d/'DeviceChecks.java').write_text((Path(__file__).parent/'fixtures/android_device/DeviceChecks.java').read_text())
 env={**os.environ,'JAVA_HOME':str(a.java_home),'ANDROID_HOME':str(a.sdk),'ANDROID_SDK_ROOT':str(a.sdk)}
 (w/'build.log').write_text(run([a.gradle,'-p',w,'--no-daemon','--max-workers=2',':app:assembleDebug'],env=env,timeout=600))
 adb=[a.sdk/'platform-tools/adb','-s',a.serial];target=a.project/'android/app/build/outputs/apk/debug/app-debug.apk'
 installed=run(adb+['shell','pm','path','com.dotcorr.snapshared']).strip().removeprefix('package:');run(adb+['pull',installed,w/'installed.apk'])
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 assert sha(target)==sha(w/'installed.apk'),'Installed target mismatch'
 run(adb+['install','-r',w/'app/build/outputs/apk/debug/app-debug.apk'])
 run(adb+['shell','pm','grant','com.dotcorr.snapshared','android.permission.CAMERA'])
 text=run(adb+['shell','am','instrument','-w','-r','com.dotcorr.devicechecks/com.dotcorr.devicechecks.DeviceChecks'],timeout=180);(w/'instrumentation.txt').write_text(text)
 match=re.search(r'^INSTRUMENTATION_RESULT: resultJson=(.*)$',text,re.M)
 report=json.loads(match[1]) if match else {'passed':False,'error':'No native result'}
 report['apkSha256']=sha(target);report['scope']='Actual generated Android Camera2 resources and coordinate rounding; no UI input'
 (w/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
