from ios_sdk_fixture import fake_toolchain, write_sdk
import copy,hashlib,json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from dcflight import ios_verification as v

def symbol(identity,result):
 return {'identifier':{'precise':identity},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner',identity],'declarationFragments':[{'spelling':'static var '+identity+': '+result+' { get }'}]}
class ImportContractTests(unittest.TestCase):
 def fixture(self,root):
  graphs=root/'graphs';graphs.mkdir();(graphs/'plain.symbols.json').write_text(json.dumps({'symbols':[symbol('plain','Date')]}));(graphs/'overlay.symbols.json').write_text(json.dumps({'symbols':[symbol('overlay','Int')],'module':{'bystanders':['Foundation']}}));return graphs
 def native(self,command,**kwargs):
  source=Path(command[-1]).read_text();self.sources.append(source)
  if 'Date' in source and 'import Foundation\n' not in source:
   line=next(i for i,l in enumerate(source.splitlines(),1) if 'Date' in l)
   return SimpleNamespace(returncode=1,stdout=f'Verify.swift:{line}:1: error: cannot find type Date in scope')
  return SimpleNamespace(returncode=0,stdout='')
 def generate(self,root):
  graphs=self.fixture(root);report=root/'report.json';self.sources=[]
  with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',side_effect=self.native):
   self.assertEqual(1,v.main(['--module','Fixture='+str(graphs),'--output',str(report)],progress=False))
  return graphs,report,json.loads(report.read_text())
 def test_emitted_bystanders_compile_without_cross_candidate_leak(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,path,report=self.generate(root)
   self.assertEqual(['overlay'],[x['id'] for x in report['passed']]);self.assertEqual(['plain'],[x['id'] for x in report['failed']])
   self.assertEqual(2,len(self.sources));self.assertFalse(any('Date' in s and 'import Foundation\n' in s for s in self.sources))
   self.assertEqual(['Fixture','Foundation'],report['passed'][0]['imports'])
   self.assertEqual(1,v.export_records({'Fixture':graphs},path,root/'records')['Fixture']['native_tested'])
 def test_export_rejects_tampered_import_source_or_command(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,path,original=self.generate(root)
   mutations=[lambda d:d.pop('compilerSources'),lambda d:d.update(compilerSources={}),lambda d:d['passed'][0]['imports'].append('Unproven'),lambda d:d['passed'][0].update(source='let fake=1'),lambda d:d['invocations'][0].update(sourceSHA256='0'*64),lambda d:d['invocations'][0]['command'].append('-disable-availability-checking'),lambda d:d.update(invocations=[])]
   for i,mutate in enumerate(mutations):
    data=copy.deepcopy(original);mutate(data);path.write_text(json.dumps(data))
    with self.assertRaises(ValueError):v.export_records({'Fixture':graphs},path,root/('bad'+str(i)))
    self.assertFalse((root/('bad'+str(i))).exists())
 def test_explicit_imports_apply_to_every_candidate(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs=self.fixture(root);path=root/'report.json';self.sources=[]
   with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',side_effect=self.native):
    self.assertEqual(0,v.main(['--module','Fixture='+str(graphs),'--import','Foundation','--output',str(path)],progress=False))
   report=json.loads(path.read_text());self.assertEqual(2,report['nativeTested']);self.assertEqual(1,len(self.sources));v.export_records({'Fixture':graphs},path,root/'records')
if __name__=='__main__':unittest.main()
