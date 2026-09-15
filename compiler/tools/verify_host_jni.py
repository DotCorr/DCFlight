#!/usr/bin/env python3
"""Execute the shared-logic example's exact generated JNI glue on a host JVM.

This verifies JNI and application-model behavior on macOS, not Android device
execution. The same DC Dart source is compiled for host; Android objects cannot
be linked into a host dylib and are never relabeled or retargeted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.dcdart import compile_logic
from dcflight.shared_logic import rewrite_imports
from dcflight.validate import lower
from dcflight.registry import Registry


def execute(command, env=None):
    result = subprocess.run([str(x) for x in command], env=env, capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Host JNI verification failed: ' + ' '.join(map(str, command)) + '\n' + result.stdout + result.stderr)
    return result.stdout


def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(project, generated, dcc, java_home, nm, dart=None):
    if sys.platform != 'darwin': raise ValueError('This JNI fixture currently requires macOS')
    project, generated, java_home = Path(project).resolve(), Path(generated).resolve(), Path(java_home).resolve()
    app = lower(json.loads((project / 'app.json').read_text()), Registry())
    required = {'increment', 'discountedTotal', 'greatestCommonDivisor'}
    if not app.logic or not required <= {f.name for f in app.logic.functions}:
        raise ValueError('Use the shared-logic example with increment, discountedTotal and greatestCommonDivisor exports')
    java = generated / 'android/app/src/main/java' / app.id.replace('.', '/')
    native = generated / 'android/native-source'
    inputs = [java / 'SharedLogic.java', java / 'AppModel.java', native / 'logic-jni.c', native / 'logic.h']
    if not all(p.is_file() for p in inputs): raise ValueError('Generate the example Android native source before verification')
    env = os.environ.copy()
    if dart: env['DCDART_DART'] = str(Path(dart).resolve())
    source, prelude = (project / app.logic.source).resolve(), (project / app.logic.prelude).absolute()
    harness = '''package __PACKAGE__;
public final class HostJniChecks {
    private static int checks;
    private static void equal(int actual, int expected) { checks++; if(actual != expected) throw new AssertionError(actual + " != " + expected); }
    private static void rejected(Runnable operation) { checks++; try { operation.run(); } catch(IllegalArgumentException expected) { return; } throw new AssertionError("Expected range rejection"); }
    public static void main(String[] args) {
        AppModel model = new AppModel();
        model.a_add(); model.a_add(); equal(model.s_count, 2);
        model.a_reset(); equal(model.s_count, 0);
        model.a_discount(); equal(model.s_total, 6000);
        model.a_gcd(); equal(model.s_gcd, 6);
        equal(SharedLogic.f_discountedTotal(2500, 3, 101), 0);
        equal(SharedLogic.f_discountedTotal(2500, 3, 100), 0);
        equal(SharedLogic.f_discountedTotal(2500, 3, 0), 7500);
        equal(SharedLogic.f_greatestCommonDivisor(0, 0), 0);
        equal(SharedLogic.f_greatestCommonDivisor(0, 18), 18);
        equal(SharedLogic.f_greatestCommonDivisor(2147483647, 1), 1);
        rejected(() -> SharedLogic.f_increment(-1));
        rejected(() -> SharedLogic.f_increment(Integer.MAX_VALUE));
        rejected(() -> SharedLogic.f_discountedTotal(-1, 1, 0));
        rejected(() -> SharedLogic.f_greatestCommonDivisor(1, -1));
        model.s_count = -1; rejected(model::a_add); equal(model.s_count, -1);
        System.out.println("checks=" + checks);
    }
}
'''.replace('__PACKAGE__', app.id)
    with tempfile.TemporaryDirectory(prefix='dcflight-host-jni-') as folder:
        root = Path(folder)
        staged = root / 'logic.dart'
        staged.write_text(rewrite_imports(source.read_text(), source, prelude))
        compiled = compile_logic(staged, root / 'compiled', 'host', prelude=prelude, dcc=dcc, nm=nm, env=env)
        signatures = lambda path: re.findall(r'(?:u?int32_t|bool)\s+\w+\([^;]*\);', path.read_text())
        if signatures(compiled.header) != signatures(native / 'logic.h'):
            raise ValueError('Host and generated Android logic ABI declarations differ')
        for item in inputs: shutil.copy2(item, root / item.name)
        harness_path = root / 'HostJniChecks.java'; harness_path.write_text(harness)
        library = root / 'libapplogic.dylib'
        execute(['clang', '-dynamiclib', '-fPIC', '-Wall', '-Werror', '-I' + str(java_home / 'include'), '-I' + str(java_home / 'include/darwin'), root / 'logic-jni.c', compiled.object, '-o', library], env)
        dependencies = execute(['otool', '-L', library], env)
        linked = [line.strip().split(' ')[0] for line in dependencies.splitlines()[1:]]
        if any(not (name == str(library) or name.startswith('/usr/lib/') or name.startswith('/System/Library/')) for name in linked):
            raise ValueError('Host JNI library has unexpected non-system dependencies: ' + str(linked))
        execute([java_home / 'bin/javac', '-d', root, root / 'SharedLogic.java', root / 'AppModel.java', harness_path], env)
        result = execute([java_home / 'bin/java', '-Djava.library.path=' + str(root), '-cp', root, app.id + '.HostJniChecks'], env).strip()
        if result != 'checks=16': raise ValueError('Host JNI fixture did not complete all expected assertions: ' + result)
        report = {'passed': True, 'executionEnvironment': 'macOS host JVM with host-target DC Dart native object', 'androidDeviceExecuted': False,
            'checks': 16, 'sourceSha256': digest(source), 'preludeSha256': digest(prelude),
            'exactGeneratedInputs': {str(p): digest(p) for p in inputs},
            'hostObjectSha256': digest(compiled.object), 'hostLibrarySha256': digest(library),
            'objectAudit': json.loads(compiled.provenance.read_text())['audit'],
            'compilerVersion': json.loads(compiled.provenance.read_text())['compilerVersion'],
            'linkedDependencies': linked, 'result': result,
            'scope': 'Executes generated Java model and exact JNI C glue; verifies arithmetic, branches, loop and unsigned ABI range checks on host only.'}
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    parser.add_argument('--generated', required=True)
    parser.add_argument('--dcc', required=True)
    parser.add_argument('--java-home', required=True)
    parser.add_argument('--nm', default='llvm-nm')
    parser.add_argument('--dart')
    parser.add_argument('--report', required=True)
    args = parser.parse_args()
    report = verify(args.project, args.generated, args.dcc, args.java_home, args.nm, args.dart)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
