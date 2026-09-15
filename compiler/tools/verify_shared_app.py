#!/usr/bin/env python3
"""Build detached iOS/Android apps with real shared DC Dart logic."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.compiler import compile_app
from dcflight.audit import audit, audit_apk, FORBIDDEN


def run(args, cwd, log):
    with log.open('w') as stream:
        status = subprocess.run([str(a) for a in args], cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    if status.returncode:
        raise RuntimeError(str(log) + '\n' + log.read_text()[-5000:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dcc', required=True)
    parser.add_argument('--prelude', required=True)
    parser.add_argument('--dart', required=True)
    parser.add_argument('--android-clang', required=True)
    parser.add_argument('--gradle', required=True)
    parser.add_argument('--android-sdk', required=True)
    parser.add_argument('--java-home', required=True)
    parser.add_argument('--output', default='build/shared-app')
    parser.add_argument('--run-ios', action='store_true')
    parser.add_argument('--install-ios', action='store_true')
    args = parser.parse_args()
    os.environ.update(DCFLIGHT_DCC=args.dcc, DCDART_DART=args.dart, DCFLIGHT_ANDROID_CLANG=args.android_clang,
                      ANDROID_HOME=args.android_sdk, JAVA_HOME=args.java_home)
    root = Path(args.output).resolve()
    root.mkdir(parents=True, exist_ok=True)
    examples = Path(__file__).resolve().parents[1] / 'examples/shared_logic'
    for name in ('logic.dart', 'app.json'):
        shutil.copyfile(examples / name, root / name)
    shutil.copyfile(args.prelude, root / 'prelude.dart')
    generated = root / 'generated'
    compile_app(root / 'app.json', generated)
    second = compile_app(root / 'app.json', generated)
    if second['write'] or second['delete']:
        raise RuntimeError('Identical shared logic generation must be a no-op: ' + str(second))
    before = (generated / '.dcflight/logic.json').read_bytes()
    compile_app(root / 'app.json', generated, targets=('ios',))
    if (generated / '.dcflight/logic.json').read_bytes() != before:
        raise RuntimeError('iOS-only regeneration changed Android logic evidence')
    report = {'sourceAudit': audit(generated), 'generationNoop': True}
    if not report['sourceAudit']['passed']:
        raise RuntimeError(str(report))
    detached = root / 'detached'
    for target in ('ios', 'android'):
        shutil.copytree(generated / target, detached / target, dirs_exist_ok=True)
    if (detached / '.dcflight').exists():
        raise RuntimeError('Detached build contains compiler metadata')
    with ThreadPoolExecutor(max_workers=2) as pool:
        ios = pool.submit(run, ['xcodebuild', '-project', 'App.xcodeproj', '-scheme', 'App', '-sdk', 'iphonesimulator',
             '-configuration', 'Release', '-derivedDataPath', root / 'xcode', 'CODE_SIGNING_ALLOWED=NO', 'build'], detached / 'ios', root / 'ios-build.log')
        android = pool.submit(run, [args.gradle, '--no-daemon', ':app:assembleDebug'], detached / 'android', root / 'android-build.log')
        ios.result()
        android.result()
    evidence = json.loads((generated / '.dcflight/logic.json').read_text())
    expected = {'lib/' + relative.split('/jniLibs/', 1)[1]: info['sha256'] for relative, info in evidence['libraries'].items()}
    apk = detached / 'android/app/build/outputs/apk/debug/app-debug.apk'
    report['androidAPK'] = audit_apk(apk, expected)
    app = root / 'xcode/Build/Products/Release-iphonesimulator/App.app'
    dependencies = subprocess.check_output(['otool', '-L', str(app / 'App')], text=True)
    if FORBIDDEN.search('\n'.join(dependencies.splitlines()[1:])):
        raise RuntimeError('Prohibited iOS runtime dependency')
    report['iosApp'] = {'built': True, 'dependencies': dependencies.splitlines()[1:]}
    if args.run_ios:
        main = root / 'main.swift'
        main.write_text('''import Foundation
let model = AppModel()
model.a_add()
precondition(model.s_count == 1)
model.s_count = 41
model.a_add()
precondition(model.s_count == 42)
model.a_reset()
precondition(model.s_count == 0)
model.a_discount()
precondition(model.s_total == 6000)
model.a_gcd()
precondition(model.s_gcd == 6)
print("Generated app model executed shared DC Dart logic: passed")
''')
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
        native = detached / 'ios/Native'
        model = detached / 'ios/App/Generated'
        executable = root / 'model-test'
        run(['xcrun', 'swiftc', '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator', '-import-objc-header', native / 'logic.h',
             model / 'AppModel.swift', model / 'AppLogicConversions.swift', main, native / 'logic-simulator.o', '-o', executable], root, root / 'model-build.log')
        run(['xcrun', 'simctl', 'spawn', 'booted', executable], root, root / 'model-run.log')
        report['iosModelExecution'] = (root / 'model-run.log').read_text().strip()
    if args.install_ios:
        run(['xcrun', 'simctl', 'install', 'booted', app], root, root / 'install-ios.log')
        run(['xcrun', 'simctl', 'launch', 'booted', 'com.dotcorr.sharedlogic'], root, root / 'launch-ios.log')
    (root / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(root / 'report.json')


if __name__ == '__main__':
    main()
