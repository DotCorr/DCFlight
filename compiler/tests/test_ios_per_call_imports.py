import copy,json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from ios_sdk_fixture import fake_toolchain
from dcflight import ios_verification as v
from dcflight.platforms.ios_api import SDKCatalog,Reference

def symbol(identity,owner='Owner',result='Int',extension=None):
 value={'identifier':{'precise':identity},'kind':{'identifier':'swift.property'},'pathComponents':[owner,'value'],'declarationFragments':[{'spelling':'var value: '+result+' { get }'}]}
 if extension is not None:value['swiftExtension']=extension
 return value
class PerCallImportTests(unittest.TestCase):
 def graph(self,root,name,values):
  path=root/name;path.mkdir();(path/(name+'.symbols.json')).write_text(json.dumps({'symbols':values}));return path
 def test_exact_extension_owner_import_survives_single_record(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);graphs=self.graph(root,'Primary',[symbol('owner',owner='Decimal',extension={'extendedModule':'Foundation','typeKind':'swift.struct'})]);c=SDKCatalog.from_symbolgraphs(list(graphs.iterdir()),'Primary');record=next(c.records());self.assertEqual(['Foundation'],record['requiredImports']);r=SDKCatalog.from_records([record]);self.assertEqual(('Foundation','Primary'),r.emit_call('owner',[],receiver=Reference('receiver','Decimal')).imports)
 def test_extension_import_metadata_rejects_malformed_and_conflicting_identity(self):
  for extension in ({'extendedModule':'Bad;Code'}, {'extendedModule':None}, []):
   with self.subTest(extension=extension),tempfile.TemporaryDirectory() as t:
    g=self.graph(Path(t),'Primary',[symbol('id',extension=extension)])
    with self.assertRaises(ValueError):SDKCatalog.from_symbolgraphs(list(g.iterdir()),'Primary')
  with tempfile.TemporaryDirectory() as t:
   g=self.graph(Path(t),'Primary',[symbol('id',extension={'extendedModule':'One'}),symbol('id',extension={'extendedModule':'Two'})])
   with self.assertRaisesRegex(ValueError,'Conflicting extension'):SDKCatalog.from_symbolgraphs(list(g.iterdir()),'Primary')
 def fixture(self,root,extra=False):
  plain=symbol('plain',owner='Never',extension={'extendedModule':'Swift'});dated=symbol('date');dated['declarationFragments']=[{'spelling':'var value: '},{'kind':'typeIdentifier','preciseIdentifier':'date.type','spelling':'Date'},{'spelling':' { get }'}]
  primary=self.graph(root,'Primary',[plain,dated]);dependency=self.graph(root,'Foundation',[{'identifier':{'precise':'date.type'},'kind':{'identifier':'swift.struct'},'pathComponents':['Date'],'declarationFragments':[{'spelling':'struct Date'}]}]);unused=self.graph(root,'Unused',[]);path=root/'report.json';args=['--module','Primary='+str(primary),'--type-module','Foundation='+str(dependency),'--type-module','Unused='+str(unused),'--output',str(path)]
  if extra:args+=['--import','Authored']
  with patch.object(v.subprocess,'check_output',side_effect=fake_toolchain(root,'fixture')),patch.object(v.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='')):self.assertEqual(0,v.main(args,progress=False))
  return primary,{'Foundation':dependency,'Unused':unused},path,json.loads(path.read_text())
 def test_unused_automatic_modules_do_not_leak_but_explicit_imports_remain(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);primary,types,path,data=self.fixture(root,True);rows={r['id']:r for r in data['passed']};self.assertEqual(['Authored','Primary','Swift'],rows['plain']['imports']);self.assertEqual(['Authored','Foundation','Primary'],rows['date']['imports']);v.export_records({'Primary':primary},path,root/'records',type_modules=types)
   records={r['id']:r for r in map(json.loads,(root/'records/Primary.jsonl').read_text().splitlines())};self.assertEqual(['Authored','Swift'],records['plain']['requiredImports']);self.assertEqual(['Authored','Foundation'],records['date']['requiredImports'])
 def test_import_mode_tamper_rejects_before_export(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);primary,types,path,data=self.fixture(root)
   for i,value in enumerate((None,'all','guessed')):
    changed=copy.deepcopy(data)
    if value is None:changed.pop('automaticTypeImports')
    else:changed['automaticTypeImports']=value
    path.write_text(json.dumps(changed));out=root/('rejected'+str(i))
    with self.assertRaisesRegex(ValueError,'automatic type import'):v.export_records({'Primary':primary},path,out,type_modules=types)
    self.assertFalse(out.exists())
 def test_partial_type_graph_requires_explicit_import_without_precise_evidence(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);g=self.graph(root,'Primary',[symbol('id',result='Date')]);d=self.graph(root,'Foundation',[]);c=SDKCatalog.from_symbolgraphs(list(g.iterdir()),'Primary',type_graphs={'Foundation':list(d.iterdir())});self.assertEqual(['Primary'],v.candidate_for(c,c.get('id'),'Primary',(18,0),[])['imports']);self.assertEqual(['Foundation','Primary'],v.candidate_for(c,c.get('id'),'Primary',(18,0),['Foundation'])['imports'])
if __name__=='__main__':unittest.main()
