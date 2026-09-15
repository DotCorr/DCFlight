import copy,json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from ios_sdk_fixture import fake_toolchain
from dcflight import ios_verification as v
from dcflight.platforms.ios_api import SDKCatalog

class VariantVerificationTests(unittest.TestCase):
 def fixture(self,root):
  graphs=root/'graphs';graphs.mkdir()
  callback={'identifier':{'precise':'sdk:read'},'kind':{'identifier':'swift.method'},'pathComponents':['Owner','read(completion:)'],'declarationFragments':[{'spelling':'func read(completion: @escaping (Int) -> Void)'}],'functionSignature':{'parameters':[{'name':'completion','declarationFragments':[{'spelling':'completion: @escaping (Int) -> Void'}]}]}}
  async_=copy.deepcopy(callback);async_['pathComponents']=['Owner','read()'];async_['declarationFragments']=[{'spelling':'func read() async -> Int'}];async_['functionSignature']={'returns':[{'spelling':'Int'}]}
  (graphs/'Fixture.symbols.json').write_text(json.dumps({'symbols':[callback,async_]}));return graphs
 def native(self,command,**kwargs):
  source=Path(command[-1]).read_text()
  for line,text in enumerate(source.splitlines(),1):
   if 'await' in text:return SimpleNamespace(returncode=1,stdout=f'Verify.swift:{line}:1: error: ambiguous async form')
  return SimpleNamespace(returncode=0,stdout='')
 def test_context_certificate_binds_explicit_variant(self):
  from dcflight import ios_invocation_evidence as e
  from dcflight.symbolgraph import graph_paths
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs=self.fixture(root);catalog=SDKCatalog.from_symbolgraphs(graph_paths(graphs),'Fixture')
   chosen=next(key for key,api in catalog.variants['sdk:read'].items() if api.async_)
   with patch.object(e.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(e,'_compile',return_value=(True,'')):
    report=e.verify_invocations(graphs,'Fixture',['sdk:read'],root/'context.json',contexts=('main',),variant_selections={'sdk:read':chosen})
    record=e.conditional_records(report)[0]
    selected=e.select_invocation(record,{'variant':chosen,'actorContext':'main'})
    self.assertEqual(chosen,selected['variant'])
    with self.assertRaisesRegex(ValueError,'variant differs'):e.select_invocation(record,{'actorContext':'main'})
    wrong=copy.deepcopy(report);wrong['invocations'][0]['variant']='swift-v1:'+'0'*64
    with self.assertRaises(ValueError):e.conditional_records(wrong)

 def test_unclassified_skips_require_known_explicit_variant(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs=self.fixture(root);path=root/'report.json'
   with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',side_effect=self.native):
    v.main(['--module','Fixture='+str(graphs),'--output',str(path)],progress=False)
   data=json.loads(path.read_text());skips=[{'module':x['module'],'id':x['id'],'variant':x['variant'],'reason':'diagnostic skip'} for x in data['passed']+data['failed']]
   data.update(passed=[],failed=[],skipped=skips,nativeTested=0,failedCount=0,skippedCount=len(skips),candidateCount=0,invocations=[])
   for i,value in enumerate(('swift-v1:'+'0'*64,None,'missing')):
    wrong=copy.deepcopy(data)
    if value=='missing':wrong['skipped'][0].pop('variant')
    else:wrong['skipped'][0]['variant']=value
    path.write_text(json.dumps(wrong))
    with self.assertRaises(ValueError):v.export_records({'Fixture':graphs},path,root/('badskip'+str(i)))
    self.assertFalse((root/('badskip'+str(i))).exists())

 def test_variant_export_keeps_selector_and_separates_results(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs=self.fixture(root);report=root/'report.json'
   with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',side_effect=self.native):
    self.assertEqual(1,v.main(['--module','Fixture='+str(graphs),'--import','Foundation','--output',str(report)],progress=False))
   data=json.loads(report.read_text());self.assertEqual((1,1),(data['nativeTested'],data['failedCount']))
   self.assertNotEqual(data['passed'][0]['variant'],data['failed'][0]['variant'])
   output=root/'out';summary=v.export_records({'Fixture':graphs},report,output)['Fixture']
   self.assertEqual(1,summary['indexed']);self.assertEqual(2,summary['variants_indexed'])
   record=json.loads((output/'Fixture.jsonl').read_text());self.assertFalse(record['emittable']);self.assertNotIn('nativeConformance',record)
   parsed=SDKCatalog.from_records([record]);self.assertEqual(2,len(parsed.variants['sdk:read']))
   self.assertEqual({data['passed'][0]['variant'],data['failed'][0]['variant']},set(parsed.variants['sdk:read']))
   for child in record['nativeVariants']:self.assertEqual(child['variant'],child['nativeConformance']['variant'])
   for index,mutate in enumerate([lambda d:d['passed'][0].update(variant=d['failed'][0]['variant']),lambda d:d['passed'][0]['imports'].append('Unverified'),lambda d:d['invocations'][0]['members'][0].pop('variant')]):
    wrong=copy.deepcopy(data);mutate(wrong);report.write_text(json.dumps(wrong))
    with self.assertRaises(ValueError):v.export_records({'Fixture':graphs},report,root/('bad'+str(index)))
    self.assertFalse((root/('bad'+str(index))).exists())

if __name__=='__main__':unittest.main()
