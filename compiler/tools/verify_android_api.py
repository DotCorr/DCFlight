#!/usr/bin/env python3
"""Compile deterministic SDK-driven direct API call probes; never execute them.

Compilation proves source compatibility, not permissions, device behavior or API
availability on earlier releases. No runtime component is added to generated code.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import json
import re
import shutil
import shlex
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.platforms.android_api import AndroidAPI, JavaValue
from dcflight.ios_verification import compiler_sources
from dcflight.android_class_dependencies import dependency_references


def select_members(api, limit):
    groups = defaultdict(list)
    for m in api.members.values():
        if m.emittable:
            groups[(m.owner.rsplit('.', 1)[0], m.kind)].append(m)
    selected = []
    # Prefer common facilities, then spread probes across all package/member kinds.
    priorities = [
        'android.widget.Button#<init>(android.content.Context)',
        'android.widget.TextView#setText(java.lang.CharSequence)',
        'android.view.View#setVisibility(int)',
        'android.content.Intent#<init>(java.lang.String)',
        'android.os.Bundle#putString(java.lang.String,java.lang.String)',
        'android.os.BaseBundle#putString(java.lang.String,java.lang.String)',
        'android.net.Uri#parse(java.lang.String)',
        'android.app.Notification.Builder#<init>(android.content.Context,java.lang.String)',
        'android.content.Context#getSystemService(java.lang.String)',
        'android.content.SharedPreferences#getString(java.lang.String,java.lang.String)',
        'android.hardware.camera2.CameraManager#getCameraIdList()',
        'android.media.MediaPlayer#<init>()',
        'android.location.LocationManager#isProviderEnabled(java.lang.String)',
        'android.os.Vibrator#hasVibrator()',
        'android.Manifest.permission#CAMERA',
    ]
    for member_id in priorities:
        if member_id in api.members and api.members[member_id].emittable: selected.append(api.members[member_id])
    selected = selected[:limit]
    seen = {m.id for m in selected}
    level = 0
    while len(selected) < limit:
        previous = len(selected)
        for key in sorted(groups):
            if level < len(groups[key]):
                member = groups[key][level]
                if member.id not in seen:
                    selected.append(member); seen.add(member.id)
                    if len(selected) == limit: break
        if len(selected) == previous and all(level >= len(g) for g in groups.values()): break
        level += 1
    return selected


def probe_source(api, member, index):
    declarations, arguments = [], []
    receiver = None
    if member.kind != 'ctor' and not member.static:
        declarations.append(f'{member.owner} receiver')
        receiver = JavaValue.reference('receiver', member.owner)
    for i, parameter in enumerate(member.parameters):
        name = f'arg{i}'
        declarations.append(f'{parameter.java_type} {name}')
        arguments.append(JavaValue.reference(name, parameter.java_type))
    expression = api.emit(member.id, arguments, receiver)
    statement = expression.source + ';'
    if expression.java_type != 'void': statement = f'{expression.java_type} result = {statement}'
    return f'  public static void probe{index}({", ".join(declarations)}) throws Throwable {{ {statement} }}'




def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api', required=True, type=Path)
    parser.add_argument('--android-jar', required=True, type=Path)
    parser.add_argument('--javac', default='javac')
    parser.add_argument('--limit', type=int, default=256)
    parser.add_argument('--sdk', type=int, default=35)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--android-core', action='store_true', help='Resolve java.* against supplied Android boot stubs, not host JDK')
    args = parser.parse_args()
    if not 1 <= args.limit <= 50000: parser.error('--limit must be 1..50000')
    if args.sdk<1:parser.error('--sdk must be positive')
    compiler=shutil.which(args.javac) or args.javac
    compiler_version=subprocess.run([compiler,'-version'],capture_output=True,text=True,check=True).stdout.strip()
    verifier_digest = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    compiler_identity = compiler_sources()
    api_bytes = args.api.read_bytes()
    api_digest = hashlib.sha256(api_bytes).hexdigest()
    api = AndroidAPI(api_bytes.decode("utf-8"),api_level=args.sdk)
    members = select_members(api, args.limit)
    with tempfile.TemporaryDirectory(prefix='android-api-conformance-') as temp:
        sdk_snapshot=Path(temp)/'android.jar'
        shutil.copyfile(args.android_jar,sdk_snapshot)
        sdk_digest=hashlib.sha256(sdk_snapshot.read_bytes()).hexdigest()
        paths = []
        for offset in range(0, len(members), 512):
            class_name = f'AndroidApiConformance{offset // 512}'
            source = '// Generated native Java API compilation probes.\npublic class ' + class_name + ' {\n' + '\n'.join(probe_source(api, m, i) for i, m in enumerate(members[offset:offset + 512])) + '\n}\n'
            path = Path(temp) / (class_name + '.java')
            path.write_text(source)
            paths.append(str(path))
        boot_options=['-source','8','-target','8','-bootclasspath',str(sdk_snapshot)] if args.android_core else []
        command=[compiler, *boot_options, '-J-Xmx2g', '-Xmaxerrs', '100', '-Xlint:unchecked', '-encoding', 'UTF-8', '-classpath', str(sdk_snapshot), '-d', temp, *paths]
        result = subprocess.run(command, text=True, capture_output=True)
        compiled = list(Path(temp).glob('AndroidApiConformance*.class'))
        forbidden=[]
        javap=str(Path(compiler).with_name('javap'))
        for offset in range(0,len(compiled),4):
            listing=subprocess.run([javap,'-verbose',*[str(c) for c in compiled[offset:offset+4]]],text=True,capture_output=True,check=True)
            forbidden.extend(dependency_references(listing.stdout))
        dependency_clean = len(compiled) == len(paths) and not forbidden
        compiler_unchanged = compiler_identity == compiler_sources()
        certified = result.returncode == 0 and dependency_clean and compiler_unchanged
        report = {
            **api.stats(), 'probe_count': len(members), 'android_core_boot_stubs':args.android_core,
            'members_native_tested': len(members) if certified else 0,
            'compilation_passed': result.returncode == 0, 'runtime_dependency_scan_passed': dependency_clean,
            'forbidden_class_references':sorted(set(forbidden)),
            'android_jar_sha256': sdk_digest,
            'api_source_sha256': api_digest,
            'compiler_sources': compiler_identity,
            'compiler_unchanged': compiler_unchanged,
            'verifier_sha256': verifier_digest,
            'command':shlex.join(command), 'javac':str(compiler), 'javac_version':compiler_version,
            'probe_source_sha256':{Path(path).name:hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in paths},
            'native_tested_member_ids': [m.id for m in members] if certified else [],
            'probed_member_ids': [m.id for m in members],
            'diagnostics': result.stderr,
            'scope': 'Compile-only source compatibility against supplied SDK; no device execution, permission validation or older-API support implied.',
        }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ('native_tested_member_ids', 'probed_member_ids')}, indent=2))
    return 0 if members and report['compilation_passed'] and dependency_clean and report['compiler_unchanged'] else 1


if __name__ == '__main__': raise SystemExit(main())
