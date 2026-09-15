#!/usr/bin/env python3
"""Compile every supported mutable Android SDK field assignment; no OS execution."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.platforms.android_api import AndroidAPI, JavaValue


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api', type=Path, required=True)
    parser.add_argument('--android-jar', type=Path, required=True)
    parser.add_argument('--javac', required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    api = AndroidAPI.from_file(args.api)
    fields = [m for m in api.members.values() if api.is_writable(m)]
    if not fields: raise ValueError('No writable fields found')
    with tempfile.TemporaryDirectory(prefix='native-field-writes-') as tmp:
        paths = []
        for offset in range(0, len(fields), 256):
            name = f'FieldWrites{offset // 256}'
            methods = []
            for i, member in enumerate(fields[offset:offset+256]):
                parameters = [f'{member.java_type} value']
                receiver = None
                if not member.static:
                    parameters.append(f'{member.owner} receiver')
                    receiver = JavaValue.reference('receiver', member.owner)
                expression = api.emit_set(member.id, JavaValue.reference('value', member.java_type), receiver)
                methods.append(f' static void write{i}({", ".join(parameters)}) {{ {expression.source}; }}')
            path = Path(tmp)/(name+'.java')
            path.write_text('public class '+name+' {\n'+'\n'.join(methods)+'\n}\n')
            paths.append(str(path))
        result = subprocess.run([args.javac, '-Xmaxerrs', '100', '-encoding', 'UTF-8', '-classpath', str(args.android_jar), '-d', tmp, *paths], capture_output=True, text=True)
        binaries = list(Path(tmp).glob('FieldWrites*.class'))
        clean = len(binaries)==len(paths) and not any(token in p.read_bytes().lower() for p in binaries for token in (b'dcflight',b'flutter',b'com/facebook/react',b'org/mozilla'))
    passed = result.returncode==0 and clean
    report = dict(operation='fieldWrite', sourceSha256=hashlib.sha256(args.api.read_bytes()).hexdigest(), androidJarSha256=hashlib.sha256(args.android_jar.read_bytes()).hexdigest(), writableFields=len(fields), compilationPassed=passed, generatedDependencyScanPassed=clean, executed=False, compiledFieldWriteIds=[m.id for m in fields] if passed else [], diagnostics=result.stderr, scope='All emittable writable fields in supplied SDK, assignment compilation only; no device behavior or older SDK guarantee.')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='compiledFieldWriteIds'},indent=2))
    return 0 if passed else 1


if __name__=='__main__': raise SystemExit(main())
