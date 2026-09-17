#!/usr/bin/env python3
"""Local developer launcher. All machine-specific paths live in toolchain.json."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.request

ROOT=Path(__file__).resolve().parent


def run(args,env=None,cwd=None):
    subprocess.run([str(x) for x in args],env=env,cwd=cwd,check=True)


def backend(config):
    state=ROOT/'.local';state.mkdir(exist_ok=True)
    def healthy():
        try:
            with urllib.request.urlopen('http://127.0.0.1:8765/openapi.json',timeout=2) as response:
                data=json.loads(response.read(1024*1024))
            return data.get('info',{}).get('title')=='Snap private social API' and data.get('info',{}).get('version')=='0.1.0' and {'/v1/media','/v1/me','/v1/location','/v1/conversations'}<=set(data.get('paths',{}))
        except Exception:return False
    metadata=state/'backend.json'
    if healthy():
        owned=False
        if metadata.is_file():
            record=json.loads(metadata.read_text())
            try:
                identity=subprocess.check_output(['ps','-p',str(record['pid']),'-o','lstart=,command='],text=True).strip()
                owned=identity==record.get('processIdentity') and 'snap_service.main:create_app' in identity
            except subprocess.CalledProcessError:pass
        if not owned and not config.get('allowExistingBackend',False):
            raise RuntimeError('A Snap backend is already running but is not owned by this launcher. Review its identity before enabling allowExistingBackend in the local configuration.')
        print('Using the existing local Snap backend and its saved test data.',flush=True);return
    with socket.socket() as sock:
        if sock.connect_ex(('127.0.0.1',8765))==0:
            raise RuntimeError('Port 8765 is occupied by another or unhealthy service. No process was stopped.')
    database=Path(config.get('backendDatabase',str(state/'snap.sqlite3'))).resolve();database.parent.mkdir(parents=True,exist_ok=True)
    environment={**os.environ,'SNAP_DATABASE':str(database)}
    with (state/'backend.log').open('a') as stream:
        process=subprocess.Popen([config['python'],'-m','uvicorn','snap_service.main:create_app','--factory','--host','127.0.0.1','--port','8765','--no-access-log','--no-proxy-headers','--log-level','error'],cwd=Path(config.get('backendDirectory',ROOT/'backend')),env=environment,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
    identity=subprocess.check_output(['ps','-p',str(process.pid),'-o','lstart=,command='],text=True).strip()
    metadata.write_text(json.dumps({'pid':process.pid,'processIdentity':identity,'database':str(database)},indent=2))
    for _ in range(80):
        if process.poll() is not None:raise RuntimeError('Backend stopped; inspect .local/backend.log. No other process was changed.')
        if healthy():print('Local Snap backend is ready.',flush=True);return
        time.sleep(.25)
    raise RuntimeError('Backend did not become healthy. Inspect .local/backend.log.')


def main():
    config=json.loads((ROOT/'toolchain.json').read_text())
    platform=sys.argv[1] if len(sys.argv)>1 else 'ios'
    if platform not in ('ios','android'):raise ValueError('Choose ios or android')
    open_only='--open' in sys.argv[2:]
    project=Path(config.get('projectDirectory',ROOT)).resolve()
    source=Path(config.get('authoringSource',ROOT/'app.dart')).resolve()
    backend(config)
    env={**os.environ,'PYTHONPATH':config['compiler'],'DCFLIGHT_DCC':config['dcc'],'DCDART_DART':config['dart'],'DCFLIGHT_ANDROID_CLANG':config['androidClang'],'JAVA_HOME':config['javaHome'],'ANDROID_HOME':config['androidSDK'],'ANDROID_SDK_ROOT':config['androidSDK']}
    env['PATH']=str(Path(config['javaHome'])/'bin')+os.pathsep+env.get('PATH','')
    if not open_only:
        print('Generating native source from '+str(source)+'…',flush=True)
        run([config['python'],'-m','dcflight','compile',source,'--out',project,'--target',platform,'--evaluate-dart','--dart-sdk',config['dart']],env)
    if platform=='android':
        from start_android import start
        serial=start();adb=Path(config['androidSDK'])/'platform-tools/adb'
        if not open_only:
            run([config['gradle'],'--no-daemon',':app:assembleDebug'],env,project/'android')
            run([adb,'-s',serial,'install','-r',project/'android/app/build/outputs/apk/debug/app-debug.apk'])
        run([adb,'-s',serial,'shell','am','start','-n',config['applicationId']+'/.MainActivity'])
    else:
        udid=config['iosDevice']
        devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
        device=next((d for group in devices['devices'].values() for d in group if d['udid']==udid),None)
        if device is None:raise RuntimeError('Configured iOS simulator is unavailable; update iosDevice in toolchain.json.')
        if device['state']!='Booted':run(['xcrun','simctl','boot',udid])
        run(['open','-a','Simulator','--args','-CurrentDeviceUDID',udid])
        run(['xcrun','simctl','bootstatus',udid,'-b'])
        build=Path(config.get('iosBuildDirectory',ROOT/'.local/ios-build'))
        if not open_only:
            run(['xcodebuild','-project',project/'ios/App.xcodeproj','-scheme','App','-configuration','Debug','-sdk','iphonesimulator','-destination','id='+udid,'-derivedDataPath',build,'CODE_SIGNING_ALLOWED=YES','CODE_SIGN_IDENTITY=-','build'],env)
            run(['xcrun','simctl','install',udid,build/'Build/Products/Debug-iphonesimulator/App.app'])
        run(['xcrun','simctl','launch',udid,config['applicationId']])
    print('Snap is running. The local backend continues running so both platforms can communicate.',flush=True)


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,subprocess.CalledProcessError) as error:
        raise SystemExit('Snap could not start: '+str(error))
