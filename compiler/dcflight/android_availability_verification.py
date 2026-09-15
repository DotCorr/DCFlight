#!/usr/bin/env python3
"""Probe flagged declarations with generated native calls against one exact SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from .android_availability import FLAGGED, _candidate_view
from .android_availability_probe import probe
from .ios_verification import compiler_sources
from .platforms.android_api import AndroidAPI
from .android_class_dependencies import dependency_references


def verify(source, sdk, javac, api_level=35, *, progress=None):
    before = compiler_sources()
    source_bytes = Path(source).read_bytes()
    api = AndroidAPI(source_bytes.decode(), api_level=api_level)
    candidates = [m for m in api.members.values() if m.unsupported_reasons == (FLAGGED,)]
    if not candidates:
        raise ValueError('No eligible flagged declarations')
    view = _candidate_view(api, [m.id for m in candidates])
    rows = [{'id': m.id, 'compiled': False,
             'probeSha256': hashlib.sha256(probe(view, m, 0).encode()).hexdigest()} for m in candidates]
    commands = []
    dependency_clean = True
    with tempfile.TemporaryDirectory(prefix='dcflight-availability-') as directory:
        root = Path(directory)
        sdk_copy = root / 'android.jar';shutil.copyfile(sdk, sdk_copy)
        sdk_digest = hashlib.sha256(sdk_copy.read_bytes()).hexdigest()
        source_file = root / 'AvailabilityProbe.java'
        def compile_group(indices):
            nonlocal dependency_clean
            source_file.write_text('public class AvailabilityProbe {\n' + '\n'.join(
                probe(view, candidates[index], index) for index in indices) + '\n}\n')
            compiled = root / 'AvailabilityProbe.class'
            if compiled.exists():compiled.unlink()
            command = [str(javac), '-source', '8', '-target', '8', '-bootclasspath', str(sdk_copy),
                       '-Xlint:unchecked', '-Werror', '-d', str(root), str(source_file)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=120)
            commands.append(command)
            if result.returncode == 0:
                listing = subprocess.run([str(Path(javac).with_name('javap')), '-verbose', str(compiled)],
                                         capture_output=True, text=True, check=True, timeout=60)
                clean = not dependency_references(listing.stdout)
                dependency_clean = dependency_clean and clean
                for index in indices:rows[index]['compiled'] = clean
            elif len(indices) == 1:
                rows[indices[0]]['diagnostics'] = result.stderr[-4000:]
            else:
                midpoint = len(indices)//2
                compile_group(indices[:midpoint]);compile_group(indices[midpoint:])
        for offset in range(0, len(rows), 64):
            compile_group(list(range(offset, min(offset+64, len(rows)))))
            if progress is not None:
                progress({'processed':min(offset+64,len(rows)),'candidates':len(rows),'compiled':sum(row['compiled'] for row in rows)})
    return {'kind': 'dcflight.android.flagged-availability.v1', 'generator': 'AndroidAPI.emit',
            'sourceSha256': hashlib.sha256(source_bytes).hexdigest(), 'sdkSha256': sdk_digest,
            'apiLevel': api_level, 'compilerSources': before, 'compilerUnchanged': before == compiler_sources(),
            'candidateCount': len(rows), 'compiledCount': sum(row['compiled'] for row in rows),
            'dependencyScanPassed': dependency_clean, 'members': rows,
            'command': commands, 'toolchain': {'javac': str(javac), 'version': subprocess.check_output([str(javac), '-version'], text=True).strip()},
            'runtimeSupported': None, 'minimumApi': None,
            'scope': 'Conditional use only: exact SDK compilation does not prove device availability or runtime flag state.'}


def add_arguments(parser, *, catalog=True):
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--javac', type=Path, required=True)
    parser.add_argument('--api-level', type=int, default=35)
    parser.add_argument('--report', type=Path, required=True)
    if catalog: parser.add_argument('--catalog', type=Path)


def run(args, *, progress=False):
    if args.report.exists(): raise ValueError('Use a fresh report path')
    callback=(lambda state: print(json.dumps(state),file=sys.stderr,flush=True)) if progress else None
    report=verify(args.source,args.sdk,args.javac,args.api_level,progress=callback)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    if args.catalog:
        from .android_availability import import_availability
        return import_availability(args.catalog,args.report,args.sdk,javac=args.javac)
    return {'candidates':report['candidateCount'],'compiled':report['compiledCount']}


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    add_arguments(parser)
    args=parser.parse_args(argv)
    try: result=run(args,progress=True)
    except (ValueError,OSError,subprocess.CalledProcessError) as error: parser.error(str(error))
    print(json.dumps(result))
    return 0
