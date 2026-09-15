import copy,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_operation import emit_operation
from dcflight.platforms.ios_api import API
from dcflight.compiler import compile_app
from dcflight.audit import source_consistency

class TargetScopeTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name);self.db=self.root/'sdk.sqlite'
  sdk=self.root/'sdk.txt';sdk.write_text('package java.lang {\n public class Boolean {\n method public static java.lang.String toString(boolean);\n }\n}')
  index_android(self.db,sdk)
  with Catalog(self.db,write=True) as c:c.import_records('ios','Foundation','26',[API('ios-value','Foundation',('UUID','uuidString'),'static_property',(),'String',(),()).to_dict()],{})
  self.op={'name':'value','execution':'main','result':'string','implementations':{'ios':{'steps':[{'id':'ios-value','bind':'v'}],'return':{'ref':'v'}},'android':{'steps':[{'id':'java.lang.Boolean#toString(boolean)','arguments':[{'literal':True}],'bind':'v'}],'return':{'ref':'v'}}}}
  self.doc={'version':2,'id':'com.test.scoped','name':'Scoped','state':{'text':''},'sdkCatalog':str(self.db),'nativeOperations':[self.op],'root':{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Home','body':{'id':'label','type':'text','props':{'text':{'ref':'text'}}}}]}
  self.source=self.root/'app.json';self.source.write_text(json.dumps(self.doc))
 def test_only_requested_platform_reaches_sdk_emitter(self):
  real=NativeAPI.emit
  for target in ('ios','android'):
   calls=[]
   def emit(api,request):
    calls.append(request['platform'])
    if request['platform']!=target:raise RuntimeError('Foreign SDK/toolchain unavailable')
    return real(api,request)
   with patch.object(NativeAPI,'emit',emit):compile_app(self.source,self.root/target,targets=(target,))
   self.assertTrue(calls);self.assertEqual(set(calls),{target})
 def test_both_catalog_descriptors_remain_shared_inputs(self):
  doc=copy.deepcopy(self.doc);doc['nativeOperations'][0]['implementations']['ios']['steps'][0]['id']='not-indexed'
  with self.assertRaises(ValueError):compile_app(self.source,self.root/'missing-descriptor',targets=('android',),document=doc)
 def test_foreign_deployment_check_scoped(self):
  doc=copy.deepcopy(self.doc);doc['nativeOperations'][0]['implementations']['ios']['iosVersion']=[99,0]
  compile_app(self.source,self.root/'android',targets=('android',),document=doc)
  with self.assertRaisesRegex(ValueError,'above app deployment'):compile_app(self.source,self.root/'ios',targets=('ios',),document=doc)
 def test_shared_contract_and_envelope_still_checked(self):
  for mutation in (lambda v:v['implementations'].pop('ios'),lambda v:v['implementations']['ios'].update(injected='text'),lambda v:v['implementations']['ios'].update(steps=[]),lambda v:v['implementations']['ios'].update({'return':'raw'})):
   op=copy.deepcopy(self.op);mutation(op)
   with self.assertRaises(ValueError):emit_operation(NativeAPI(self.db),op,targets=('android',))
  for targets in ((),('web',),('ios','ios')):
   with self.assertRaises(ValueError):emit_operation(NativeAPI(self.db),self.op,targets=targets)
 def test_unselected_sequence_shape_and_dataflow(self):
  changes=[lambda i:i['steps'][0].update(arguments='not-array'),lambda i:i['steps'][0].update(arguments=[42]),lambda i:i['steps'][0].update(receiver={'ref':'missing'}),lambda i:i.update({'return':{'ref':'missing'}}),lambda i:i['steps'][0].update(bind='not a name'),lambda i:i['steps'][0].update(bind='dcfLocal0'),lambda i:i['steps'].append(copy.deepcopy(i['steps'][0])),lambda i:i.update(steps=[{'project':{'ref':'missing','index':0},'bind':'v'}]),lambda i:i.update(steps=[{'project':{'ref':'v','index':True},'bind':'v'}]),lambda i:i.update(steps=[{'unwrap':{'ref':'missing'},'bind':'v','message':'missing'}]),lambda i:i['steps'][0].update(arguments=[{'ref':'v','type':'String'}])]
  for index,change in enumerate(changes):
   with self.subTest(index=index):
    doc=copy.deepcopy(self.doc);change(doc['nativeOperations'][0]['implementations']['ios']);out=self.root/('invalid'+str(index))
    with self.assertRaises(ValueError):compile_app(self.source,out,targets=('android',),document=doc)
    self.assertFalse(out.exists())
  with self.assertRaises(ValueError):emit_operation(NativeAPI(self.db),self.op,targets=([],))
 def test_receiver_requires_reference_on_both_graphs(self):
  for target in ('ios','android'):
   for receiver in ({'literal':'not a ref'},{'null':'java.lang.String'},{'array':[],'type':'int[]'}):
    with self.subTest(target=target,receiver=receiver):
     doc=copy.deepcopy(self.doc);foreign='android' if target=='ios' else 'ios';doc['nativeOperations'][0]['implementations'][foreign]['steps'][0]['receiver']=receiver
     with self.assertRaises(ValueError):compile_app(self.source,self.root/'invalid-receiver',targets=(target,),document=doc)
 def test_unselected_type_and_literal_bounds(self):
  deep=0
  for _ in range(18):deep=[deep]
  changes=[{'constructedType':'java.lang.String; injected'}, {'constructedType':'int'}, {'constructedType':'java.util.List<?>'}, {'typeArguments':['int']}, {'typeArguments':['T']}, {'typeArguments':['java.lang.String; injected']}]
  changes += [{'arguments':[{'literal':v}]} for v in (deep,[0]*4096,{'nested':'\ud800'},float('nan'))]
  for index,change in enumerate(changes):
   with self.subTest(index=index):
    doc=copy.deepcopy(self.doc);doc['nativeOperations'][0]['implementations']['android']['steps'][0].update(change)
    with self.assertRaises(ValueError):compile_app(self.source,self.root/'invalid-types',targets=('ios',),document=doc)
 def test_selected_failure_still_fails_before_sync(self):
  doc=copy.deepcopy(self.doc);doc['nativeOperations'][0]['implementations']['android']['steps'][0]['id']='missing';out=self.root/'failure'
  with self.assertRaises(ValueError):compile_app(self.source,out,targets=('android',),document=doc)
  self.assertFalse(out.exists())
 def test_standalone_default_and_sequential_receipts(self):
  self.assertEqual(set(emit_operation(NativeAPI(self.db),self.op)['targets']),{'ios','android'})
  out=self.root/'paired';compile_app(self.source,out,targets=('ios',));compile_app(self.source,out,targets=('android',))
  self.assertEqual(source_consistency(out)['status'],'matched')
  receipt=json.loads((out/'.dcflight/source.json').read_text());self.assertEqual(set(receipt['nativeOperationEmissions']),{'ios','android'})
  with Catalog(self.db,write=True) as c:c.import_records('ios','Unrelated','26',[],{'unrelated':True})
  compile_app(self.source,out,targets=('ios',));self.assertEqual(source_consistency(out)['status'],'matched')
  with Catalog(self.db,write=True) as c:
   record=c.get('ios','ios-value','Foundation')['api'];c.import_records('ios','Foundation','26',[record],{'revision':2})
  compile_app(self.source,out,targets=('ios',));self.assertEqual(source_consistency(out)['status'],'mismatched')
  compile_app(self.source,out,targets=('android',));self.assertEqual(source_consistency(out)['status'],'matched')
if __name__=='__main__':unittest.main()
