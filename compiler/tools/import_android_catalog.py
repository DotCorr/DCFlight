#!/usr/bin/env python3
"""Import Android descriptors and exact native compilation evidence into a catalog."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.catalog import Catalog
from dcflight.native_api import index_android
from dcflight.platforms.android_api import AndroidAPI


def import_android_catalog(database, source, report_path):
    source, report_path = Path(source).resolve(), Path(report_path).resolve()
    report = json.loads(report_path.read_text())
    if not report.get('compilation_passed') or not report.get('runtime_dependency_scan_passed'):
        raise ValueError('Conformance report must show successful compilation and dependency checks')
    source_hash = hashlib.sha256(source.read_text().encode()).hexdigest()
    if source_hash != report.get('source_sha256'):
        raise ValueError('Conformance report does not match this SDK source')
    ids = report.get('native_tested_member_ids', [])
    if not isinstance(ids, list) or any(not isinstance(x, str) for x in ids) or not ids or len(ids) != len(set(ids)) or len(ids) != report.get('members_native_tested'):
        raise ValueError('Conformance report requires unique exact tested IDs and matching count')
    api = AndroidAPI.from_file(source, api_level=report['api_level'])
    if any(not api.get(identity).emittable for identity in ids):
        raise ValueError('Conformance report includes unsupported APIs')
    result = index_android(database, source, report['api_level'])
    evidence = {
        'command': report.get('command', 'python3 tools/verify_android_api.py --limit 50000'),
        'toolchain': {'compiler': report.get('javac', 'javac'), 'androidApi': report['api_level'], 'androidJarSha256': report['android_jar_sha256']},
        'reportPath': str(report_path), 'reportSha256': hashlib.sha256(report_path.read_bytes()).hexdigest(),
        'sdkSourceSha256': source_hash, 'scope': report['scope'],
    }
    with Catalog(database, write=True) as catalog:
        catalog.record_evidence('android', 'framework', ids, 'compiled', evidence)
    return {**result, 'compiled': len(ids), 'executed': 0, 'catalog': str(Path(database).resolve())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--report', required=True)
    args = parser.parse_args()
    print(json.dumps(import_android_catalog(args.catalog, args.source, args.report), indent=2))


if __name__ == '__main__': main()
