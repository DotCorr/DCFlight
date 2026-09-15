#!/usr/bin/env python3
"""Plan exact SDK nominal dependencies in one bounded batch; no native credit."""
import argparse,json
from dcflight.ios_type_dependency_batch import plan_batch

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',required=True);p.add_argument('--output',required=True);p.add_argument('--module',action='append');p.add_argument('--timeout',type=int,default=1800);p.add_argument('--disk-floor',type=int,default=1024**3);a=p.parse_args()
 result=plan_batch(a.capture,a.output,modules=a.module,timeout=a.timeout,disk_floor=a.disk_floor,progress=lambda row:print(json.dumps(row),flush=True))
 print(json.dumps({'modules':len(result['modules']),'planned':sum(x['status']=='planned' for x in result['modules']),'nativeTested':0}))
if __name__=='__main__':main()
