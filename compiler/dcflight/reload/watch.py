"""External native rebuild watcher. No helper is added to the generated app."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from ..compiler import compile_app
from ..frontends import load
from ..evaluated_frontend import load_evaluated
from ..validate import lower
from ..registry import Registry

IGNORED={'.git','.gradle','.dart_tool','.dcflight','build','dist','node_modules','__pycache__'}
EXTENSIONS={'.dart','.json','.swift','.java','.kt','.xml','.gradle','.kts','.properties','.plist','.png','.jpg','.jpeg','.xcconfig','.pbxproj','.c','.h','.m','.mm'}


def snapshot(roots,excluded=()):
    result={};excluded=tuple(Path(p).resolve() for p in excluded)
    def scan(path):
        if path.is_symlink() or any(path==p or p in path.parents for p in excluded):return
        if path.is_dir():
            for child in sorted(path.iterdir()):
                if child.name not in IGNORED:scan(child)
        elif path.is_file() and path.suffix in EXTENSIONS:
            result[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
    for root in roots:scan(Path(root).resolve())
    return result


def command(args,cwd,env,log):
    with log.open('a') as stream:
        result=subprocess.run([str(x) for x in args],cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
    if result.returncode:raise ValueError('Native command failed; see '+str(log))


def build(args,app,env,log):
    out=Path(args.out).resolve();work=out/'.dcflight/reload';work.mkdir(parents=True,exist_ok=True)
    log.write_text('')
    if args.target=='android':
        from ..android_develop import android_doctor
        tools=android_doctor(args.android_sdk,args.java_home,args.gradle,require_device=not args.build_only)
        env.update(ANDROID_HOME=tools['sdk'],ANDROID_SDK_ROOT=tools['sdk'])
        if tools['java_home']:env.update(JAVA_HOME=tools['java_home'],PATH=str(Path(tools['java_home'])/'bin')+os.pathsep+env.get('PATH',''))
        command([tools['gradle'],'--no-daemon',':app:assembleDebug'],out/'android',env,log)
        product=out/'android/app/build/outputs/apk/debug/app-debug.apk'
        if not product.is_file():raise ValueError('Native build returned no APK')
        return product,tools
    command(['xcodebuild','-project',out/'ios/App.xcodeproj','-scheme','App','-configuration','Debug',
             '-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','-derivedDataPath',work/'ios',
             'CODE_SIGNING_ALLOWED=NO','build'],out,env,log)
    product=work/'ios/Build/Products/Debug-iphonesimulator/App.app'
    if not product.is_dir():raise ValueError('Native build returned no simulator app')
    return product,{}


def deploy(args,app,product,tools,env,log):
    if args.target=='android':
        from ..android_develop import choose_android_device
        devices=subprocess.check_output([tools['adb'],'devices','-l'],env=env,text=True)
        choose_android_device(devices,args.device)
        command([tools['adb'],'-s',args.device,'install','-r',product],Path(args.out),env,log)
        command([tools['adb'],'-s',args.device,'shell','am','force-stop',app.id],Path(args.out),env,log)
        result=subprocess.run([tools['adb'],'-s',args.device,'shell','am','start','-W','-n',app.id+'/.MainActivity'],env=env,text=True,capture_output=True,timeout=60)
        if result.returncode or 'Error:' in result.stdout+result.stderr:raise ValueError('Android launch failed: '+result.stdout+result.stderr)
    else:
        # Explicit device, never pick or boot somebody else's preview implicitly.
        devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))
        selected=[d for group in devices['devices'].values() for d in group if d['udid']==args.device and d.get('isAvailable') and d['state']=='Booted']
        if not selected:raise ValueError('Select an available, already booted iOS simulator')
        command(['xcrun','simctl','install',args.device,product],Path(args.out),env,log)
        command(['xcrun','simctl','launch','--terminate-running-process',args.device,app.id],Path(args.out),env,log)


def run(args):
    source=Path(args.source).resolve();out=Path(args.out).resolve()
    if not source.is_file():raise ValueError('Authoring source does not exist')
    if not args.build_only and not args.device:raise ValueError('Choose an explicit --device or use --build-only')
    if not 0.1<=args.interval<=10:raise ValueError('Watch interval must be between 0.1 and 10 seconds')
    # Watch authoring, plus explicitly selected native user files or external imports.
    roots=[source.parent]
    extra=[Path(p).resolve() for p in args.watch]
    if out!=source.parent and out in source.parents:raise ValueError('Output must not contain the authoring directory')
    excluded=[out] if out!=source.parent else [out/'ios',out/'android']
    work=out/'.dcflight/reload';work.mkdir(parents=True,exist_ok=True)
    lock=work/'session.lock'
    try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
    except FileExistsError:raise ValueError('A reload session already owns this output; inspect '+str(lock))
    os.write(fd,str(os.getpid()).encode());os.close(fd)
    previous=None;attempted=None;identity=None
    def inputs():return {**snapshot(roots,excluded),**snapshot(extra)}
    def event(status,**values):
        record={'status':status,'time':time.time(),**values}
        print(json.dumps(record),flush=True)
        (work/'status.json').write_text(json.dumps(record,indent=2)+'\n')
    try:
        while True:
            current=inputs()
            if current==attempted:
                time.sleep(args.interval);continue
            time.sleep(args.interval)
            if current!=inputs():continue
            attempted=current
            try:
                document=load_evaluated(source,args.dart_sdk) if args.evaluate_dart else load(source)
                app=lower(document,Registry())
                if identity is not None and identity!=app.id:raise ValueError('App identity changed; start a separate session')
                identity=app.id
                event('building',mode='native-rebuild',memoryStatePreserved=False)
                compile_app(source,out,targets=(args.target,),document=document)
                env=os.environ.copy();log=work/'native-build.log'
                product,tools=build(args,app,env,log)
                if current!=inputs():
                    event('superseded',reason='Inputs changed while building; newer revision will be built')
                    if args.once:return 2
                    continue
                if not args.build_only:deploy(args,app,product,tools,env,log)
                previous=current
                event('built' if args.build_only else 'restarted',product=str(product),
                      mode='native-rebuild',memoryStatePreserved=False,persistedDataCleared=False)
                if args.once:return 0
            except (ValueError,OSError,subprocess.SubprocessError) as error:
                event('failed',error=str(error),lastSuccessfulBuildAvailable=previous is not None)
                if args.once:return 1
    finally:lock.unlink(missing_ok=True)
