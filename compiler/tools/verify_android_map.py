#!/usr/bin/env python3
"""Exercise the exact installed generated NativeMap using a separate test APK."""
import argparse,hashlib,json,os,re,subprocess,zipfile
from pathlib import Path

def run(command,**kw):return subprocess.check_output([str(x) for x in command],stderr=subprocess.STDOUT,text=True,**kw)
p=argparse.ArgumentParser()
for name in ('project','work','sdk','java-home','gradle'):p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--serial',default='emulator-5580');a=p.parse_args();w=a.work.resolve();w.mkdir(parents=True,exist_ok=True);project=a.project.resolve()/'android'
(w/'settings.gradle').write_text((project/'settings.gradle').read_text())
(w/'build.gradle').write_text((project/'build.gradle').read_text())
d=w/'app/src/main/java/com/dotcorr/mapchecks';d.mkdir(parents=True,exist_ok=True)
jars=w/'compile-only';jars.mkdir(exist_ok=True);inputs=[]
for item in (project/'app/libs').iterdir():
 if item.suffix=='.jar':inputs.append(item)
 elif item.suffix=='.aar':
  with zipfile.ZipFile(item) as z:
   if 'classes.jar' in z.namelist():
    dest=jars/(item.stem+'.jar');dest.write_bytes(z.read('classes.jar'));inputs.append(dest)
classes=project/'app/build/tmp/kotlin-classes/debug'
compiled=jars/'generated-classes.jar'
with zipfile.ZipFile(compiled,'w',zipfile.ZIP_DEFLATED) as z:
 for path in classes.rglob('*'):
  if path.is_file():z.write(path,path.relative_to(classes))
inputs.append(compiled)
(w/'app/build.gradle').write_text("plugins { id 'com.android.application'; id 'org.jetbrains.kotlin.android'; id 'org.jetbrains.kotlin.plugin.compose' }\nandroid { namespace 'com.dotcorr.mapchecks'; compileSdk 35; defaultConfig { applicationId 'com.dotcorr.mapchecks'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }; buildFeatures { compose true }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }; kotlinOptions { jvmTarget='17' } }\ndependencies { compileOnly files("+','.join(repr(str(x)) for x in inputs)+") }\n")
(w/'app/src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Native map checks"/><instrumentation android:name="com.dotcorr.mapchecks.MapChecks" android:targetPackage="com.dotcorr.snapshared"/></manifest>')
(d/'MapChecks.kt').write_text((Path(__file__).parent/'fixtures/android_device/MapChecks.kt').read_text())
env={**os.environ,'JAVA_HOME':str(a.java_home),'ANDROID_HOME':str(a.sdk)}
try:(w/'build.log').write_text(run([a.gradle,'-p',w,'--no-daemon','--max-workers=1',':app:assembleDebug'],env=env,timeout=300))
except subprocess.CalledProcessError as e:(w/'build.log').write_text(e.output);raise
adb=[a.sdk/'platform-tools/adb','-s',a.serial];target=project/'app/build/outputs/apk/debug/app-debug.apk';sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
installed=run(adb+['shell','pm','path','com.dotcorr.snapshared']).strip().removeprefix('package:');run(adb+['pull',installed,w/'installed.apk']);assert sha(target)==sha(w/'installed.apk')
run(adb+['install','-r',w/'app/build/outputs/apk/debug/app-debug.apk']);result=run(adb+['shell','am','instrument','-w','com.dotcorr.mapchecks/.MapChecks'],timeout=180);(w/'instrumentation.txt').write_text(result);match=re.search(r'resultJson=(\{.*\})',result);report=json.loads(match[1]) if match else {'passed':False,'error':result};report['apkSha256']=sha(target);report['scope']='Exact generated NativeMap native style/annotation/update/recovery APIs; no touchscreen inputs';(w/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));raise SystemExit(0 if report.get('passed') else 1)
