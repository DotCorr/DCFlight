"""Repeatable bulk extraction/import with SDK provenance and per-source receipts."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.ingest import ingest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apple-module', action='append', default=[])
    parser.add_argument('--apple-sdk', default='iphonesimulator')
    parser.add_argument('--apple-target', default='arm64-apple-ios17.0-simulator')
    parser.add_argument('--android-api')
    parser.add_argument('--android-version')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    if not args.apple_module and not args.android_api:
        parser.error('Choose Apple modules and/or an Android API text file')
    if args.android_api and not args.android_version:
        parser.error('--android-api requires --android-version')
    output = Path(args.out).resolve()
    output.mkdir(parents=True, exist_ok=True)
    jobs = []
    for module in args.apple_module:
        import re
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', module):
            parser.error('Invalid Apple module name')
        sdk = subprocess.check_output(['xcrun', '--sdk', args.apple_sdk, '--show-sdk-path'], text=True).strip()
        version = subprocess.check_output(['xcrun', '--sdk', args.apple_sdk, '--show-sdk-version'], text=True).strip()
        extraction = output / 'raw' / module
        extraction.mkdir(parents=True, exist_ok=True)
        subprocess.run(['xcrun', 'swift-symbolgraph-extract', '-module-name', module, '-sdk', sdk,
                        '-target', args.apple_target, '-minimum-access-level', 'public', '-output-dir', str(extraction)], check=True)
        # Include extension graphs as separate inventories; precise native identities are preserved.
        for graph in sorted(extraction.glob('*.symbols.json')):
            jobs.append((graph, 'apple-symbolgraph', args.apple_sdk + version))
    if args.android_api:
        jobs.append((Path(args.android_api), 'android-api', args.android_version))
    receipts = []
    for source, kind, version in jobs:
        inventory = ingest(source, kind, version)
        destination = output / (source.stem + '.inventory.json')
        destination.write_text(json.dumps(inventory, indent=2, sort_keys=True) + '\n')
        receipts.append(dict(source=source.name, format=kind, sdk=version, sha256=inventory['sourceSha256'],
                             symbols=len(inventory['symbols']), inventory=destination.name))
        print(json.dumps(receipts[-1]), flush=True)
    (output / 'receipts.json').write_text(json.dumps(receipts, indent=2) + '\n')


if __name__ == '__main__':
    main()
