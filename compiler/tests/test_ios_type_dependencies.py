import gzip,json,tempfile,unittest,hashlib,io,os
from pathlib import Path
from unittest.mock import patch
from dcflight.ios_type_dependencies import plan,object_sha,copy_checked,sha,read_bounded,chunks,directory_entries
from dcflight.platforms.ios_api import SDKCatalog
from dcflight.symbolgraph import graph_paths

def nominal(identity,spelling):return {'identifier':{'precise':identity},'kind':{'identifier':'swift.struct'},'pathComponents':[spelling],'declarationFragments':[{'spelling':'struct '+spelling}]}
def member(identity='call',ref='type:wanted'):
 return {'identifier':{'precise':identity},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner','value'],'declarationFragments':[{'spelling':'static var value: '},{'kind':'typeIdentifier','spelling':'OldName','preciseIdentifier':ref},{'spelling':' { get }'}]}
def capture(root,module,syms):
 p=root/module/'symbolgraphs';p.mkdir(parents=True);raw=json.dumps({'symbols':syms}).encode();data=gzip.compress(raw,mtime=0);graph=p/(module+'.symbols.json.gz');graph.write_bytes(data)
 status={'module':module,'status':'success','proofReusable':True,'extractionProvenanceVerified':True,'provenance':{'sdk':'fixture','sdkVersion':'26.2','sdkSettingsSHA256':'0'*64,'target':'arm64-apple-ios18.0-simulator'},'artifacts':{'graphs':[{'path':graph.name,'sha256':hashlib.sha256(data).hexdigest(),'rawSHA256':hashlib.sha256(raw).hexdigest()}]}}
 (p.parent/'status.json').write_text(json.dumps(status));return graph
class TypeDependencyTests(unittest.TestCase):
 def test_exact_id_subset_avoids_unrelated_cross_module_collision(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);capture(source,'First',[nominal('type:wanted','Renamed'),nominal('type:unrelated','Collision')]);capture(source,'Second',[nominal('type:unrelated','Other')])
   with self.assertRaisesRegex(ValueError,'Conflicting imported'):SDKCatalog.from_symbolgraphs(graph_paths(source/'Primary/symbolgraphs'),'Primary',type_graphs={m:graph_paths(source/m/'symbolgraphs') for m in ['First','Second']})
   out=r/'out';report=plan(source,'Primary',out);self.assertEqual({'First':'types/First'},report['typeModules']);self.assertEqual(0,report['nativeTested']);self.assertEqual(['type:wanted'],[x['id'] for x in report['selectedNominals']])
   c=SDKCatalog.from_symbolgraphs(graph_paths(out/'primary'),'Primary',type_graphs={'First':graph_paths(out/'types/First')});self.assertEqual('Renamed',c.get('call').result)
   for row in report['retained']:self.assertEqual(hashlib.sha256((out/row['original']).read_bytes()).hexdigest(),row['sha256'])
 def test_referenced_collision_fails_before_output(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);capture(source,'First',[nominal('type:wanted','Foo')]);capture(source,'Second',[nominal('type:wanted','Foo')])
   with self.assertRaisesRegex(ValueError,'Ambiguous referenced'):plan(source,'Primary',r/'out')
   self.assertFalse((r/'out').exists())
 def test_same_spelling_never_substitutes_different_identity(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);capture(source,'Other',[nominal('type:different','OldName')]);report=plan(source,'Primary',r/'out');self.assertEqual({},report['typeModules']);self.assertEqual(['type:wanted'],report['unresolvedTypeIDs'])
 def test_mixed_environment_or_corrupt_inputs_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);g=capture(source,'Other',[nominal('type:wanted','Foo')]);s=g.parent.parent/'status.json';d=json.loads(s.read_text());d['provenance']['target']='arm64-apple-ios18.0';s.write_text(json.dumps(d))
   with self.assertRaisesRegex(ValueError,'Mixed SDK'):plan(source,'Primary',r/'out')
   g.write_bytes(b'corrupt')
   with self.assertRaisesRegex(ValueError,'Retained graph changed'):plan(source,'Primary',r/'out')
 def test_output_parent_symlink_and_unknown_selected_identity_reject(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);real=r/'real';real.mkdir();link=r/'link';link.symlink_to(real,target_is_directory=True)
   with self.assertRaisesRegex(ValueError,'symlink'):plan(source,'Primary',link/'out')
   with self.assertRaisesRegex(ValueError,'not present'):plan(source,'Primary',r/'out',identities=['missing'])
   self.assertEqual([],list(real.iterdir()))
 def test_snapshot_hash_check_rejects_changed_bytes(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);p=r/'source';p.write_bytes(b'changed')
   with self.assertRaisesRegex(ValueError,'changed before snapshot'):copy_checked(p,r/'copy','0'*64)
 def test_conflicting_same_source_nominal_rejects(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()]);a=nominal('type:wanted','Foo');b=dict(a,availability=[{'domain':'iOS','introduced':{'major':26}}]);capture(source,'Other',[a,b])
   with self.assertRaisesRegex(ValueError,'Conflicting duplicate'):plan(source,'Primary',r/'out')
   self.assertFalse((r/'out').exists())
 def test_total_output_including_manifest_is_bounded(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);source=r/'capture';capture(source,'Primary',[member()])
   with patch('dcflight.ios_type_dependencies.MAX_RETAINED',1000):
    with self.assertRaisesRegex(ValueError,'bundle exceeds'):plan(source,'Primary',r/'out')
   self.assertFalse((r/'out').exists());self.assertEqual([],list(r.glob('.type-plan-*')))
 def test_reads_reject_nonregular_and_oversized_inputs(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);fifo=r/'fifo';os.mkfifo(fifo)
   for action in (lambda:sha(fifo),lambda:read_bounded(fifo,8),lambda:copy_checked(fifo,r/'out','0'*64)):
    with self.assertRaisesRegex(ValueError,'Nonregular'):action()
   regular=r/'large';regular.write_bytes(b'12345')
   with self.assertRaisesRegex(ValueError,'oversized'):sha(regular,4)
   with self.assertRaisesRegex(ValueError,'beyond bound'):list(chunks(io.BytesIO(b'12345'),4))
 def test_directory_entries_are_bounded_before_sorting(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t)
   for i in range(3):(r/str(i)).touch()
   with self.assertRaisesRegex(ValueError,'entry count'):directory_entries(r,2)
if __name__=='__main__':unittest.main()
