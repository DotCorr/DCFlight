from ios_sdk_fixture import fake_toolchain, write_sdk
import tempfile,unittest,gzip,json,hashlib,zipfile
from pathlib import Path
import importlib.util
_spec=importlib.util.spec_from_file_location('dcflight_sdk_coordinator_test_tool',Path(__file__).resolve().parents[1]/'tools/verify_ios_sdk.py')
c=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(c)
class CoordinatorTests(unittest.TestCase):
 def fixture(self,root):
  p=root/'Example';p.mkdir();g=p/'symbolgraphs';g.mkdir();raw=b'{"symbols":[]}';compressed=gzip.compress(raw,mtime=0);(g/'Example.symbols.json.gz').write_bytes(compressed)
  producer={'compilerSources':{'a':'hash'},'harnessSHA256':'tool'}
  status={'module':'Example','status':'success','provenance':{'compilerSources':{'a':'hash'},'extractorSHA256':'tool'},'artifacts':{'graphs':[{'path':'Example.symbols.json.gz','compression':'gzip','sha256':hashlib.sha256(compressed).hexdigest(),'rawSHA256':hashlib.sha256(raw).hexdigest()}]}}
  (p/'records.jsonl').write_text('');status['artifacts']['records']={'path':'records.jsonl','sha256':c.sha(p/'records.jsonl')}
  c.write(p/'status.json',status);return producer,status
 def test_original_compressed_and_raw_hashes(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);producer,status=self.fixture(root);self.assertEqual(len(c.extraction(root,producer)),1)
   status['artifacts']['graphs'][0]['rawSHA256']='wrong';c.write(root/'Example/status.json',status)
   with self.assertRaisesRegex(ValueError,'raw graph'):c.extraction(root,producer)
 def test_added_graph_and_symlink_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);producer,status=self.fixture(root);p=root/'Example/symbolgraphs/extra';p.write_text('extra')
   with self.assertRaisesRegex(ValueError,'graph set'):c.extraction(root,producer)
   p.unlink();p=root/'Example/status.json';data=p.read_bytes();p.unlink();external=root/'external';external.write_bytes(data);p.symlink_to(external)
   with self.assertRaises(ValueError):c.extraction(root,producer)
 def test_failed_extraction_is_not_native_pass(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);p=root/'Failure';p.mkdir();c.write(p/'status.json',{'module':'Failure','status':'failed'})
   self.assertEqual(c.extraction(root,{})['Failure']['status'],'failed')
 def test_exact_wheel(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);(root/'site/dcflight').mkdir(parents=True);p=root/'site/dcflight/a.py';p.write_text('x=1');wheel=root/'x.whl'
   with zipfile.ZipFile(wheel,'w') as z:z.writestr('dcflight/a.py','x=1')
   self.assertEqual(c.wheel_identity(wheel,root/'site',c.sha(wheel)),{'a.py':c.sha(p)})
   p.write_text('x=2')
   with self.assertRaises(ValueError):c.wheel_identity(wheel,root/'site',c.sha(wheel))
 def test_no_candidates_partial_and_dependencies(self):
  temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup);sdk=write_sdk(Path(temporary.name)/'sdk')
  expected={'inputs':{'Example':[]},'typeInputs':{},'imports':[]};tools={'sdk':str(sdk),'sdkVersion':'26.2','swift':'s'}
  report={**tools,'compilerSources':{},'target':'arm64-apple-ios18.0-simulator','swiftLanguageVersion':'6','actorContext':'main','inputs':expected['inputs'],'typeInputs':{},'additionalImports':[],'candidateCount':0,'nativeTested':0,'failedCount':0,'skippedCount':0,'passed':[],'failed':[],'skipped':[],'coverage':{'Example':{'unsupported':5}}}
  self.assertEqual(c.classify(report,'Example',expected,{},tools)['status'],'no_candidates')
  report['candidateCount']=1
  with self.assertRaisesRegex(ValueError,'Partial'):c.classify(report,'Example',expected,{},tools)
  report['candidateCount']=0;expected['typeInputs']={'Foreign':[]}
  with self.assertRaisesRegex(ValueError,'graph inputs'):c.classify(report,'Example',expected,{},tools)
 def test_completed_resume_rechecks_report_and_skips_execution(self):
  from unittest.mock import patch
  from types import SimpleNamespace
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);ex=root/'ex';ex.mkdir();producer,status=self.fixture(ex)
   sdk=write_sdk(root/'fake-sdk')
   tools={'sdk':str(sdk),'sdkVersion':'26.2','swift':'s','xcode':'x','sdkSettingsSHA256':c.sha(sdk/'SDKSettings.json'),'target':'arm64-apple-ios18.0-simulator'}
   status['provenance'].update(tools);c.write(ex/'Example/status.json',status);c.write(ex/'inventory.json',[{'module':'Example','excluded':False}])
   producer.update(status='completed',producerUnchanged=True,exitCode=0);c.write(root/'producer.json',producer)
   site=root/'site';(site/'dcflight').mkdir(parents=True);(site/'dcflight/a.py').write_text('x=1');wheel=root/'x.whl'
   from dcflight import ios_sdk_environment as environment_module
   helper=Path(environment_module.__file__).read_text();(site/'dcflight/ios_sdk_environment.py').write_text(helper)
   with zipfile.ZipFile(wheel,'w') as z:
    z.writestr('dcflight/a.py','x=1');z.writestr('dcflight/ios_sdk_environment.py',helper)
   c.write(root/'deps.json',{})
   args=SimpleNamespace(wheel=wheel,site=site,extraction=ex,output=root/'out',jobs=1,timeout=5,min_free_mb=256,wheel_sha256=c.sha(wheel),producer_report=root/'producer.json',producer_sha256=c.sha(root/'producer.json'),module=None,dependencies=root/'deps.json',resume=False)
   def launch(command,**kwargs):
    expected=c.expectation('Example',c.extraction(ex,producer),{})
    report={**tools,'compilerSources':c.compiler(site),'target':'arm64-apple-ios18.0-simulator','swiftLanguageVersion':'6','actorContext':'main','inputs':expected['inputs'],'typeInputs':{},'additionalImports':[],'candidateCount':0,'nativeTested':0,'failedCount':0,'skippedCount':0,'passed':[],'failed':[],'skipped':[],'coverage':{'Example':{'unsupported':5}}}
    c.write(Path(command[command.index('--output')+1]),report)
    return SimpleNamespace(returncode=1,poll=lambda:1)
   with patch.object(c,'toolchain',return_value=tools),patch.object(c.subprocess,'Popen',side_effect=launch) as popen:
    self.assertEqual(c.run(args),0);self.assertEqual(popen.call_count,1)
    args.resume=True;self.assertEqual(c.run(args),0);self.assertEqual(popen.call_count,1)
    (args.output/'Example.json').write_text('{}')
    with self.assertRaisesRegex(ValueError,'corrupted'):c.run(args)
   (args.output/'Example.receipt.json').unlink()
   class Hung:
    pid=123456789;returncode=None
    def poll(self):return self.returncode
    def wait(self,timeout):self.returncode=-9;return -9
   with patch.object(c,'toolchain',return_value=tools),patch.object(c.subprocess,'Popen',return_value=Hung()),patch.object(c.os,'killpg') as kill,patch.object(c.time,'monotonic',side_effect=[0,10,11]):
    self.assertEqual(c.run(args),1);kill.assert_called_once_with(123456789,c.signal.SIGKILL)
    self.assertFalse((args.output/'.cache-Example').exists())
    self.assertEqual(c.read(args.output/'Example.receipt.json')['status'],'timeout')
 def test_output_and_cache_links_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);real=root/'real';real.mkdir();linked=root/'linked';linked.symlink_to(real,target_is_directory=True)
   with self.assertRaises(ValueError):c.safe_output(linked)
   (real/'.cache-Example').symlink_to(root,target_is_directory=True)
   with self.assertRaises(ValueError):c.safe_output(real)

