import json
import tempfile
import unittest
import subprocess
import shutil
from pathlib import Path
from dcflight.platforms import ios_api as m
from dcflight import native_api as n

class UIKitDispatchTests(unittest.TestCase):
 def api(self,kind='static_property',owner_kind='protocol'):
  return m.API('test','UIKit',('Provider','value()' if kind=='static_method' else 'value'),kind,(),'Int',(),(),owner_kind=owner_kind,writable=True)
 def test_protocol_static_requires_existential_metatype_binding(self):
  c=m.SDKCatalog([self.api()])
  for receiver in [None,m.Reference('type','Provider'),m.Reference('type','Provider.Type'),m.Reference('type','(any Provider).Type'),m.Reference('type','any Other.Type')]:
   with self.assertRaisesRegex(ValueError,'metatype'):c.emit_call('test',receiver=receiver)
  self.assertEqual('`type`.`value`',c.emit_call('test',receiver=m.Reference('type','any Provider.Type')).expression)
  self.assertEqual('`type`.`value` = 3',c.emit_set('test',m.Literal(3),receiver=m.Reference('type','any Provider.Type')).expression)
 def test_protocol_methods_and_concrete_static_unchanged(self):
  self.assertEqual('(`type`.`value`() as Int)',m.SDKCatalog([self.api('static_method')]).emit_call('test',receiver=m.Reference('type','any Provider.Type')).expression)
  c=m.SDKCatalog([self.api(owner_kind='class')]);self.assertEqual('`Provider`.`value`',c.emit_call('test').expression)
  with self.assertRaisesRegex(ValueError,'do not take receivers'):c.emit_call('test',receiver=m.Reference('type','any Provider.Type'))
 def test_generic_owner_requirements_reach_nested_members(self):
  nominal={'identifier':{'precise':'owner'},'kind':{'identifier':'swift.struct'},'pathComponents':['Box'],'swiftGenerics':{'parameters':[{'name':'Value','index':0,'depth':0}]},'declarationFragments':[{'spelling':'struct Box<Value>'}]}
  prop={'identifier':{'precise':'property'},'kind':{'identifier':'swift.property'},'pathComponents':['Box','Nested','count'],'declarationFragments':[{'spelling':'var count: Int { get }'}]}
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'graph.json';p.write_text(json.dumps({'symbols':[nominal,prop]}));c=m.SDKCatalog.from_symbolgraphs([p],'UIKit')
   self.assertIn('generic owner requires explicit specialization',c.get('property').unsupported)
   self.assertEqual(2,c.coverage()['indexed'])
   with self.assertRaisesRegex(ValueError,'specialization'):c.emit_call('property',receiver=m.Reference('box','Box.Nested'))
 def test_generic_specialization_and_restricted_records(self):
  api=m.API('generic','UIKit',('Snapshot','items'),'property',(),'[Item]',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',),owner_constraints=(('conformance','Item','Hashable'),('conformance','Item','Sendable')))
  c=m.SDKCatalog.from_records([api.to_dict()]);out=c.emit_call('generic',receiver=m.Reference('snapshot','Snapshot<String>'))
  self.assertEqual('Array<String>',out.result_type)
  for typ in ['Snapshot','Snapshot<String, Int>','Other<String>','Snapshot<NSObject>','Snapshot<String>?']:
   with self.assertRaises(ValueError):c.emit_call('generic',receiver=m.Reference('snapshot',typ))
  record=api.to_dict();record['nativeConformance']={'status':'rejected'}
  with self.assertRaisesRegex(ValueError,'rejected'):m.SDKCatalog.from_records([record]).emit_call('generic',receiver=m.Reference('snapshot','Snapshot<String>'))
 def test_public_native_api_and_sequence_accept_typed_receivers(self):
  from dcflight.catalog import Catalog
  from dcflight.native_sequence import emit_sequence
  generic=m.API('generic','UIKit',('Snapshot','items'),'property',(),'[Item]',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',),owner_constraints=(('conformance','Item','Hashable'),))
  with tempfile.TemporaryDirectory() as folder:
   db=Path(folder)/'catalog.db'
   with Catalog(db,write=True) as catalog:catalog.import_records('ios','UIKit','26.2',[generic.to_dict(),self.api().to_dict(),m.API('nested','UIKit',('Outer','Inner','item'),'property',(),'Item',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',),generic_owner='Outer').to_dict()],{'fixture':True})
   native=n.NativeAPI(db)
   result=emit_sequence(native,{'platform':'ios','inputs':[{'name':'snapshot','type':'Snapshot<String>'},{'name':'provider','type':'any Provider.Type'}],'steps':[{'id':'generic','receiver':{'ref':'snapshot'},'bind':'items'},{'id':'test','receiver':{'ref':'provider'},'bind':'count'}]})
   self.assertEqual('Array<String>',result['bindings'][0]['type'])
   self.assertIn('`provider`.`value`',result['source'])
   self.assertIsNone(result['compilerRuntimeDependency'])
   nested=emit_sequence(native,{'platform':'ios','inputs':[{'name':'nested','type':'Outer<String>.Inner'}],'steps':[{'id':'nested','receiver':{'ref':'nested'},'bind':'item'}]})
   self.assertEqual('String',nested['bindings'][0]['type'])
   record=generic.to_dict();record['unsupportedReasons'].append('Descriptor explicitly disables emission')
   with Catalog(db,write=True) as catalog:catalog.import_records('ios','Blocked','26.2',[record],{'fixture':True})
   with self.assertRaisesRegex(ValueError,'Unsupported API'):native.emit({'platform':'ios','scope':'Blocked','id':'generic','receiver':{'ref':'snapshot','type':'Snapshot<String>'}})


from dcflight.platforms.swift_types import parse_type, spelling
from dcflight.platforms.ios_api import API, SDKCatalog, Reference

class NestedTypeTests(unittest.TestCase):
 def test_structural_nested_type_roundtrip(self):
  for source in ['Outer<Int, String>.Inner','Outer<Int>.Inner<String>.Leaf?','Array<Outer<Int>.Inner>','((Outer<Int>.Inner) -> Void)?']:
   self.assertEqual(source,spelling(parse_type(source)))
  for source in ['Outer<Int>.','Outer<Int>..Inner','Outer<Int>.Inner; fatalError()','Outer<Int>?.Inner','Outer<Int>.1Bad']:
   with self.assertRaises(ValueError):parse_type(source)
 def test_nested_owner_specialization(self):
  api=API('nested','UIKit',('Outer','Inner','item'),'property',(),'Item',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',),owner_constraints=(('conformance','Item','Hashable'),),generic_owner='Outer')
  c=SDKCatalog.from_records([api.to_dict()]);self.assertEqual('String',c.emit_call('nested',receiver=Reference('r','Outer<String>.Inner')).result_type)
  for source in ['Outer<String>.Other','Outer<NSObject>.Inner','Outer<String>.Inner<Int>','Outer<String>.Inner?']:
   with self.assertRaises(ValueError):c.emit_call('nested',receiver=Reference('r',source))
 def test_generic_metatype_substitution_and_associated_type_rejection(self):
  from dataclasses import replace
  api=API('meta','UIKit',('Box','type'),'property',(),'Item.Type',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',))
  receiver=Reference('r','Box<Array<Int>>')
  self.assertEqual('Array<Int>.Type',SDKCatalog([api]).emit_call('meta',receiver=receiver).result_type)
  with self.assertRaisesRegex(ValueError,'Dependent generic member'):SDKCatalog([replace(api,result='Item.Element')]).emit_call('meta',receiver=receiver)
 def test_native_metatype_precedence_and_roundtrip(self):
  import os
  from dataclasses import replace
  api=API('meta','Foundation',('Box','type'),'property',(),'Item.Type',(),('generic owner requires explicit specialization',),owner_kind='struct',owner_parameters=('Item',))
  cases=['() -> Int','() async throws -> Int','@Sendable () -> Int','Int?','(Int, String)','any P','(() -> Int)?']
  sources=['protocol P {}','struct Box<Item> { var type: Item.Type { Item.self } }']
  for i,argument in enumerate(cases):
   receiver=Reference('box','Box<'+argument+'>');out=SDKCatalog([api]).emit_call('meta',receiver=receiver)
   self.assertEqual(out.result_type,spelling(parse_type(out.result_type)))
   sources.append('func proof'+str(i)+'(box: '+receiver.type+') { let _: '+out.result_type+' = '+out.expression+' }')
  if not shutil.which('xcrun'):self.skipTest('Swift compiler required')
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'Metatypes.swift';p.write_text('\n'.join(sources))
   result=subprocess.run(['xcrun','swiftc','-typecheck','-swift-version','6','-module-cache-path',str(Path(folder)/'cache'),str(p)],capture_output=True,text=True)
   self.assertEqual(0,result.returncode,result.stderr)
 def test_distinct_generic_depth_is_not_inherited_by_name(self):
  def nominal(path,depth):
   return {'identifier':{'precise':'.'.join(path)},'kind':{'identifier':'swift.struct'},'pathComponents':path,'swiftGenerics':{'parameters':[{'name':'T','depth':depth,'index':0}]},'declarationFragments':[{'spelling':'struct '+path[-1]}]}
  prop={'identifier':{'precise':'prop'},'kind':{'identifier':'swift.property'},'pathComponents':['Outer','Inner','value'],'declarationFragments':[{'spelling':'var value: T { get }'}]}
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'graph.json';p.write_text(json.dumps({'symbols':[nominal(['Outer'],0),nominal(['Outer','Inner'],1),prop]}));catalog=SDKCatalog.from_symbolgraphs([p],'Fixture')
   self.assertFalse(catalog.get('prop').owner_parameters)
   with self.assertRaisesRegex(ValueError,'specialization'):catalog.emit_call('prop',receiver=Reference('r','Outer<Int>.Inner'))
 def test_shadowed_generic_metadata_stays_rejected(self):
  def nominal(path,parameters):
   return {'identifier':{'precise':'.'.join(path)},'kind':{'identifier':'swift.struct'},'pathComponents':path,'swiftGenerics':{'parameters':[{'name':name,'depth':depth,'index':index} for depth,index,name in parameters]},'declarationFragments':[{'spelling':'struct '+path[-1]}]}
  prop={'identifier':{'precise':'prop'},'kind':{'identifier':'swift.property'},'pathComponents':['Outer','Inner','value'],'declarationFragments':[{'spelling':'var value: Item { get }'}]}
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'s.json';p.write_text(json.dumps({'symbols':[nominal(['Outer'],[(0,0,'Item')]),nominal(['Outer','Inner'],[(0,0,'Item'),(1,0,'Item')]),prop]}));c=SDKCatalog.from_symbolgraphs([p],'UIKit')
   self.assertFalse(c.get('prop').owner_parameters)
   with self.assertRaisesRegex(ValueError,'specialization'):c.emit_call('prop',receiver=Reference('r','Outer<Int>.Inner<String>'))


if __name__ == "__main__":
 unittest.main()
