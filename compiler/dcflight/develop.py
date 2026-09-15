"""Development commands. None of this module ships in a generated native app."""
import json
from pathlib import Path
import plistlib
import subprocess
import sys
from .compiler import compile_app
from .registry import Registry
from .validate import lower


def create_project(destination, name='My First App', bundle_id='com.example.myapp'):
    root = Path(destination).absolute()
    data = json.loads((Path(__file__).parent / 'data/starter.json').read_text())
    data.update(name=name, id=bundle_id)
    data['root']['children'][0]['props']['text'] = name
    lower(data, Registry())
    if root.exists() or root.is_symlink():
        raise ValueError('Project folder already exists; choose a new folder: ' + str(root))
    root.mkdir(parents=True)
    source = root / 'app.json'
    source.write_text(json.dumps(data, indent=2) + '\n')
    compile_app(source, root / 'native')
    (root / 'README.md').write_text('''# Your native app

Edit `app.json` to change the app. `native/ios` and `native/android` contain ordinary native projects.

From your installed dcflight compiler:

```
dcflight run /path/to/this/project
```

This builds and launches iOS in Simulator. Run it again after saving changes.
This is native rebuild/relaunch, not state-preserving hot reload.

Open `native/ios/App.xcodeproj` in Xcode or `native/android` in Android Studio for native development.
User-owned native files are preserved. Conflicting edits to generated files stop regeneration.
''')
    return {'project': str(root), 'edit': str(source), 'next': 'dcflight run ' + str(root)}


def choose_simulator(devices, requested=None):
    available = [device for group in devices['devices'].values() for device in group if device.get('isAvailable')]
    if requested:
        matches = [d for d in available if d['udid'] == requested]
        if not matches:
            raise ValueError('Requested Simulator is unavailable: ' + requested)
        return matches[0]
    for candidate in (lambda d: d['state'] == 'Booted', lambda d: 'iPhone' in d['name'], lambda d: True):
        matches = [d for d in available if candidate(d)]
        if matches:
            return matches[0]
    raise ValueError('No iOS Simulator is installed. Install an iOS runtime in Xcode Settings > Components.')


def run_ios(project, requested_device=None, *, evaluate_dart=False, dart='dart'):
    if sys.platform != 'darwin':
        raise ValueError('Launching iOS requires macOS and Xcode; native Android projects can be opened in Android Studio.')
    root = Path(project).resolve()
    source = root / ('app.dart' if evaluate_dart else 'app.json')
    if not source.is_file():
        raise ValueError('No '+source.name+' found in app directory.')
    # Check toolchain before generation; report actual diagnostics, not an absent preview.
    subprocess.run(['xcodebuild', '-version'], check=True, stdout=subprocess.DEVNULL)
    compile_app(source, root / 'native', targets=('ios',), evaluate_dart=evaluate_dart, dart=dart)
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True))
    device = choose_simulator(devices, requested_device)
    identity = device['udid']
    if device['state'] != 'Booted':
        print('Starting ' + device['name'] + '…', flush=True)
        subprocess.run(['xcrun', 'simctl', 'boot', identity], check=True)
    subprocess.run(['open', '-a', 'Simulator'], check=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', identity, '-b'], check=True)
    work = root / '.dcflight'
    work.mkdir(exist_ok=True)
    log = work / 'build-ios.log'
    derived = work / 'ios-build'
    print('Building your native app. Build log: ' + str(log), flush=True)
    with log.open('w') as stream:
        result = subprocess.run(['xcodebuild', '-project', str(root / 'native/ios/App.xcodeproj'),
            '-scheme', 'App', '-configuration', 'Debug', '-destination', 'id=' + identity,
            '-derivedDataPath', str(derived), 'CODE_SIGNING_ALLOWED=YES', 'CODE_SIGN_IDENTITY=-', 'build'], stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise ValueError('Native build failed. See ' + str(log) + '\n' + log.read_text()[-4000:])
    product = derived / 'Build/Products/Debug-iphonesimulator/App.app'
    with (product / 'Info.plist').open('rb') as stream:
        bundle_id = plistlib.load(stream)['CFBundleIdentifier']
    subprocess.run(['xcrun', 'simctl', 'install', identity, str(product)], check=True)
    subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', identity, bundle_id], check=True)
    print('Your app is running in ' + device['name'] + '.', flush=True)
    return {'running': bundle_id, 'simulator': device['name'], 'edit': str(source), 'buildLog': str(log)}
