"""Load a real MapKit standard-map snapshot using generated region helpers.

This proves a native SDK map render, not that the product's map UI was inspected.
It executes a signed simulator CLI bundle and never sends UI input.
"""
import argparse,hashlib,json,plistlib,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project',type=Path,required=True);p.add_argument('--simulator',required=True);p.add_argument('--work-dir',type=Path,required=True);a=p.parse_args();a.work_dir.mkdir(parents=True,exist_ok=True)
 bundle=a.work_dir/'MapProbe.app';bundle.mkdir(exist_ok=True);binary=bundle/'MapProbe';sources=[];hashes={}
 for name in ['NativeEffects.swift','NativeMedia.swift','NativeDevice.swift']:
  src=a.project/'App/Generated'/name;dst=a.work_dir/name;dst.write_bytes(src.read_bytes());sources.append(str(dst));hashes[name]=hashlib.sha256(src.read_bytes()).hexdigest()
 fixture=ROOT/'tests/fixtures/ios_map_load.swift';sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
 build=subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*sources,str(fixture),'-o',str(binary)],capture_output=True,text=True);(a.work_dir/'build.log').write_text(build.stdout+build.stderr)
 if build.returncode:raise RuntimeError(build.stderr[-5000:])
 (bundle/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.dotcorr.native.maprender','CFBundleExecutable':'MapProbe','CFBundleName':'MapProbe','CFBundlePackageType':'APPL'}))
 subprocess.run(['codesign','--force','--sign','-',str(bundle)],check=True,capture_output=True)
 result=subprocess.run(['xcrun','simctl','spawn',a.simulator,str(binary),str(a.work_dir/'snapshot.png')],capture_output=True,text=True,timeout=60);(a.work_dir/'execution.log').write_text(result.stdout+result.stderr)
 report={'status':'failed','processExitCode':result.returncode,'productMapUIVerified':False}
 for line in reversed(result.stdout.splitlines()):
  try:report.update(json.loads(line));break
  except json.JSONDecodeError:pass
 if report.get('status')=='rendered':
  report['imageLogicalWidthPoints']=report.pop('width');report['imageLogicalHeightPoints']=report.pop('height')
  report['pixelWidth'],report['pixelHeight']=struct.unpack('>II',(a.work_dir/'snapshot.png').read_bytes()[16:24])
 report.update(generatedSourceSha256=hashes,fixtureSha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),binarySha256=hashlib.sha256(binary.read_bytes()).hexdigest(),simulator=a.simulator)
 (a.work_dir/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));return 0 if report['status']=='rendered' else 1
if __name__=='__main__':sys.exit(main())
