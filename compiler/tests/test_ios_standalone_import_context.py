from ios_sdk_fixture import fake_toolchain
import json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from dcflight import ios_verification as v
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.platforms.ios_api import SDKCatalog

class StandaloneImportContextTests(unittest.TestCase):
 def fixture(self,root):
  graphs=root/'graphs';graphs.mkdir();types=root/'types';types.mkdir()
  (graphs/'Fixture.symbols.json').write_text(json.dumps({'symbols':[{'identifier':{'precise':'date'},'kind':{'identifier':'swift.type.property'},'pathComponents':['Owner','date'],'declarationFragments':[{'spelling':'static var date: '},{'kind':'typeIdentifier','spelling':'Date','preciseIdentifier':'foundation.date'},{'spelling':' { get }'}]}]}))
  (types/'Foundation.symbols.json').write_text(json.dumps({'symbols':[{'identifier':{'precise':'foundation.date'},'kind':{'identifier':'swift.struct'},'pathComponents':['Date'],'declarationFragments':[{'spelling':'struct Date'}]}]}))
  report=root/'report.json'
  with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):
   self.assertEqual(0,v.main(['--module','Fixture='+str(graphs),'--type-module','Foundation='+str(types),'--output',str(report)],progress=False))
  return graphs,types,report
 def test_type_module_context_survives_public_single_record_authoring(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,types,report=self.fixture(root);out=root/'records'
   self.assertEqual(1,v.export_records({'Fixture':graphs},report,out,type_modules={'Foundation':types})['Fixture']['native_tested'])
   record=json.loads((out/'Fixture.jsonl').read_text());self.assertEqual(['Foundation'],record['requiredImports'])
   db=root/'catalog.sqlite'
   with Catalog(db,write=True) as catalog:catalog.import_records('ios','Fixture','26.2',[record],{'fixture':True})
   result=NativeAPI(db).emit({'platform':'ios','id':'date','actorContext':'main'})
   self.assertEqual(['Fixture','Foundation'],result['imports'])
 def test_future_target_skip_preserves_type_module_context_without_credit(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,types,path=self.fixture(root)
   graph=graphs/'Fixture.symbols.json';data=json.loads(graph.read_text());data['symbols'][0]['availability']=[{'domain':'iOS','introduced':{'major':26,'minor':0}}];graph.write_text(json.dumps(data));path.unlink()
   with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):
    v.main(['--module','Fixture='+str(graphs),'--type-module','Foundation='+str(types),'--output',str(path)],progress=False)
   out=root/'records';summary=v.export_records({'Fixture':graphs},path,out,type_modules={'Foundation':types})
   self.assertEqual(0,summary['Fixture']['native_tested']);record=json.loads((out/'Fixture.jsonl').read_text());self.assertTrue(record['emittable']);self.assertEqual(['Foundation'],record['requiredImports'])
   db=root/'catalog.sqlite'
   with Catalog(db,write=True) as catalog:catalog.import_records('ios','Fixture','26.2',[record],{'fixture':True})
   request={'platform':'ios','id':'date','actorContext':'main','iosVersion':[18,0]}
   with self.assertRaises(ValueError):NativeAPI(db).emit(request)
   request['iosVersion']=[26,2];self.assertEqual(['Fixture','Foundation'],NativeAPI(db).emit(request)['imports'])
 def test_oversized_unavailable_context_rejects_before_output(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,types,path=self.fixture(root)
   graph=graphs/'Fixture.symbols.json';data=json.loads(graph.read_text());data['symbols'][0]['availability']=[{'domain':'iOS','introduced':{'major':26,'minor':0}}];graph.write_text(json.dumps(data));path.unlink()
   arguments=['--module','Fixture='+str(graphs),'--type-module','Foundation='+str(types),'--output',str(path)]
   for i in range(32):arguments += ['--import','Extra'+str(i)]
   with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):v.main(arguments,progress=False)
   out=root/'records'
   with self.assertRaisesRegex(ValueError,'32 module'):v.export_records({'Fixture':graphs},path,out,type_modules={'Foundation':types})
   self.assertFalse(out.exists())
 def test_standalone_replay_failure_creates_no_output(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,types,report=self.fixture(root);out=root/'records'
   with patch.object(SDKCatalog,'from_records',side_effect=ValueError('descriptor replay rejects')):
    with self.assertRaisesRegex(ValueError,'descriptor replay'):v.export_records({'Fixture':graphs},report,out,type_modules={'Foundation':types})
   self.assertFalse(out.exists())
 def test_standalone_replay_cannot_use_hidden_verifier_imports(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs,types,report=self.fixture(root);out=root/'records';original=v.candidate_for
   calls=[0]
   def candidate(catalog,api,module,version,imports,variant=None):
    calls[0]+=1;result=original(catalog,api,module,version,imports,variant)
    if calls[0]>1:result['imports']=['Fixture']
    return result
   with patch.object(v,'candidate_for',side_effect=candidate):
    with self.assertRaisesRegex(ValueError,'standalone'):v.export_records({'Fixture':graphs},report,out,type_modules={'Foundation':types})
   self.assertFalse(out.exists())
if __name__=='__main__':unittest.main()
