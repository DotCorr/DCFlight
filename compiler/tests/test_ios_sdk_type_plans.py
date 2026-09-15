import importlib.util,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from test_ios_type_dependencies import capture,member,nominal
from dcflight.ios_type_dependency_batch import plan_batch

def load(name,file):
 spec=importlib.util.spec_from_file_location(name,Path(__file__).parents[1]/'tools'/file);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
helper=load('type_plan_validation_test','ios_type_plan_validation.py');coordinator=load('sdk_plans_coordinator_test','verify_ios_sdk.py')
class PlanTests(unittest.TestCase):
 def fixture(self,r):
  c=r/'capture';capture(c,'Primary',[member()]);capture(c,'Other',[nominal('type:wanted','Name')]);b=r/'batch';plan_batch(c,b,disk_floor=0);records={}
  for p in c.glob('*/status.json'):
   d=json.loads(p.read_text());records[p.parent.name]={'status':'success','statusSHA256':coordinator.sha(p),'provenance':d['provenance'],'graphs':[{'name':x['path'],'sha256':x['sha256']} for x in d['artifacts']['graphs']]}
  return c,b,records
 def test_original_primary_and_per_call_subset(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));plans=helper.validate_batch(b,c,records);e=coordinator.expectation('Primary',records,{},plans)
   self.assertEqual([],e['imports']);self.assertEqual(records['Primary']['graphs'],e['inputs']['Primary']);self.assertEqual({'Other'},set(e['typeInputs']))
 def test_rehashed_forged_nominal_is_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));mf=b/'plans/Primary/type-dependencies.json';m=json.loads(mf.read_text());p=b/'plans/Primary'/m['derived'][0]['path'];d=json.loads(p.read_text());d['symbols'][0]['pathComponents']=['Forged'];p.write_text(json.dumps(d));m['derived'][0]['sha256']=coordinator.sha(p);mf.write_text(json.dumps(m));batch=json.loads((b/'batch.json').read_text());next(x for x in batch['modules'] if x['module']=='Primary')['manifestSHA256']=coordinator.sha(mf);(b/'batch.json').write_text(json.dumps(batch))
   with self.assertRaisesRegex(ValueError,'nominal differs'):helper.validate_batch(b,c,records)
 def test_context_and_missing_scope_reject(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));mf=b/'plans/Primary/type-dependencies.json';m=json.loads(mf.read_text());m['context']['target']='wrong';mf.write_text(json.dumps(m));d=json.loads((b/'batch.json').read_text());next(x for x in d['modules'] if x['module']=='Primary')['manifestSHA256']=coordinator.sha(mf);(b/'batch.json').write_text(json.dumps(d))
   with self.assertRaisesRegex(ValueError,'context'):helper.validate_batch(b,c,records)
   d['modules'].pop();(b/'batch.json').write_text(json.dumps(d))
   with self.assertRaisesRegex(ValueError,'scope'):helper.validate_batch(b,c,records)
 def test_plan_rejection_is_explicit(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));d=json.loads((b/'batch.json').read_text());d['modules']=[{'module':x['module'],'status':'rejected','reason':'Unsupported bounded plan','nativeTested':0} for x in d['modules']];(b/'batch.json').write_text(json.dumps(d));result=helper.validate_batch(b,c,records);self.assertEqual('rejected',result['modules']['Primary']['status'])
 def test_linked_manifest_rejects(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));p=b/'batch.json';q=Path(t)/'outside';p.rename(q);p.symlink_to(q)
   with self.assertRaises(ValueError):helper.validate_batch(b,c,records)
 def test_coordinator_command_resume_and_changed_plan(self):
  from types import SimpleNamespace
  from dcflight import ios_sdk_environment
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c,b,records=self.fixture(r);(c/'inventory.json').write_text('[]');producer={'status':'completed','producerUnchanged':True,'exitCode':0};(r/'producer.json').write_text(json.dumps(producer));(r/'wheel').write_text('wheel');site=r/'site';site.mkdir()
   tools={'sdkEnvironment':'iphonesimulator',**{k:records['Primary']['provenance'].get(k) for k in ('sdk','sdkVersion','swift','xcode','sdkSettingsSHA256')}}
   args=SimpleNamespace(wheel=r/'wheel',site=site,extraction=c,output=r/'out',jobs=1,timeout=10,min_free_mb=256,wheel_sha256='wheel',producer_report=r/'producer.json',producer_sha256=coordinator.sha(r/'producer.json'),module=['Primary'],dependencies=None,type_plans=b,resume=False,ios_version='18.0')
   identity={'ios_sdk_environment.py':coordinator.sha(ios_sdk_environment.__file__)}
   def launch(command,**kwargs):
    self.assertNotIn('--import',command);self.assertIn('--type-module',command);self.assertIn('Primary='+str(c.resolve()/'Primary/symbolgraphs'),command)
    report=Path(command[command.index('--output')+1]);report.write_text('{}');return SimpleNamespace(returncode=0,poll=lambda:0)
   classification={'status':'native_passes','ordinaryPasses':1,'specializedPasses':0,'nativeFailures':0,'targetSkipped':0,'coverage':{}}
   with patch.object(coordinator,'wheel_identity',return_value=identity),patch.object(coordinator,'extraction',return_value=records),patch.object(coordinator,'toolchain',return_value=tools),patch.object(coordinator,'classify',return_value=classification),patch.object(coordinator.subprocess,'Popen',side_effect=launch) as launched:
    code=coordinator.run(args);self.assertEqual(0,code,(args.output/'Primary.receipt.json').read_text());self.assertEqual(1,launched.call_count);args.resume=True;self.assertEqual(0,coordinator.run(args));self.assertEqual(1,launched.call_count)
    d=json.loads((b/'batch.json').read_text());d['retention']='changed';(b/'batch.json').write_text(json.dumps(d))
    with self.assertRaisesRegex(ValueError,'Resume identity'):coordinator.run(args)
 def test_reference_and_selected_expansion_bounds(self):
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t))
   for name in ('MAX_REFERENCES','MAX_SELECTED_ROWS','MAX_SELECTED_BYTES','MAX_ID_LENGTH','MAX_TOTAL_REFERENCES'):
    with patch.object(helper,name,0),self.assertRaisesRegex(ValueError,'bound'):helper.validate_batch(b,c,records)
 def test_snapshot_is_verified_before_symbol_parse(self):
  from dcflight import ios_type_dependencies as core
  with tempfile.TemporaryDirectory() as t:
   c,b,records=self.fixture(Path(t));original=core.snapshot_symbols;seen=[]
   def snapshot(path,expected,**kwargs):seen.append((str(path),bool(kwargs.get('relationship_handler'))));yield from original(path,expected,**kwargs)
   with patch.object(core,'snapshot_symbols',side_effect=snapshot):helper.validate_batch(b,c,records)
   self.assertEqual(2,sum(not bridge for _,bridge in seen))
   self.assertEqual(1,sum(bridge for _,bridge in seen))
   self.assertEqual({str((c/'Other'/'symbolgraphs'/g['name']).resolve()) for g in records['Other']['graphs']},{path for path,bridge in seen if bridge})
if __name__=='__main__':unittest.main()
