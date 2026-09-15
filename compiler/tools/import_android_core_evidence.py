#!/usr/bin/env python3
"""Associate exact Android-core compilation evidence without reindexing the SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.catalog import Catalog
from dcflight.frontends import read_json


def record(database,report_path):
    report_path=Path(report_path).resolve();report=read_json(report_path.read_text())
    if not isinstance(report,dict):raise ValueError('Expected conformance report object')
    if not all(report.get(k) is True for k in ('compilation_passed','runtime_dependency_scan_passed','android_core_boot_stubs')):
        raise ValueError('Core evidence must compile successfully against Android boot stubs')
    identities=report.get('native_tested_member_ids')
    if not isinstance(identities,list) or not identities or any(not isinstance(v,str) for v in identities) or len(set(identities))!=len(identities) or len(identities)!=report.get('members_native_tested'):
        raise ValueError('Evidence requires exact unique tested IDs and matching count')
    if (type(report.get('members_native_tested')) is not int or type(report.get('probe_count')) is not int
            or report['probe_count']!=len(identities) or report.get('probed_member_ids')!=identities
            or report.get('forbidden_class_references')!=[]):
        raise ValueError('Tested identities must exactly match clean compilation probes')
    for field in ('command','javac','javac_version'):
        if not isinstance(report.get(field),str) or not report[field].strip():
            raise ValueError('Evidence must record actual compiler command and version')
    with Catalog(database,write=True) as catalog:
        source=catalog.source('android','core-bytecode');provenance=source['provenance']
        if (report.get('source_sha256')!=provenance.get('sourceSha256') or report.get('android_jar_sha256')!=provenance.get('sdkArchiveSha256') or str(report.get('api_level'))!=source['sdk']):
            raise ValueError('Evidence differs from indexed core SDK inputs')
        catalog.record_evidence('android','core-bytecode',identities,'compiled',{
            'command':report['command'],
            'toolchain':{'compiler':report['javac'],'version':report['javac_version'],'androidApi':source['sdk'],'androidJarSha256':provenance['sdkArchiveSha256']},
            'reportSha256':hashlib.sha256(report_path.read_bytes()).hexdigest(),'reportPath':str(report_path),
            'scope':'Exact listed calls compiled against Android core stubs; not executed on a device.'})
    return {'scope':'core-bytecode','compiled':len(identities),'executed':0}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--catalog',required=True);parser.add_argument('--report',required=True)
    args=parser.parse_args();print(json.dumps(record(args.catalog,args.report)))
