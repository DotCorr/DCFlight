"""Build detached native projects and execute generated state/action code.

Requires Xcode for iOS. Android source verification requires JDK17 and an Android
platform jar; APK verification additionally needs Gradle8.11.1 and an SDK.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.audit import audit, audit_apk, FORBIDDEN
from dcflight.compiler import compile_app

ROOT = Path(__file__).resolve().parents[1]


def run(command, cwd, log, env=None):
    with log.open('w') as stream:
        result = subprocess.run([str(v) for v in command], cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, env=env)
    if result.returncode:
        raise RuntimeError('Native verification failed: ' + str(log) + '\n' + log.read_text()[-6000:])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work-dir', default=str(ROOT / '.build/native'))
    parser.add_argument('--ios', action='store_true')
    parser.add_argument('--android-jar')
    parser.add_argument('--java-home')
    parser.add_argument('--gradle')
    parser.add_argument('--android-sdk')
    args = parser.parse_args()
    if not args.ios and not args.android_jar and not args.gradle:
        parser.error('Select --ios and/or an Android SDK/toolchain option for native verification')
    work = Path(args.work_dir).resolve()
    work.mkdir(parents=True, exist_ok=True)
    report = {}
    env = os.environ.copy()
    env.pop('PYTHONPATH', None)
    if args.java_home:
        env['JAVA_HOME'] = args.java_home
        env['PATH'] = str(Path(args.java_home) / 'bin') + os.pathsep + env.get('PATH', '')
    for example in ('counter', 'catalog', 'native'):
        generated = work / (example + '-generated')
        if example == 'native':
            for target, relative in [('ios', 'ios/App/User'), ('android', 'android/app/src/main/java/com/dotcorr/escape')]:
                shutil.copytree(ROOT / 'examples/native' / target, generated / relative, dirs_exist_ok=True)
        compile_app(ROOT / 'examples' / (example + '.json'), generated)
        report[example] = audit(generated)
        if not report[example]['passed']:
            raise RuntimeError(str(report[example]))
        detached = work / (example + '-detached')
        detached.mkdir(exist_ok=True)
        for target in ('ios', 'android'):
            shutil.copytree(generated / target, detached / target, dirs_exist_ok=True)
        # Detached folders contain only native projects, not source IR, registry or compiler metadata.
        assert not (detached / '.dcflight').exists()
        if args.ios:
            build = work / (example + '-xcode')
            run(['xcodebuild', '-project', 'App.xcodeproj', '-scheme', 'App', '-sdk', 'iphonesimulator',
                 '-configuration', 'Release', '-derivedDataPath', build, 'CODE_SIGNING_ALLOWED=NO', 'build'],
                detached / 'ios', work / (example + '-ios.log'), env)
            binary = build / 'Build/Products/Release-iphonesimulator/App.app/App'
            deps = subprocess.check_output(['otool', '-L', str(binary)], text=True)
            if FORBIDDEN.search('\n'.join(deps.splitlines()[1:])):
                raise RuntimeError('Forbidden linked runtime in ' + str(binary))
            (work / (example + '-ios-dependencies.txt')).write_text(deps)
            report[example]['ios'] = 'detached Release simulator build + linked dependency scan passed'
        if args.android_jar:
            java_bin = Path(args.java_home) / 'bin' if args.java_home else Path('/usr/bin')
            classes = work / (example + '-classes')
            classes.mkdir(exist_ok=True)
            sources = sorted((detached / 'android/app/src/main/java').rglob('*.java'))
            run([java_bin / 'javac', '-classpath', args.android_jar, '-d', classes, *sources], detached, work / (example + '-javac.log'), env)
            report[example]['androidSource'] = 'compiled against real Android SDK'
        if args.gradle:
            if args.android_sdk:
                env['ANDROID_HOME'] = args.android_sdk
            run([args.gradle, '--no-daemon', ':app:assembleDebug'], detached / 'android', work / (example + '-gradle.log'), env)
            import zipfile
            apk = detached / 'android/app/build/outputs/apk/debug/app-debug.apk'
            expected = {}
            logic_report = generated / '.dcflight/logic.json'
            if logic_report.exists():
                for relative, evidence in json.loads(logic_report.read_text())['libraries'].items():
                    expected['lib/' + relative.split('/jniLibs/', 1)[1]] = evidence['sha256']
            audit_apk(apk, expected)
            run([args.gradle, '--no-daemon', ':app:dependencies', '--configuration', 'debugRuntimeClasspath'],
                detached / 'android', work / (example + '-android-dependencies.txt'), env)
            if 'No dependencies' not in (work / (example + '-android-dependencies.txt')).read_text():
                raise RuntimeError('Generated app unexpectedly has runtime library dependencies')
            report[example]['androidAPK'] = 'detached debug APK build + package scan + empty runtime classpath passed'
    # Execute identical action sequences in emitted native model code.
    generated = work / 'counter-generated'
    if args.ios:
        main = work / 'main.swift'
        main.write_text('''import Foundation
let model = AppModel()
model.a_add()
precondition(model.s_count == 1)
model.a_reset()
precondition(model.s_count == 0)
model.s_count = Int32.max
model.a_add()
precondition(model.s_count == Int32.min)
print("native Swift state/actions passed")
''')
        run(['swiftc', generated / 'ios/App/Generated/AppModel.swift', main, '-o', work / 'swift-model-test'], work, work / 'swift-model-build.log', env)
        run([work / 'swift-model-test'], work, work / 'swift-model-run.log', env)
        report['swiftActions'] = 'passed including Int32 overflow'
    if args.android_jar:
        main = work / 'ModelTest.java'
        main.write_text('''import com.dotcorr.counter.AppModel;
public class ModelTest {
    public static void main(String[] args) {
        AppModel model = new AppModel();
        model.a_add();
        if (model.s_count != 1) throw new AssertionError();
        model.a_reset();
        if (model.s_count != 0) throw new AssertionError();
        model.s_count = Integer.MAX_VALUE;
        model.a_add();
        if (model.s_count != Integer.MIN_VALUE) throw new AssertionError();
        System.out.println("native Java state/actions passed");
    }
}
''')
        classes = work / 'counter-classes'
        run([java_bin / 'javac', '-classpath', classes, '-d', classes, main], work, work / 'java-model-build.log', env)
        run([java_bin / 'java', '-classpath', classes, 'ModelTest'], work, work / 'java-model-run.log', env)
        report['javaActions'] = 'passed including Int32 overflow'
    (work / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
