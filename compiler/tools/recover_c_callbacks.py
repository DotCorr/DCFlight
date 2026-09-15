#!/usr/bin/env python3
"""Retain explicit SDK-derived C callback conventions for later native verification."""
import argparse,json,subprocess
from pathlib import Path
from dcflight.c_callback_recovery import recover

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--graphs',type=Path,required=True)
    parser.add_argument('--module',required=True)
    parser.add_argument('--id',action='append',required=True,dest='identities')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--sdk',type=Path)
    parser.add_argument('--swiftc',type=Path)
    parser.add_argument('--target',default='arm64-apple-ios18.0-simulator')
    args=parser.parse_args()
    sdk=args.sdk or Path(subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip())
    swiftc=args.swiftc or Path(subprocess.check_output(['xcrun','--find','swiftc'],text=True).strip())
    report=recover(args.graphs,args.module,args.identities,args.output,swiftc=swiftc,sdk=sdk,target=args.target)
    print(json.dumps({'report':str(args.output/'recovery.json'),'changes':len(report['changes']),'nativeVerified':False}))
if __name__=='__main__':main()
