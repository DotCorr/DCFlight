import copy,json,tempfile,unittest,os,subprocess,shutil
from pathlib import Path
from dcflight.platforms.ios_api import SDKCatalog,Reference
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence

def nominal(name,kind='class',availability=()):
 return {'identifier':{'precise':name},'kind':{'identifier':'swift.'+kind},'pathComponents':[name],'declarationFragments':[{'spelling':kind+' '+name}],'availability':list(availability)}
def graph(declaration='class Box<T> where T : AnyObject',structured=(),extras=()):
 owner=nominal('Box');owner['declarationFragments']=[{'spelling':declaration}];owner['swiftGenerics']={'parameters':[{'name':'T','index':0,'depth':0}],'constraints':list(structured)}
 return {'symbols':[owner,nominal('Asset'),nominal('Value','struct'),nominal('Delegate','protocol'),{'identifier':{'precise':'value'},'kind':{'identifier':'swift.property'},'pathComponents':['Box','value'],'declarationFragments':[{'spelling':'var value: T { get }'}]},*extras]}
class ClassConstraintTests(unittest.TestCase):
 def catalog(self,data=None):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);p=Path(tmp.name)/'Fixture.symbols.json';p.write_text(json.dumps(data or graph()));return SDKCatalog.from_symbolgraphs([p],'Fixture')
 def test_declaration_class_bound_survives_single_record_roundtrip(self):
  c=self.catalog();a=c.get('value');self.assertEqual(a.owner_constraints,(('conformance','T','AnyObject'),));self.assertFalse(a.to_dict()['emittable'])
  r=a.to_dict();self.assertEqual(r['ownerClassFacts'][0]['kind'],'class');self.assertEqual(len(r['ownerClassFacts'][0]['sourceSHA256']),64)
  c=SDKCatalog.from_records([r]);self.assertEqual(c.emit_call('value',receiver=Reference('box','Box<Asset>')).result_type,'Asset')
  self.assertEqual(c.emit_call('value',receiver=Reference('box','Box<Fixture.Asset>')).result_type,'Fixture.Asset')
  for typ in ('Int','Value','Delegate','Unknown','Asset?','Array<Asset>','any Delegate','Asset.Type'):
   with self.subTest(typ=typ),self.assertRaises(ValueError):c.emit_call('value',receiver=Reference('box','Box<'+typ+'>'))
 def test_public_native_api_and_sequence_use_single_generic_descriptor(self):
  a=self.catalog().get('value').to_dict()
  with tempfile.TemporaryDirectory() as tmp:
   path=Path(tmp)/'db'
   with Catalog(path,write=True) as c:c.import_records('ios','Fixture','26.2',[a],{'fixture':True})
   api=NativeAPI(path);r=api.emit({'platform':'ios','id':'value','receiver':{'ref':'box','type':'Box<Asset>'}});self.assertEqual(r['resultType'],'Asset');self.assertIsNone(r['runtimeDependency'])
   seq=emit_sequence(api,{'platform':'ios','inputs':[{'name':'box','type':'Box<Asset>'}],'steps':[{'id':'value','receiver':{'ref':'box'},'bind':'result'}]});self.assertEqual(seq['bindings'][0]['type'],'Asset')
   with self.assertRaises(ValueError):api.emit({'platform':'ios','id':'value','receiver':{'ref':'box','type':'Box<Int>'}})
 def test_inline_newline_and_unknown_requirements_fail_closed(self):
  for declaration in ('class Box<T: AnyObject>','class Box<T>\nwhere T: Swift.AnyObject'):
   c=self.catalog(graph(declaration));self.assertEqual(c.emit_call('value',receiver=Reference('box','Box<Asset>')).result_type,'Asset')
  for declaration in ('class Box<T> where T: UnknownProtocol','class Box<T> where T == Asset','class Box<T> where T : AnyObject & Unknown','class Box<T> where T.Element : AnyObject','class Box<T> where T: AnyObject, broken','class Box<T> where Wrong: AnyObject'):
   with self.subTest(declaration=declaration),self.assertRaises(ValueError):self.catalog(graph(declaration)).emit_call('value',receiver=Reference('box','Box<Asset>'))
 def test_existing_single_pack_witness_preserves_structured_identity(self):
  data=graph('struct Box<each T>');data['symbols'][0]['kind']['identifier']='swift.struct'
  c=self.catalog(data);self.assertEqual(c.emit_call('value',receiver=Reference('box','Box<Int>')).result_type,'Int')
 def test_structured_requirement_is_intersected_not_overwritten(self):
  c=self.catalog(graph(structured=[{'kind':'conformance','lhs':'T','rhs':'Sendable'}]));self.assertIn(('conformance','T','AnyObject'),c.get('value').owner_constraints)
  with self.assertRaises(ValueError):c.emit_call('value',receiver=Reference('box','Box<Asset>'))
 def test_class_availability_and_probe_witness_are_target_aware(self):
  data=graph(extras=[nominal('AFuture',availability=[{'domain':'iOS','introduced':{'major':26}}])]);c=self.catalog(data)
  self.assertEqual(c.probe_receiver('value',(18,0)).type,'Box<Fixture.Asset>')
  with self.assertRaisesRegex(ValueError,'availability'):c.emit_call('value',receiver=Reference('box','Box<AFuture>'),ios_version=(18,0))
  self.assertEqual(c.emit_call('value',receiver=Reference('box','Box<AFuture>'),ios_version=(26,0)).result_type,'AFuture')
 def test_malformed_class_facts_and_restricted_catalog_are_rejected(self):
  original=self.catalog().get('value').to_dict()
  for key,value in [('kind','struct'),('module','Other'),('sourceSHA256','not-hash'),('spelling','Asset;evil'),('availability',[{'domain':'iOS','introduced':{'major':-1}}])]:
   record=copy.deepcopy(original);record['ownerClassFacts'][0][key]=value
   with self.subTest(key=key),self.assertRaises(ValueError):SDKCatalog.from_records([record])
  record=copy.deepcopy(original);record['unsupportedReasons'].append('Explicitly restricted')
  with self.assertRaisesRegex(ValueError,'restricted'):SDKCatalog.from_records([record]).emit_call('value',receiver=Reference('box','Box<Asset>'))
 @unittest.skipUnless(shutil.which('xcrun'),'Apple compiler required')
 def test_native_class_specialization_executes_and_struct_is_rejected(self):
  emitted=self.catalog().emit_call('value',receiver=Reference('box','Box<Asset>'))
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);source=root/'main.swift';binary=root/'app'
   source.write_text('class Asset { let number = 42 }\nclass Box<T: AnyObject> { let value: T; init(_ value: T) { self.value=value } }\nlet box=Box(Asset())\nlet selected: '+emitted.result_type+' = '+emitted.expression+'\nprint(selected.number)\n')
   env={**os.environ,'CLANG_MODULE_CACHE_PATH':os.environ.get('CLANG_MODULE_CACHE_PATH',str(root/'cache'))}
   proc=subprocess.run(['xcrun','swiftc',str(source),'-o',str(binary)],capture_output=True,text=True,env=env);self.assertEqual(proc.returncode,0,proc.stderr)
   self.assertEqual(subprocess.check_output([str(binary)],text=True).strip(),'42')
   source.write_text('struct Asset {}\nclass Box<T: AnyObject> {}\nlet _: Box<Asset>? = nil\n')
   proc=subprocess.run(['xcrun','swiftc','-typecheck',str(source)],capture_output=True,text=True,env=env);self.assertNotEqual(proc.returncode,0);self.assertIn('class type',proc.stderr)
 def test_missing_generic_parameter_identity_is_not_treated_as_nongeneric(self):
  data=graph();data['symbols'][0].pop('swiftGenerics');c=self.catalog(data)
  with self.assertRaisesRegex(ValueError,'generic|Generic'):c.emit_call('value',receiver=Reference('box','Box'))
 def test_fact_limit_and_generic_class_arguments_stay_closed(self):
  data=graph(extras=[nominal('Asset'+str(i)) for i in range(129)]);c=self.catalog(data)
  with self.assertRaisesRegex(ValueError,'bounded source class index'):c.emit_call('value',receiver=Reference('box','Box<Asset>'))
  generic=nominal('Generic');generic['swiftGenerics']={'parameters':[{'name':'U','index':0,'depth':0}]};generic['declarationFragments']=[{'spelling':'class Generic<U>'}]
  c=self.catalog(graph(extras=[generic]));self.assertNotIn('Generic',[f['spelling'] for f in c.get('value').class_facts])
if __name__=='__main__':unittest.main()
