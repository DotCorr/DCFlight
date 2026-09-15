#!/usr/bin/env python3
"""Build precise-ID nominal dependency subsets from a retained SDK capture."""
from pathlib import Path
import argparse,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.ios_type_dependencies import plan

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--module',required=True);p.add_argument('--id',action='append');p.add_argument('--output',type=Path,required=True);a=p.parse_args();report=plan(a.capture,a.module,a.output,identities=a.id)
 print(json.dumps({'module':a.module,'typeModules':report['typeModules'],'selectedNominals':len(report['selectedNominals']),'unresolvedTypeIDs':len(report['unresolvedTypeIDs']),'nativeTested':0,'report':str(a.output/'type-dependencies.json')}))
if __name__=='__main__':main()
