"""Build and launch ordinary Android projects using installed native tools."""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import subprocess
from .compiler import compile_app


def choose_android_device(output: str, requested: str | None = None) -> str:
    devices = {}
    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1] in ('device', 'offline', 'unauthorized', 'recovery', 'sideload'):
            devices[parts[0]] = parts[1]
    if requested:
        if devices.get(requested) != 'device':
            raise ValueError(f'Android device {requested} is {devices.get(requested, "not connected")}. Connect and authorize it, or start its emulator.')
        return requested
    ready = [serial for serial, state in devices.items() if state == 'device']
    if len(ready) == 1: return ready[0]
    if not ready: raise ValueError('No authorized Android device is connected. Start an emulator in Android Studio or connect a phone with USB debugging enabled.')
    raise ValueError('Multiple Android devices are connected; select one with --device: ' + ', '.join(ready))


def android_doctor(sdk=None, java_home=None, gradle=None, require_device=True):
    sdk = sdk or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not sdk:
        for candidate in (Path.home() / 'Library/Android/sdk', Path.home() / 'Android/Sdk'):
            if candidate.is_dir(): sdk = candidate; break
    if not sdk or not Path(sdk).is_dir(): raise ValueError('Android SDK not found. Set ANDROID_HOME or pass --android-sdk.')
    sdk = Path(sdk).resolve()
    if not (sdk / 'platforms/android-35/android.jar').is_file(): raise ValueError('Android SDK Platform 35 is required. Install it with Android Studio SDK Manager.')
    java_home = java_home or os.environ.get('JAVA_HOME')
    if java_home:
        java_home = str(Path(java_home).resolve())
        if not (Path(java_home) / 'bin/java').is_file(): raise ValueError('JAVA_HOME does not contain a Java installation.')
    elif not shutil.which('java'): raise ValueError('Java 17 or newer is required; set JAVA_HOME or pass --java-home.')
    gradle = gradle or shutil.which('gradle')
    if not gradle or not Path(gradle).is_file(): raise ValueError('Gradle is required. Install Gradle 8.11.1 or pass --gradle with its executable path.')
    adb = sdk / 'platform-tools/adb'
    if require_device and not adb.is_file(): raise ValueError('Android SDK Platform-Tools are required to install and launch apps.')
    return {'sdk': str(sdk), 'java_home': java_home, 'gradle': str(Path(gradle).resolve()), 'adb': str(adb)}


def run_android(project, device=None, sdk=None, java_home=None, gradle=None, build_only=False,
                *, evaluate_dart=False, dart='dart'):
    root = Path(project).resolve()
    source = root / ('app.dart' if evaluate_dart else 'app.json')
    if not source.is_file(): raise ValueError('No '+source.name+' found in app directory.')
    tools = android_doctor(sdk, java_home, gradle, require_device=not build_only)
    env = os.environ.copy()
    env['ANDROID_HOME'] = tools['sdk']
    env['ANDROID_SDK_ROOT'] = tools['sdk']
    if tools['java_home']:
        env['JAVA_HOME'] = tools['java_home']
        env['PATH'] = str(Path(tools['java_home']) / 'bin') + os.pathsep + env.get('PATH', '')
    serial = None
    if not build_only:
        serial = choose_android_device(subprocess.check_output([tools['adb'], 'devices', '-l'], text=True, env=env), device)
    if evaluate_dart:
        from .evaluated_frontend import load_evaluated
        document = load_evaluated(source, dart)
        compile_app(source, root / 'native', targets=('android',), document=document)
    else:
        document = json.loads(source.read_text())
        compile_app(source, root / 'native', targets=('android',))
    work = root / '.dcflight'
    work.mkdir(exist_ok=True)
    log = work / 'build-android.log'
    print('Building your native Android app. Build log: ' + str(log), flush=True)
    with log.open('w') as stream:
        result = subprocess.run([tools['gradle'], '--no-daemon', ':app:assembleDebug'], cwd=root / 'native/android', env=env, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode: raise ValueError('Native Android build failed. See ' + str(log) + '\n' + log.read_text()[-4000:])
    apk = root / 'native/android/app/build/outputs/apk/debug/app-debug.apk'
    if not apk.is_file(): raise ValueError('Android build did not produce the expected APK: ' + str(apk))
    output = {'apk': str(apk), 'buildLog': str(log), 'edit': str(source), 'built': True}
    if build_only: return output
    bundle_id = document['id']
    subprocess.run([tools['adb'], '-s', serial, 'install', '-r', str(apk)], env=env, check=True)
    launch = subprocess.run([tools['adb'], '-s', serial, 'shell', 'am', 'start', '-W', '-n', bundle_id + '/.MainActivity'], env=env, text=True, capture_output=True)
    if launch.returncode or 'Error:' in launch.stdout or 'Error:' in launch.stderr:
        raise ValueError('Android app launch failed: ' + launch.stdout + launch.stderr)
    output.update(running=bundle_id, device=serial)
    print('Your app is running on Android device ' + serial + '.', flush=True)
    return output
