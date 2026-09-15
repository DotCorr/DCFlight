#!/usr/bin/env python3
"""Execute catalogued failable Foundation construction on an explicit iOS simulator."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import uuid

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence


def run(catalog, simulator, report):
    if report.exists() or report.is_symlink():
        raise ValueError('Use a fresh report path; preserve prior evidence')
    request={'platform':'ios','allowThrows':True,
        'inputs':[{'name':'text','type':'String'}],
        'steps':[
            {'scope':'Foundation','id':'s:10Foundation4UUIDV10uuidStringACSgSSh_tcfc','arguments':[{'ref':'text'}],'bind':'candidate'},
            {'unwrap':{'ref':'candidate'},'bind':'value','message':'Invalid UUID'},
            {'scope':'Foundation','id':'s:10Foundation4UUIDV10uuidStringSSvp','receiver':{'ref':'value'},'bind':'result'}]}
    emitted=emit_sequence(NativeAPI(catalog),request)
    bindings={item['name']:item for item in emitted['bindings']}
    if bindings['candidate']['type']!='UUID?' or bindings['value']['type']!='UUID' or bindings['result']['type']!='String':
        raise ValueError('Unexpected SDK optional-result contract')
    token=uuid.uuid4().hex
    valid=['00000000-0000-0000-0000-000000000000','123e4567-e89b-12d3-a456-426614174000']
    invalid=['','not-a-uuid','123e4567-e89b-12d3-a456-426614174000x']
    source='import Foundation\nfunc parse(_ text:String) throws -> String {\n'+emitted['source']+'\nreturn '+bindings['result']['nativeName']+'\n}\n'
    source+='''@main struct Main { static func main() throws {
      var committed="unchanged", successes=0, failures=0
      for input in VALID {
        committed=try parse(input);precondition(committed==input.uppercased());successes += 1
      }
      for input in INVALID {
        let before=committed
        do { committed=try parse(input);fatalError("Accepted invalid UUID") }
        catch let error as NSError {
          precondition(error.domain=="NativeValue" && error.code==1 && error.localizedDescription=="Invalid UUID")
          precondition(committed==before);failures += 1
        }
      }
      precondition(successes==2 && failures==3)
      print("MARKER")
    }}
'''.replace('INVALID',json.dumps(invalid)).replace('VALID',json.dumps(valid)).replace('MARKER','FAILABLE_PASSED:'+token)
    def execute(command):
        result=subprocess.run(command,text=True,capture_output=True,timeout=60)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        return result.stdout.strip()
    sdk=execute(['xcrun','--sdk','iphonesimulator','--show-sdk-path'])
    with tempfile.TemporaryDirectory(prefix='dcflight-failable-') as directory:
        root=Path(directory);swift=root/'Check.swift';swift.write_text(source)
        bundle=root/'Check.app';bundle.mkdir();binary=bundle/'Check'
        execute(['xcrun','swiftc','-swift-version','6','-parse-as-library','-sdk',sdk,'-target','arm64-apple-ios18.0-simulator',str(swift),'-o',str(binary)])
        (bundle/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.dotcorr.test.failable','CFBundleExecutable':'Check','CFBundleName':'Check','CFBundlePackageType':'APPL'}))
        execute(['codesign','--force','--sign','-',str(bundle)])
        output=execute(['xcrun','simctl','spawn',simulator,str(binary)])
        if output.splitlines().count('FAILABLE_PASSED:'+token)!=1:raise ValueError('Missing current run completion marker')
        result={'passed':True,'validCases':valid,'invalidCases':invalid,'simulator':simulator,
            'sdk':sdk,'swiftVersion':execute(['xcrun','swiftc','--version']),
            'request':request,'emission':emitted,'source':source,'deviceOutput':output,
            'sourceSHA256':hashlib.sha256(source.encode()).hexdigest(),
            'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),
            'scope':'Native iOS simulator execution of failable UUID construction and authored unwrap guard. No product UI, app lifecycle or full API certification.'}
    report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(result,indent=2)+'\n')
    return {'passed':True,'executedCases':len(valid)+len(invalid),'report':str(report)}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog',type=Path,required=True)
    parser.add_argument('--simulator',required=True)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args();print(json.dumps(run(args.catalog,args.simulator,args.report)))
