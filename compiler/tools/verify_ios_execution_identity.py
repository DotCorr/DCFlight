#!/usr/bin/env python3
"""Create new bounded native execution identity evidence; never reuse old proof."""
from pathlib import Path
import argparse,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.ios_execution_identity import run

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--sdk-environment',choices=('iphoneos','iphonesimulator'),default='iphonesimulator');p.add_argument('--ios-version',default='18.0');p.add_argument('--swift-version',choices=('5','6'),default='6');a=p.parse_args()
 if a.source.stat().st_size>1024*1024:p.error('Source exceeds1MiB')
 from dcflight.ios_verification import deployment_version
 r=run(a.source.read_text(),a.output,sdk_environment=a.sdk_environment,ios_version=deployment_version(a.ios_version),swift_version=a.swift_version);print(json.dumps(r['metrics']))
 return json.loads((a.output/'native-report.json').read_text())['exitCode']
if __name__=='__main__':sys.exit(main())