class CoordinatorTargetTests(unittest.TestCase):
 def test_version_components_are_exact(self):
  self.assertEqual(c.parse_version('26.2'),(26,2))
  for value in ('26.2.1','26.02','26.2-simulator','26','0.1',True,None):
   with self.subTest(value=value),self.assertRaises(ValueError):c.parse_version(value)
 def test_report_target_must_match_selected_version(self):
  with tempfile.TemporaryDirectory() as tmp:
   sdk=write_sdk(Path(tmp)/'sdk');tools={'sdk':str(sdk),'sdkVersion':'26.2','swift':'s'}
   expected={'inputs':{'Example':[]},'typeInputs':{},'imports':[]}
   report={**tools,'compilerSources':{},'target':'arm64-apple-ios26.2-simulator','swiftLanguageVersion':'6','actorContext':'main','inputs':expected['inputs'],'typeInputs':{},'additionalImports':[],'candidateCount':0,'nativeTested':0,'failedCount':0,'skippedCount':0,'passed':[],'failed':[],'skipped':[],'coverage':{'Example':{}}}
   self.assertEqual(c.classify(report,'Example',expected,{},tools,(26,2))['status'],'no_candidates')
   with self.assertRaisesRegex(ValueError,'target/context'):c.classify(report,'Example',expected,{},tools,(18,0))

if __name__=='__main__':unittest.main()
