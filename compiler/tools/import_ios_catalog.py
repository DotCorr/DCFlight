#!/usr/bin/env python3
"""Load SDK sweep descriptors, then target-certified corrections and exact native evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.catalog import Catalog
from dcflight.native_api import index_ios_sweep


def sha(path):
    result=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''): result.update(block)
    return result.hexdigest()


def import_certified(database, certified, report_path, sdk_version):
    report_path=Path(report_path);report=json.loads(report_path.read_text());certified=Path(certified)
    toolchain={'sdk':report['sdk'],'target':report['target'],'swift':subprocess.check_output(['xcrun','swiftc','--version'],text=True).strip()}
    tested={}
    for item in report['passed']: tested.setdefault(item['module'],[]).append(item['id'])
    results=[]
    with Catalog(database,write=True) as catalog:
        for module,identities in sorted(tested.items()):
            path=certified/(module+'.jsonl')
            provenance={'recordsPath':str(path.resolve()),'recordsSha256':sha(path),'reportPath':str(report_path.resolve()),
                        'reportSha256':sha(report_path),'nativeCertificationTarget':report['target'],'toolchain':toolchain,
                        'adapterSha256':sha(Path(__file__).resolve().parents[1]/'dcflight/platforms/ios_api.py'),
                        'verifierSha256':sha(Path(__file__).resolve().parent/'verify_ios_api_batch.py')}
            with path.open() as stream:
                result=catalog.import_records('ios',module,sdk_version,(json.loads(line) for line in stream if line.strip()),provenance)
            # The exact report supplies both symbol identity and generated native source.
            # No namespace-wide certification is inferred from representative fixtures.
            catalog.record_evidence('ios',module,identities,'compiled',{
                'command':['xcrun','swiftc','-typecheck','-target',report['target'],'-sdk',report['sdk'],'<generated Verify.swift>'],
                'toolchain':toolchain,'reportPath':str(report_path.resolve()),'reportSha256':sha(report_path),
                'verification':'Typed native source compilation; no runtime execution claim'})
            result['compiled']=len(set(identities));results.append(result)
    return results


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--database',type=Path,required=True)
    p.add_argument('--sweep',type=Path,required=True)
    p.add_argument('--certified',type=Path,required=True)
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--skip-sweep',action='store_true')
    args=p.parse_args()
    result={}
    if not args.skip_sweep: result['sweep']=index_ios_sweep(args.database,args.sweep)
    provenance=json.loads((args.sweep/'provenance.json').read_text())
    result['certified']=import_certified(args.database,args.certified,args.report,provenance['sdkVersion'])
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
