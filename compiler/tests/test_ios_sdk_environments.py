import copy,json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from dcflight import ios_sdk_environment as e,ios_verification as v
from dcflight import ios_invocation_evidence as inv
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI

def settings(root,name):
 p=root/name;p.mkdir();(p/'SDKSettings.json').write_text(json.dumps({'CanonicalName':name+'26.2','Version':'26.2','SupportedTargets':{name:{'LLVMTargetTripleVendor':'apple','LLVMTargetTripleSys':'ios','LLVMTargetTripleEnvironment':'simulator' if name=='iphonesimulator' else '', 'Archs':['arm64']}}}));return p
class EnvironmentTests(unittest.TestCase):
 def fixture(self,root):
  sdks={n:settings(root,n) for n in e.ENVIRONMENTS};g=root/'graphs';g.mkdir();(g/'Fixture.symbols.json').write_text(json.dumps({'symbols':[{'identifier':{'precise':'value'},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner','value'],'declarationFragments':[{'spelling':'static var value: Int { get }'}]}]}))
  def output(command,**kwargs):
   if '--show-sdk-path' in command:return str(sdks[command[command.index('--sdk')+1]])
   if '--show-sdk-version' in command:return '26.2'
   return 'fixture swift'
  return sdks,g,output
 def test_sdk_settings_and_target_cannot_disagree(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);sdk=settings(r,'iphoneos');self.assertEqual('arm64-apple-ios18.0',e.target('iphoneos',(18,0)))
   self.assertEqual('arm64-apple-ios18.0-simulator',e.target('iphonesimulator',(18,0)))
   with self.assertRaises(ValueError):e.sdk_settings(sdk,'iphonesimulator')
   for env,target in [('iphoneos','arm64-apple-ios18.0-simulator'),('iphonesimulator','arm64-apple-ios18.0'),('iphoneos','x86_64-apple-ios18.0')]:
    with self.assertRaises(ValueError):e.validate_target(env,target)
 def test_produce_export_and_tampering_both_environments(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);sdks,g,output=self.fixture(r)
   with patch.object(v.subprocess,'check_output',side_effect=output),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):
    for env in e.ENVIRONMENTS:
     p=r/(env+'.json');self.assertEqual(0,v.main(['--module','Fixture='+str(g),'--sdk-environment',env,'--swift-version','6','--output',str(p)],progress=False));d=json.loads(p.read_text());self.assertEqual(env,d['sdkEnvironment']);self.assertEqual(e.target(env,(18,0)),d['target']);v.export_records({'Fixture':g},p,r/(env+'-records'))
     import importlib.util
     spec=importlib.util.spec_from_file_location('coordinator_environment',Path(__file__).parents[1]/'tools/verify_ios_sdk.py');coordinator=importlib.util.module_from_spec(spec);spec.loader.exec_module(coordinator)
     tools={k:d[k] for k in ['sdkEnvironment','sdk','sdkVersion','sdkSettingsSHA256','swift']}
     expected={'inputs':d['inputs'],'typeInputs':d['typeInputs'],'imports':d['additionalImports']}
     self.assertEqual('native_passes',coordinator.classify(d,'Fixture',expected,d['compilerSources'],tools)['status'])
     for n,change in enumerate([lambda x:x.update(sdkEnvironment='iphoneos' if env=='iphonesimulator' else 'iphonesimulator'),lambda x:x.update(sdkSettingsSHA256='0'*64),lambda x:x.update(sdk=str(sdks['iphoneos' if env=='iphonesimulator' else 'iphonesimulator']))]):
      bad=copy.deepcopy(d);change(bad);p.write_text(json.dumps(bad))
      with self.assertRaises(ValueError):v.export_records({'Fixture':g},p,r/(env+'-bad'+str(n)))
     if env=='iphoneos':
      d.pop('sdkEnvironment');p.write_text(json.dumps(d))
      with self.assertRaises(ValueError):v.export_records({'Fixture':g},p,r/'legacy-device')
 def test_index_scopes_and_public_request_environment(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);sdks,g,output=self.fixture(r);db=r/'db'
   with patch.object(v.subprocess,'check_output',side_effect=output),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):
    for env in e.ENVIRONMENTS:v.verify_and_index(db,g,'Fixture',r/(env+'.json'),sdk_environment=env)
   api=NativeAPI(db)
   self.assertEqual('Int',api.emit({'platform':'ios','scope':'Fixture','id':'value'})['resultType'])
   self.assertEqual('Int',api.emit({'platform':'ios','scope':'Fixture@iphoneos','sdkEnvironment':'iphoneos','id':'value'})['resultType'])
   for request in [{'platform':'ios','scope':'Fixture@iphoneos','id':'value'},{'platform':'ios','scope':'Fixture','id':'value','sdkEnvironment':'iphoneos'}]:
    with self.assertRaisesRegex(ValueError,'environment differs'):api.emit(request)
 def test_structured_authoring_rejects_environment_explicitly(self):
  from dcflight.native_sequence import emit_sequence
  with self.assertRaisesRegex(ValueError,'Unknown native sequence fields'):emit_sequence(None,{'platform':'ios','sdkEnvironment':'iphoneos','steps':[]})
  from dcflight.native_operation import validate_sequence_structure
  with self.assertRaises(ValueError):validate_sequence_structure('ios',[{'id':'value','sdkEnvironment':'iphoneos'}],[])
 def test_invocation_certificate_cannot_cross_environment(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);sdks,g,output=self.fixture(r)
   with patch.object(v.subprocess,'check_output',side_effect=output),patch.object(inv,'_compile',return_value=(True,'')):
    report=inv.verify_invocations(g,'Fixture',['value'],r/'inv.json',contexts=['main'],sdk_environment='iphoneos');record=inv.conditional_records(report)[0]
    with self.assertRaisesRegex(ValueError,'SDK environment'):inv.select_invocation(record,{'actorContext':'main'})
    inv.select_invocation(record,{'actorContext':'main','sdkEnvironment':'iphoneos'})
    bad=copy.deepcopy(report);bad['sdkEnvironment']='iphonesimulator'
    with self.assertRaises(ValueError):inv._validate(bad)
if __name__=='__main__':unittest.main()
