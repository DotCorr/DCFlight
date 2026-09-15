#!/usr/bin/env python3
"""Exercise installed, signed-in Snap with a caller-selected simulator QA photo.

Requires Xcode, xcodegen, and a known QA image already in simulator Photos.
Selects that image into a local draft, cancels it, then cancels the picker.
Does not publish media, sign out, regenerate Snap, or change its saved account.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.backends.ios_routed import quote


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--photo-label', required=True, help='Exact accessibility label of the known QA image in Photos')
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    work = args.work.resolve(); report = args.report.resolve()
    if work.exists() or report.exists():
        parser.error('Use fresh work and report paths')
    if not args.photo_label.strip() or len(args.photo_label) > 300:
        parser.error('Provide a nonempty QA photo label of at most 300 characters')
    xcodegen = shutil.which('xcodegen')
    if not xcodegen:
        parser.error('xcodegen is required to create the isolated native test host')
    # XCUITest can resolve a stale extension instance by bundle ID. Report
    # duplicate instances on this simulator instead of choosing or killing one.
    picker_pids = []
    processes = subprocess.check_output(['ps', 'ax', '-o', 'pid=,command='], text=True)
    for line in processes.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2 or not parts[1].startswith('/Library/Developer/CoreSimulator/Volumes/') or '/PhotosPicker.appex/PhotosPicker ' not in parts[1]:
            continue
        try:
            environment = subprocess.check_output(['ps', 'eww', '-p', parts[0], '-o', 'command='], text=True)
        except subprocess.CalledProcessError:
            continue
        identity = re.search(r'(?:^| )SIMULATOR_UDID=([^ ]+)', environment)
        if identity and identity.group(1) == args.simulator:
            picker_pids.append(int(parts[0]))
    if len(picker_pids) > 1:
        parser.error('Multiple PhotosPicker instances on this simulator: '+str(picker_pids)+'. Close stale QA picker instances before testing; no process was changed.')
    installed = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.simulator, 'com.dotcorr.snapshared', 'app'], text=True).strip())
    identities = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in installed.iterdir()
                  if p.is_file() and (p.name == 'App' or p.suffix == '.dylib')}
    if 'App' not in identities:
        parser.error('Installed Snap executable was not found')
    fixture = Path(__file__).parent/'fixtures/snap_ios_ui'
    work.mkdir(parents=True); report.parent.mkdir(parents=True, exist_ok=True)
    (work/'Host').mkdir(); (work/'UITests').mkdir()
    shutil.copyfile(fixture/'Host.swift', work/'Host/Host.swift')
    shutil.copyfile(fixture/'project.json', work/'project.json')
    source = (fixture/'SnapUITests.swift.in').read_text().replace('__PHOTO_LABEL__', quote(args.photo_label))
    (work/'UITests/SnapUITests.swift').write_text(source)
    def run(command, log):
        with (work/log).open('w') as stream:
            result = subprocess.run(command, cwd=work, stdout=stream, stderr=subprocess.STDOUT, timeout=300)
        if result.returncode:
            raise RuntimeError('Native UI check failed; inspect '+str(work/log))
    run([xcodegen, 'generate', '--spec', 'project.json', '--no-env'], 'project.log')
    run(['xcodebuild', '-project', 'SnapUIProbe.xcodeproj', '-scheme', 'SnapUIProbe', '-destination',
         'platform=iOS Simulator,id='+args.simulator, '-derivedDataPath', 'build', '-resultBundlePath',
         'result.xcresult', '-parallel-testing-enabled', 'NO', 'test'], 'test.log')
    log = (work/'test.log').read_text()
    if '** TEST SUCCEEDED **' not in log or 'SNAP_UI_picker-cancelled_END' not in log:
        raise RuntimeError('The complete photo selection and cancellation journey did not finish')
    for name, digest in identities.items():
        if hashlib.sha256((installed/name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Installed Snap changed during verification')
    run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', 'result.xcresult',
         '--output-path', 'attachments'], 'attachments.log')
    result = {'passed': True, 'simulator': args.simulator, 'installedMachOSHA256': identities,
              'fixtureSHA256': hashlib.sha256(source.encode()).hexdigest(), 'work': str(work),
              'scope': 'Native iOS picker selection, centered preview, composer cancellation and picker cancellation in installed Snap. No publishing, physical camera or full production acceptance.'}
    report.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
