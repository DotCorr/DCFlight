#!/usr/bin/env python3
"""Generated Android Snap model / DC Dart AOT against an isolated real backend."""
import argparse,hashlib,json,os,re,socket,sqlite3,subprocess,sys,time,urllib.request,uuid,zipfile
from pathlib import Path

def run(args,**kw):
    r=subprocess.run(list(map(str,args)),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,**kw)
    if r.returncode:raise RuntimeError(f'{args[0]} failed ({r.returncode}): {r.stdout[-12000:]}')
    return r.stdout

def audit_artifact(root, generated, out):
    from dcflight.audit import audit_apk
    from dcflight.modules.resolve import verify
    from tools.verify_android_device import dex_classes
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    apk=generated/'android/app/build/outputs/apk/debug/app-debug.apk'
    logic=json.loads((generated/'.dcflight/logic.json').read_text())
    modules=json.loads((generated/'.dcflight/modules.json').read_text())
    lockpath=root/'examples/native-modules/maplibre-compose/module.lock.json'
    lock=verify(lockpath)
    assert len(modules['modules'])==1 and modules['modules'][0]['lockSha256']==sha(lockpath),'Module lock receipt mismatch'
    expected={'lib/'+path.split('/jniLibs/',1)[1]:info['sha256'] for path,info in logic['libraries'].items()}
    derived={}
    for item in lock['artifacts']:
        if item['extension']!='aar':continue
        with zipfile.ZipFile(lockpath.parent/item['path']) as z:
            for entry in z.namelist():
                if entry.startswith('jni/arm64-v8a/') and entry.endswith('.so'):
                    name='lib/'+entry[4:];digest=hashlib.sha256(z.read(entry)).hexdigest()
                    assert name not in derived or derived[name]==digest,'Conflicting locked library'
                    derived[name]=digest
    assert derived==modules['nativeLibraries'],'Locked native-library receipt mismatch'
    assert not (expected.keys() & derived.keys()),'Logic/module library collision'
    expected.update(derived);native=audit_apk(apk,expected);assert native['passed'],native
    defined=[];dex=[]
    with zipfile.ZipFile(apk) as z:
        for entry in sorted(n for n in z.namelist() if n.endswith('.dex')):
            data=z.read(entry);classes=dex_classes(data);defined.extend(classes)
            dex.append({'entry':entry,'sha256':hashlib.sha256(data).hexdigest(),'definedClassCount':len(classes)})
        payloads=[n for n in z.namelist() if n.lower().endswith(('.dart','.js','.wasm','.dill','.snapshot'))]
        entries=z.namelist()
    assert dex,'No DEX definitions inspected'
    prefixes=('Ldcflight/','Lio/flutter/','Lcom/facebook/react/','Lcom/facebook/hermes/','Lorg/mozilla/javascript/','Lcom/eclipsesource/v8/')
    prohibited=[name for name in defined if name.startswith(prefixes)]
    assert not prohibited and not payloads,'Forbidden runtime definition or payload'
    for build in logic['builds']:
        assert build['audit']['passed'] and not build['audit']['undefinedSymbols'] and build['compilerVersion']=='dcc 0.1.1'
    out.mkdir(parents=True,exist_ok=True)
    (out/'dex-defined-classes.json').write_text(json.dumps(sorted(defined),indent=2))
    (out/'apk-entries.json').write_text(json.dumps(entries,indent=2))
    result={'passed':True,'apkSha256':sha(apk),'exactNativeLibraryAudit':native,'expectedNativeLibraries':expected,'moduleLockSha256':sha(lockpath),'dexFiles':dex,'definedClasses':len(defined),'prohibitedDefinedNamespaces':prohibited,'runtimeSourcePayloads':payloads,'logicReceiptSha256':sha(generated/'.dcflight/logic.json'),'moduleReceiptSha256':sha(generated/'.dcflight/modules.json'),'scope':'Debug arm64 Android APK. Exact native-library bytes compared to generated DC Dart application logic and verified locked AARs; DEX definition tables and runtime payload suffixes inspected. AndroidX Compose, Kotlin and MapLibre are intentional native dependencies. This does not prove absence of every possible statically linked runtime, nor test hardware or UI.'}
    (out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--toolchain',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--serial',default='emulator-5580');p.add_argument('--audit-only',action='store_true');a=p.parse_args()
    c=json.loads(a.toolchain.read_text());root=Path(c['compiler']);out=a.out.resolve();out.mkdir(parents=True,exist_ok=a.audit_only)
    sys.path.insert(0,str(root));from dcflight.evaluated_frontend import load_evaluated
    from dcflight.compiler import compile_app
    from dcflight.audit import audit
    if a.audit_only:
        report=json.loads((out/'report.json').read_text());report['artifactAudit']=audit_artifact(root,out/'generated',out/'artifact-audit');report['passed']=report['passed'] and report['artifactAudit']['passed']
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':report['passed'],'artifactAudit':report['artifactAudit']}));return 0 if report['passed'] else 1
    compiler_hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'dcflight').rglob('*.py')}
    tag=uuid.uuid4().hex[:12];app='com.dotcorr.flowtest'+tag;checks=app+'checks';source=Path(__file__).resolve().parents[1]/'shared/app.dart'
    with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    base=f'http://127.0.0.1:{port}'
    env={**os.environ,'JAVA_HOME':c['javaHome'],'ANDROID_HOME':c['androidSDK'],'ANDROID_SDK_ROOT':c['androidSDK'],'DCFLIGHT_DCC':c['dcc'],'DCDART_DART':c['dart'],'DCFLIGHT_ANDROID_CLANG':c['androidClang'],'DCFLIGHT_NM':str(Path(c['androidClang']).with_name('llvm-nm')),'DCFLIGHT_READELF':'/opt/homebrew/opt/llvm/bin/llvm-readelf','SNAP_DATABASE':str(out/'backend.sqlite3'),'CI':'true','DART_SUPPRESS_ANALYTICS':'true'}
    os.environ.update({k:env[k] for k in ('DCFLIGHT_DCC','DCDART_DART','DCFLIGHT_ANDROID_CLANG','DCFLIGHT_NM','DCFLIGHT_READELF','JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT')})
    authored_hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,source.with_name('logic.dart'))}
    doc=load_evaluated(source,dart=c['dart']);doc['id']=app;doc['transport']['baseUrl']=base
    (out/'input.json').write_text(json.dumps(doc,indent=2))
    compile_app(source,out/'generated',targets=('android',),document=doc)
    effects=list((out/'generated/android').rglob('NativeEffects.kt'));assert len(effects)==1,effects
    transport_text=effects[0].read_text();assert f'http://10.0.2.2:{port}' in transport_text and base not in transport_text,'Generated transport does not use isolated emulator backend'
    proof=audit(out/'generated');(out/'source-audit.json').write_text(json.dumps(proof,indent=2));assert proof['passed'],proof
    project=out/'generated/android';w=out/'instrumentation';d=w/'app/src/main/java'/Path(*checks.split('.'));d.mkdir(parents=True)
    (w/'settings.gradle').write_text("pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name='SharedFlowChecks'\ninclude ':app'\n")
    (w/'build.gradle').write_text("plugins { id 'com.android.application' version '8.9.2' apply false }\n")
    (w/'app/build.gradle').write_text("plugins { id 'com.android.application' }\nandroid { namespace '"+checks+"'; compileSdk 35; defaultConfig { applicationId '"+checks+"'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 } }\n")
    (w/'app/src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Isolated shared flow checks"/><instrumentation android:name="'+checks+'.SharedFlowChecks" android:targetPackage="'+app+'" android:functionalTest="true"/></manifest>')
    fixture=(Path(__file__).parent/'fixtures/snap_shared_android/SharedFlowChecks.java').read_text().replace('__APP_ID__',app).replace('__CHECK_ID__',checks).replace('__BASE__',f'http://10.0.2.2:{port}')
    (d/'SharedFlowChecks.java').write_text(fixture)
    for name,path in [('app',project),('instrumentation',w)]:
        try:log=run([c['gradle'],'-p',path,'--no-daemon','--max-workers=2',':app:assembleDebug'],env=env,timeout=900)
        except Exception as e:(out/(name+'-build.log')).write_text(str(e));raise
        (out/(name+'-build.log')).write_text(log)
    artifact_audit=audit_artifact(root,out/'generated',out/'artifact-audit')
    adb=[Path(c['androidSDK'])/'platform-tools/adb','-s',a.serial];owned=[];backend=None;report={'passed':False};cleanup=[]
    def package_exists(name):
        r=subprocess.run(list(map(str,adb+['shell','pm','path',name])),capture_output=True,text=True,timeout=30)
        if r.returncode not in (0,1):raise RuntimeError('Package query failed: '+r.stderr)
        return 'package:' in r.stdout
    try:
        for name in (app,checks):
            if package_exists(name):raise RuntimeError('Refusing existing QA identity '+name)
        with (out/'backend.log').open('w') as log:backend=subprocess.Popen([c['python'],'-m','uvicorn','snap_service.main:create_app','--factory','--host','127.0.0.1','--port',str(port),'--no-access-log','--log-level','error'],cwd=root/'examples/snap/server',env=env,stdout=log,stderr=subprocess.STDOUT)
        for _ in range(100):
            if backend.poll() is not None:raise RuntimeError('Isolated backend exited')
            try:
                with urllib.request.urlopen(base+'/health',timeout=1) as r:
                    if r.status==200:break
            except OSError:time.sleep(.1)
        else:raise RuntimeError('Backend health timeout')
        for name,path in [(app,project),(checks,w)]:
            owned.append(name);run(adb+['install',path/'app/build/outputs/apk/debug/app-debug.apk'],timeout=90)
        text=run(adb+['shell','am','instrument','-w','-r',checks+'/'+checks+'.SharedFlowChecks'],timeout=300);(out/'instrumentation.txt').write_text(text)
        match=re.search(r'^INSTRUMENTATION_RESULT: resultJson=(.*)$',text,re.M)
        if not match:raise RuntimeError('Native report absent')
        report=json.loads(match[1])
        with sqlite3.connect(out/'backend.sqlite3') as db:remaining=db.execute('SELECT count(*) FROM users').fetchone()[0]
        report['remainingTestAccounts']=remaining;report['passed']=report['passed'] and remaining==0
    except BaseException as error:
        report['passed']=False;report['harnessError']=type(error).__name__+': '+str(error)
    finally:
        for name in reversed(owned):
            try:run(adb+['uninstall',name],timeout=45);cleanup.append({'package':name,'removed':True})
            except Exception as error:cleanup.append({'package':name,'removed':False,'error':str(error)});report['passed']=False
        if backend:
            backend.terminate()
            try:backend.wait(timeout=10)
            except subprocess.TimeoutExpired:backend.kill();backend.wait(timeout=10)
        try:run(adb+['shell','am','start','-n',c['applicationId']+'/.MainActivity'],timeout=30);report['originalForegroundRestored']=True
        except Exception as error:report['originalForegroundRestored']=False;report['foregroundError']=str(error);report['passed']=False
        current_hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'dcflight').rglob('*.py')}
        report['compilerUnchanged']=current_hashes==compiler_hashes
        if not report['compilerUnchanged']:report['passed']=False
        report['compilerSha256']=compiler_hashes
        report['apkSha256']={name:hashlib.sha256((path/'app/build/outputs/apk/debug/app-debug.apk').read_bytes()).hexdigest() for name,path in [('target',project),('instrumentation',w)]}
        report['artifactAudit']=artifact_audit
        report['cleanup']=cleanup;report['qaApplicationId']=app;report['qaInstrumentationId']=checks
        report['sourceSha256']=authored_hashes
        report['authoredSourceUnchanged']=authored_hashes=={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (source,source.with_name('logic.dart'))}
        if not report['authoredSourceUnchanged']:report['passed']=False
        report['generatedSha256']={str(p.relative_to(out/'generated')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'generated').rglob('*') if p.is_file() and not any(k in p.parts for k in ('build','.gradle'))}
        report['scope']='Actual generated Android model, generated DC Dart wrappers/AOT and isolated real backend; hardware capture, permission/GPS and UI layout excluded.'
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ('generatedSha256','compilerSha256')}))
    return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
