from ios_sdk_fixture import fake_toolchain, write_sdk
import copy,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from dcflight import ios_verification as v
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.platforms.ios_api import TargetAvailabilityError,SDKCatalog,Reference

def member(availability):
 return {'identifier':{'precise':'target-member'},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner','value'],'declarationFragments':[{'spelling':'static var value: Int { get }'}],'availability':availability}
class TargetAvailabilityTests(unittest.TestCase):
 def generate(self,root,availability):
  graph=root/'graphs';graph.mkdir();(graph/'Fixture.symbols.json').write_text(json.dumps({'symbols':[member(availability)]}));report=root/'report.json'
  with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run') as native:
   self.assertEqual(1,v.main(['--module','Fixture='+str(graph),'--output',str(report)],progress=False));native.assert_not_called()
  return graph,report
 def export(self,root,graphs,report):
  dest=root/'records';summary=v.export_records({'Fixture':graphs},report,dest);record=json.loads((dest/'Fixture.jsonl').read_text());db=root/'catalog.sqlite'
  with Catalog(db,write=True) as c:c.import_records('ios','Fixture','26.2',[record],{'fixture':'typed target availability'})
  return record,NativeAPI(db),db,summary
 def test_target_skip_retains_raw_contract_no_compiled_credit(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);g,p=self.generate(root,[{'domain':'iOS','introduced':{'major':26}}]);record,api,db,summary=self.export(root,g,p)
   self.assertTrue(record['emittable']);self.assertEqual([],record['unsupportedReasons']);self.assertEqual('target_unavailable',record['nativeConformance']['status']);self.assertEqual(0,summary['Fixture']['native_tested'])
   with self.assertRaises(TargetAvailabilityError):api.emit({'platform':'ios','id':'target-member','iosVersion':[18,0]})
   self.assertEqual('Int',api.emit({'platform':'ios','id':'target-member','iosVersion':[26,2]})['resultType'])
   with Catalog(db) as c:self.assertEqual([],c.evidence_groups('ios','Fixture'))
 def test_unconditional_and_swift_unavailable_stay_closed(self):
  for availability in [[{'domain':'iOS','isUnconditionallyUnavailable':True}],[{'domain':'Swift','obsoleted':{'major':5}}]]:
   with self.subTest(availability=availability),tempfile.TemporaryDirectory() as t:
    root=Path(t);g,p=self.generate(root,availability);record,api,db,_=self.export(root,g,p);self.assertFalse(record['emittable'])
    with self.assertRaises(ValueError):api.emit({'platform':'ios','id':'target-member','iosVersion':[26,2]})
 def test_classification_tamper_rejected_and_unclassified_skip_closed(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);g,p=self.generate(root,[{'domain':'iOS','introduced':{'major':26}}]);original=json.loads(p.read_text())
   for i,change in enumerate([lambda x:x.update(kind='other'),lambda x:x.update(boundary=[25,0]),lambda x:x.update(extra=True)]):
    data=copy.deepcopy(original);change(data['skipped'][0]['classification']);p.write_text(json.dumps(data))
    with self.assertRaises(ValueError):v.export_records({'Fixture':g},p,root/('bad'+str(i)))
   data=copy.deepcopy(original);data['skipped'][0].pop('classification');p.write_text(json.dumps(data));record,_,_,_=self.export(root,g,p);self.assertFalse(record['emittable'])
 def test_nonavailability_cannot_forge_typed_classification(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);g,p=self.generate(root,[{'domain':'iOS','isUnconditionallyUnavailable':True}]);data=json.loads(p.read_text());data['skipped']=[{'module':'Fixture','id':'target-member','reason':'forged'}];data['skippedCount']=1;data['skipped'][0]['classification']={'kind':'iosTargetAvailability','constraint':'introduced','target':[18,0],'boundary':[26,0]};p.write_text(json.dumps(data))
   with self.assertRaisesRegex(ValueError,'SDK failure'):v.export_records({'Fixture':g},p,root/'bad')
 def test_selected_class_fact_uses_typed_check_without_unbound_promotion(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graph=root/'Fixture.symbols.json'
   graph.write_text(json.dumps({'symbols':[
    {'identifier':{'precise':'Box'},'kind':{'identifier':'swift.class'},'pathComponents':['Box'],'declarationFragments':[{'spelling':'class Box<T> where T: AnyObject'}],'swiftGenerics':{'parameters':[{'name':'T','index':0,'depth':0}],'constraints':[]}},
    {'identifier':{'precise':'Future'},'kind':{'identifier':'swift.class'},'pathComponents':['Future'],'declarationFragments':[{'spelling':'class Future'}],'availability':[{'domain':'iOS','introduced':{'major':26}}]},
    {'identifier':{'precise':'value'},'kind':{'identifier':'swift.property'},'pathComponents':['Box','value'],'declarationFragments':[{'spelling':'var value: T { get }'}]}]}))
   catalog=SDKCatalog.from_symbolgraphs([graph],'Fixture');record=catalog.get('value').to_dict();self.assertFalse(record['emittable'])
   with self.assertRaises(TargetAvailabilityError):catalog.emit_call('value',receiver=Reference('box','Box<Future>'),ios_version=(18,0))
   self.assertEqual('Future',catalog.emit_call('value',receiver=Reference('box','Box<Future>'),ios_version=(26,2)).result_type)
   self.assertFalse(catalog.get('value').to_dict()['emittable'])
if __name__=='__main__':unittest.main()
