#!/usr/bin/env python3
"""Retain original SDK graphs and derive exact outer @Sendable callback metadata."""
import argparse,json,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.swift_qualifier_recovery import recover,verify_bundle

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('graphs',type=Path);p.add_argument('--module',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--demangler',type=Path);p.add_argument('--interface',type=Path)
 a=p.parse_args();executable=a.demangler or Path(subprocess.check_output(['xcrun','--find','swift-demangle'],text=True).strip())
 r=recover(a.graphs,a.module,a.output,demangler=executable,interface=a.interface)
 verify_bundle(a.output)
 print(json.dumps({'changedSymbols':len({c['id'] for c in r['changes']}),'changedParameters':sum(len(c['parameterIndices']) for c in r['changes']),'skippedAmbiguous':len(r['skipped']),'manifest':str(a.output/'qualifier-recovery.json'),'nativeConformance':False},indent=2))
if __name__=='__main__':main()
