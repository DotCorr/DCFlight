import tempfile,json,unittest,os
from pathlib import Path
from unittest.mock import patch
from test_ios_type_dependencies import capture,member,nominal
from dcflight.ios_type_dependencies import plan,sha
from dcflight import ios_type_dependency_batch as batch
class BatchTypeTests(unittest.TestCase):
 def test_equivalent_plans_and_one_symbol_scan(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);c=root/'capture';capture(c,'Primary',[member()]);capture(c,'Other',[nominal('type:wanted','Name')]);capture(c,'Third',[member('third')]);expected={m:plan(c,m,root/('single'+m)) for m in ('Primary','Other','Third')};calls=[];original=batch.symbols
   def read(path):calls.append(str(path));yield from original(path)
   with patch.object(batch,'symbols',side_effect=read):result=batch.plan_batch(c,root/'batch',disk_floor=0)
   self.assertEqual(3,len(calls));self.assertEqual(3,result['symbolScans']);self.assertTrue(result['indexRemoved']);self.assertFalse((root/'batch/index.sqlite').exists())
   for row in result['modules']:
    self.assertEqual('planned',row['status']);p=root/'batch'/row['path'];actual=json.loads((p/'type-dependencies.json').read_text());self.assertEqual(expected[row['module']],actual)
    for artifact in actual['retained']:self.assertEqual(artifact['sha256'],sha(p/artifact['original']))
   # Retention aliases share only the private copied pool, never capture input.
   primary=next((root/'batch/plans/Primary/primary').iterdir());self.assertNotEqual(primary.stat().st_ino,next((c/'Primary/symbolgraphs').iterdir()).stat().st_ino);self.assertGreater(primary.stat().st_nlink,1)
 def test_ambiguity_has_explicit_rejection_not_missing_scope(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);capture(c,'First',[nominal('type:wanted','Name')]);capture(c,'Second',[nominal('type:wanted','Name')])
   with self.assertRaisesRegex(ValueError,'Ambiguous'):plan(c,'Primary',r/'single')
   report=batch.plan_batch(c,r/'batch',disk_floor=0);row=next(x for x in report['modules'] if x['module']=='Primary');self.assertEqual('rejected',row['status']);self.assertIn('Ambiguous',row['reason']);self.assertFalse((r/'batch/plans/Primary').exists())
 def test_conflicting_duplicate_has_same_failure(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);a=nominal('type:wanted','Name');capture(c,'Other',[a,{**a,'availability':[{'domain':'iOS','introduced':{'major':26}}]}]);d=batch.plan_batch(c,r/'batch',modules=['Primary'],disk_floor=0);self.assertEqual('rejected',d['modules'][0]['status']);self.assertIn('Conflicting duplicate',d['modules'][0]['reason'])
 def test_mixed_context_and_malformed_inputs_publish_nothing(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);p=capture(c,'Other',[nominal('type:wanted','Name')]);status=p.parent.parent/'status.json';d=json.loads(status.read_text());d['provenance']['target']='different';status.write_text(json.dumps(d))
   with self.assertRaisesRegex(ValueError,'Mixed'):batch.plan_batch(c,r/'batch',disk_floor=0)
   self.assertFalse((r/'batch').exists());p.write_bytes(b'corrupt')
   with self.assertRaises(ValueError):batch.plan_batch(c,r/'corrupt',disk_floor=0)
   self.assertFalse((r/'corrupt').exists())
 def test_changed_capture_during_scan_rejects_atomically(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';p=capture(c,'Primary',[member()]);original=batch.symbols
   def read(path):yield from original(path);p.write_bytes(b'changed')
   with patch.object(batch,'symbols',side_effect=read),self.assertRaisesRegex(ValueError,'changed'):batch.plan_batch(c,r/'batch',disk_floor=0)
   self.assertFalse((r/'batch').exists());self.assertFalse(list(r.glob('.type-batch-*')))
 def test_bounds_and_linked_output_reject(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);real=r/'real';real.mkdir();link=r/'link';link.symlink_to(real,target_is_directory=True)
   with self.assertRaises(ValueError):batch.plan_batch(c,link/'out',disk_floor=0)
   with patch.object(batch,'MAX_INDEX_BYTES',1),self.assertRaisesRegex(ValueError,'index'):batch.plan_batch(c,r/'index',disk_floor=0)
   with patch.object(batch,'MAX_BATCH_BYTES',1),self.assertRaisesRegex(ValueError,'output'):batch.plan_batch(c,r/'bytes',disk_floor=0)
   self.assertFalse((r/'index').exists());self.assertFalse((r/'bytes').exists())
 def test_selected_nominal_accumulation_is_bounded(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);capture(c,'Other',[nominal('type:wanted','Name')])
   for constant in ('MAX_SELECTED_ROWS','MAX_SELECTED_BYTES'):
    with patch.object(batch,constant,0):result=batch.plan_batch(c,r/constant,modules=['Primary'],disk_floor=0)
    self.assertEqual('rejected',result['modules'][0]['status']);self.assertIn('rows/bytes',result['modules'][0]['reason'])
 def test_reference_bound_applies_after_local_exclusion(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);c=r/'capture';capture(c,'Primary',[member(str(i),'type:'+str(i)) for i in range(16385)])
   result=batch.plan_batch(c,r/'out',modules=['Primary'],disk_floor=0)
   self.assertEqual('rejected',result['modules'][0]['status']);self.assertIn('Referenced type',result['modules'][0]['reason'])
if __name__=='__main__':unittest.main()
