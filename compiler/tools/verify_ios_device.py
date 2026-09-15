"""Run real native device helpers without presenting app UI or permission dialogs."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from dcflight.backends.ios_device import SWIFT,MAP
from dcflight.backends.ios_media import SWIFT as MEDIA,REMOTE
from dcflight.backends.ios_flow import HELPERS

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--simulator',required=True);p.add_argument('--work-dir',required=True,type=Path);a=p.parse_args();a.work_dir.mkdir(parents=True,exist_ok=True)
 source=SWIFT+MAP+MEDIA+REMOTE+HELPERS+'\nenum NativeEffectConfiguration { static let secureNamespace="device-test" }'
 path=a.work_dir/'NativeDevice.swift';path.write_text(source);fixture=ROOT/'tests/fixtures/ios_device_main.swift';binary=a.work_dir/'verify-device'
 sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
 build=subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',str(path),str(fixture),'-o',str(binary)],capture_output=True,text=True);(a.work_dir/'build.log').write_text(build.stdout+build.stderr)
 if build.returncode:raise RuntimeError(build.stderr[-5000:])
 result=subprocess.run(['xcrun','simctl','spawn',a.simulator,str(binary)],capture_output=True,text=True,timeout=45);(a.work_dir/'execution.log').write_text(result.stdout+result.stderr)
 if result.returncode:raise RuntimeError(result.stdout+result.stderr)
 report=json.loads(result.stdout.strip().splitlines()[-1]);report.update(sourceSha256=hashlib.sha256(source.encode()).hexdigest(),fixtureSha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),binarySha256=hashlib.sha256(binary.read_bytes()).hexdigest(),simulator=a.simulator);(a.work_dir/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
