import copy,gzip,hashlib,importlib.util,json,tempfile,unittest
from pathlib import Path
from dcflight.platforms.ios_api import SDKCatalog,Reference
from dcflight.ios_bridge_types import PROTOCOL
from dcflight.ios_type_dependencies import plan
from dcflight.ios_type_dependency_batch import plan_batch
from dcflight.symbolgraph import graph_paths,symbols
from test_ios_type_dependencies import capture,member,nominal

def bridge_fixture(root,*,relation=True,value_since=14):
 call=member(ref='objc:reference');call['declarationFragments'][1]['spelling']='Value'
 capture(root,'Primary',[call])
 value=nominal('swift:value','Value');value['availability']=[{'domain':'iOS','introduced':{'major':value_since}}]
 reference=nominal('objc:reference','ValueReference');reference['kind']['identifier']='swift.class'
 alias=nominal('swift:alias','ReferenceType');alias['kind']['identifier']='swift.typealias';alias['pathComponents']=['Value','ReferenceType'];alias['declarationFragments']=[{'spelling':'typealias ReferenceType = '},{'kind':'typeIdentifier','spelling':'ValueReference','preciseIdentifier':'objc:reference'}]
 graph=capture(root,'Types',[value,reference,alias]);update_graph(graph,relationships=[{'kind':'conformsTo','source':'swift:value','target':PROTOCOL},{'kind':'memberOf','source':'swift:alias','target':'swift:value'}] if relation else [])
 return graph

def update_graph(graph,**changes):
 data=json.loads(gzip.decompress(graph.read_bytes()));data.update(changes);raw=json.dumps(data).encode();encoded=gzip.compress(raw,mtime=0);graph.write_bytes(encoded)
 p=graph.parent.parent/'status.json';status=json.loads(p.read_text());status['artifacts']['graphs'][0].update(sha256=hashlib.sha256(encoded).hexdigest(),rawSHA256=hashlib.sha256(raw).hexdigest());p.write_text(json.dumps(status))

