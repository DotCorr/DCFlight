"""Execute generated UIKit/ImageIO media helpers as a simulator CLI; no UI taps."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from dcflight.backends.ios_media import SWIFT,REMOTE
from dcflight.backends.ios_flow import HELPERS

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--simulator',required=True);p.add_argument('--work-dir',type=Path,required=True);a=p.parse_args();a.work_dir.mkdir(parents=True,exist_ok=True)
 source=SWIFT+REMOTE+HELPERS+'\nenum NativeEffectConfiguration { static let secureNamespace = "media-test" }\n'
 native=a.work_dir/'NativeMedia.swift';native.write_text(source)
 fixture=ROOT/'tests/fixtures/ios_media_main.swift';binary=a.work_dir/'verify-media'
 sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
 build=subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',str(native),str(fixture),'-o',str(binary)],capture_output=True,text=True);(a.work_dir/'build.log').write_text(build.stdout+build.stderr)
 if build.returncode:raise RuntimeError(build.stderr[-5000:])
 run=subprocess.run(['xcrun','simctl','spawn',a.simulator,str(binary)],capture_output=True,text=True,timeout=90);(a.work_dir/'execution.log').write_text(run.stdout+run.stderr)
 if run.returncode:raise RuntimeError(run.stdout+run.stderr)
 result=json.loads(run.stdout.strip().splitlines()[-1]);result.update(nativeSourceSha256=hashlib.sha256(source.encode()).hexdigest(),fixtureSha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),simulator=a.simulator,binarySha256=hashlib.sha256(binary.read_bytes()).hexdigest());(a.work_dir/'report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));return 0
if __name__=='__main__':sys.exit(main())