class BridgeTests(unittest.TestCase):
 def catalog(self,root):return SDKCatalog.from_symbolgraphs(graph_paths(root/'Primary/symbolgraphs'),'Primary',type_graphs={'Types':graph_paths(root/'Types/symbolgraphs')})
 def test_full_graph_contract_preserves_exposed_identity(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root);api=self.catalog(root).get('call');self.assertEqual('Value',api.result);self.assertEqual({'swift:value','objc:reference','swift:alias'},{r['id'] for r in api.type_resolutions});self.assertEqual(PROTOCOL,api.bridge_resolutions[0]['conformances'][0]['relationship']['target']);self.assertEqual(api.to_dict(),SDKCatalog.from_records([api.to_dict()]).get('call').to_dict())
 def test_no_conformance_is_not_a_spelling_bridge(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root,relation=False);api=self.catalog(root).get('call');self.assertEqual('ValueReference',api.result);self.assertFalse(api.bridge_resolutions)
 def test_alias_cannot_point_at_different_reference_identity(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);g=bridge_fixture(root);doc=json.loads(gzip.decompress(g.read_bytes()));doc['symbols'][2]['declarationFragments'][1]['preciseIdentifier']='different';update_graph(g,symbols=doc['symbols']);self.assertEqual('ValueReference',self.catalog(root).get('call').result)
 def test_reference_spelling_is_not_replaced_with_value(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root);g=next((root/'Primary/symbolgraphs').iterdir());doc=json.loads(gzip.decompress(g.read_bytes()));doc['symbols'][0]['declarationFragments'][1]['spelling']='ValueReference';update_graph(g,symbols=doc['symbols']);api=self.catalog(root).get('call');self.assertEqual('ValueReference',api.result);self.assertFalse(api.bridge_resolutions)
 def test_exposed_value_availability_applies(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root,value_since=26);api=self.catalog(root).get('call');self.assertIn({'domain':'iOS','introduced':{'major':26}},api.availability)
 def test_bridge_availability_uses_native_call_gate(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root,value_since=26);cat=self.catalog(root)
   with self.assertRaises(ValueError):cat.emit_call('call',ios_version=(18,0))
   self.assertEqual('Value',cat.emit_call('call',ios_version=(26,2)).result_type)
  for role in (1,2):
   with self.subTest(role=role),tempfile.TemporaryDirectory() as d:
    root=Path(d);g=bridge_fixture(root);doc=json.loads(gzip.decompress(g.read_bytes()));doc['symbols'][role]['availability']=[{'domain':'iOS','isUnconditionallyUnavailable':True}];update_graph(g,symbols=doc['symbols']);cat=self.catalog(root)
    with self.assertRaises(ValueError):cat.emit_call('call',ios_version=(26,2))
 def test_same_spelling_conflicting_value_ids_reject(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);g=bridge_fixture(root);doc=json.loads(gzip.decompress(g.read_bytes()));other=copy.deepcopy(doc['symbols'][0]);other['identifier']['precise']='swift:other';update_graph(g,symbols=doc['symbols']+[other])
   with self.assertRaisesRegex(ValueError,'Ambiguous'):self.catalog(root)
 def test_conflicting_reference_alias_targets_reject(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);g=bridge_fixture(root);doc=json.loads(gzip.decompress(g.read_bytes()));other=copy.deepcopy(doc['symbols'][2]);other['declarationFragments'][1]['preciseIdentifier']='another:reference';update_graph(g,symbols=doc['symbols']+[other])
   with self.assertRaisesRegex(ValueError,'Conflicting bridge ReferenceType'):self.catalog(root)
 def test_membership_required_and_conditional_owner_not_guessed(self):
  for mode in ('missing','conditional','conflicting'):
   with self.subTest(mode=mode),tempfile.TemporaryDirectory() as d:
    root=Path(d);g=bridge_fixture(root);doc=json.loads(gzip.decompress(g.read_bytes()))
    if mode=='missing':doc['relationships'].pop()
    elif mode=='conditional':doc['relationships'][-1]['swiftConstraints']=[{'kind':'conformance','lhs':'T','rhs':'P'}]
    else:doc['relationships'][-1]['target']='unrelated'
    update_graph(g,relationships=doc['relationships'])
    if mode=='conflicting':
     with self.assertRaisesRegex(ValueError,'owner identity'):self.catalog(root)
    else:self.assertEqual('ValueReference',self.catalog(root).get('call').result)
 def test_record_conformance_tampering_rejects(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bridge_fixture(root);record=self.catalog(root).get('call').to_dict();record['bridgeResolutions'][0]['conformances'][0]['relationship']['source']='unrelated'
   with self.assertRaisesRegex(ValueError,'conformance'):SDKCatalog.from_records([record])
 def test_single_minimal_plan_retains_exact_bridge_evidence(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);source=root/'capture';bridge_fixture(source);out=root/'plan';report=plan(source,'Primary',out)
   self.assertEqual(3,len(report['selectedNominals']));self.assertEqual(1,len(report['bridgeEnrichment']));self.assertEqual(0,report['nativeTested']);api=SDKCatalog.from_symbolgraphs(graph_paths(out/'primary'),'Primary',type_graphs={'Types':graph_paths(out/'types/Types')}).get('call');self.assertEqual('Value',api.result)
 def test_batch_plan_matches_single_plan_and_replay_rejects_forgery(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);source=root/'capture';bridge_fixture(source);batch=root/'batch';plan_batch(source,batch,disk_floor=0);single=plan(source,'Primary',root/'single');mf=batch/'plans/Primary/type-dependencies.json';report=json.loads(mf.read_text());self.assertEqual(single['selectedNominals'],report['selectedNominals']);self.assertEqual(single['bridgeEnrichment'],report['bridgeEnrichment'])
   p=Path(__file__).parents[1]/'tools/ios_type_plan_validation.py';spec=importlib.util.spec_from_file_location('bridge_plan_validator',p);v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);records={}
   for p in source.glob('*/status.json'):
    status=json.loads(p.read_text());records[p.parent.name]={'status':'success','statusSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'provenance':status['provenance'],'graphs':[{'name':g['path'],'sha256':g['sha256']} for g in status['artifacts']['graphs']]}
   self.assertEqual('planned',v.validate_batch(batch,source,records)['modules']['Primary']['status'])
   derived=batch/'plans/Primary'/report['derived'][0]['path'];doc=json.loads(derived.read_text());doc['relationships'][0]['target']='other';derived.write_text(json.dumps(doc));report['derived'][0]['sha256']=hashlib.sha256(derived.read_bytes()).hexdigest();mf.write_text(json.dumps(report));b=json.loads((batch/'batch.json').read_text());next(x for x in b['modules'] if x['module']=='Primary')['manifestSHA256']=hashlib.sha256(mf.read_bytes()).hexdigest();(batch/'batch.json').write_text(json.dumps(b))
   with self.assertRaisesRegex(ValueError,'structure'):v.validate_batch(batch,source,records)
 def test_stream_relationships_preserve_metadata_and_bounds(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'graph.json';p.write_text(json.dumps({'relationships':[{'kind':'conformsTo'}],'symbols':[]}));r=[];self.assertEqual([],list(symbols(p,relationship_handler=r.append)));self.assertEqual([{'kind':'conformsTo'}],r)
   with self.assertRaisesRegex(ValueError,'bound'):list(symbols(p,max_bytes=3))
if __name__=='__main__':unittest.main()
