import tempfile,unittest,json
from pathlib import Path
from dcflight.modules.export import _convert
from dcflight.android_api_versions import APIVersions,declaration_descriptors
from dcflight.platforms.android_api import AndroidAPI
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,snapshot_android_source
from dcflight.native_sequence import emit_sequence
from dcflight.android_deployment_validation import levels,operation_for_app

SIGNATURE='''public class fixture.C {
  public static int newer();
    descriptor: ()I
}
'''
class AndroidDeploymentTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.db=self.root/'catalog.sqlite'
 def fixture(self,since=36,removed=None,retained=True,sdks=None):
  xml=('<api version="3"><class name="fixture/C" since="1"><method name="newer()I" since="'+str(since)+'"'+(' removed="'+str(removed)+'"' if removed else '')+(' sdks="'+sdks+'"' if sdks else '')+'/></class></api>').encode()
  raw=self.root/'signatures';raw.write_text(SIGNATURE)
  text,_=_convert('\n'.join(l for l in SIGNATURE.splitlines() if 'descriptor:' not in l))
  source=self.root/'api';source.write_text(text);xp=self.root/'xml';xp.write_bytes(xml)
  api=AndroidAPI(text,api_level=36);records=list(api.records());facts=APIVersions(xml).lookup('fixture/C','method','newer','()I');records[0]['availability'].update(facts)
  provenance={**snapshot_android_source(self.db,source),'sdkArchiveSha256':'a'*64,'availabilityXml':snapshot_android_source(self.db,xp)}
  if retained:provenance['availabilityJvmSignatures']=snapshot_android_source(self.db,raw)
  with Catalog(self.db,write=True) as c:c.import_records('android','sdk-bytecode:36','36',records,provenance)
  return provenance
 def request(self,minimum=36,compile_sdk=36):return dict(platform='android',scope='sdk-bytecode:36',id='fixture.C#newer()',arguments=[],androidMinSdk=minimum,androidCompileSdk=compile_sdk)
 def test_exact_replay_and_version_failures(self):
  self.fixture();api=NativeAPI(self.db)
  self.assertEqual(api.emit(self.request())['versionAvailability']['status'],'base-version-checked')
  for request,error in [(self.request(35),'introduced'),(self.request(35,35),'introduced'),(self.request(36,37),'match')]:
   with self.assertRaisesRegex(ValueError,error):api.emit(request)
  self.assertNotIn('versionAvailability',api.emit({k:v for k,v in self.request().items() if not k.startswith('android')}))
 def test_unknown_compatibility_and_strict(self):
  self.fixture(retained=False)
  api=NativeAPI(self.db,android_deployment={'minimum':26,'compile':35,'requireKnown':False})
  req={k:v for k,v in self.request().items() if not k.startswith('android')}
  self.assertEqual(api.emit(req)['versionAvailability']['status'],'unknown')
  with self.assertRaisesRegex(ValueError,'Unknown'):NativeAPI(self.db).emit(self.request())
  with self.assertRaisesRegex(ValueError,'conflicts'):api.emit(self.request())
 def test_removed_not_runtime_ceiling(self):
  self.fixture(since=26,removed=40)
  with self.assertRaisesRegex(ValueError,'upper-runtime'):NativeAPI(self.db).emit(self.request())
 def test_snapshot_change_even_after_cache(self):
  p=self.fixture();api=NativeAPI(self.db);api.emit(self.request())
  (self.root/p['availabilityJvmSignatures']['sourceRelativePath']).write_text(SIGNATURE.replace('()I','()J'))
  with self.assertRaisesRegex(ValueError,'hash mismatch'):api.emit(self.request())
 def test_mutable_annotation_cannot_certify(self):
  self.fixture()
  with Catalog(self.db) as c:row=c.get('android','fixture.C#newer()','sdk-bytecode:36');source=c.source('android','sdk-bytecode:36')
  row['api']['availability']['minimumApi']=1
  with Catalog(self.db,write=True) as c:c.import_records('android','sdk-bytecode:36','36',[row['api']],source['provenance'])
  with self.assertRaisesRegex(ValueError,'differs'):NativeAPI(self.db).emit(self.request())
 def test_sequence_propagation_and_schema_envelope(self):
  self.fixture();req={'platform':'android','androidMinSdk':36,'androidCompileSdk':36,'steps':[{'id':'fixture.C#newer()','scope':'sdk-bytecode:36','arguments':[],'bind':'answer'}]}
  self.assertEqual(emit_sequence(NativeAPI(self.db),req)['versionAvailability'][0]['minimumApi'],36)
  with self.assertRaisesRegex(ValueError,'introduced'):emit_sequence(NativeAPI(self.db),dict(req,androidMinSdk=35))
 def test_levels_and_app_floor(self):
  for req in ({'androidMinSdk':36,'androidCompileSdk':1000},{'androidMinSdk':26},{'androidMinSdk':True,'androidCompileSdk':36},{'androidMinSdk':36.1,'androidCompileSdk':37},{'androidMinSdk':37,'androidCompileSdk':36}):
   with self.assertRaises(ValueError):levels(req)
  with self.assertRaisesRegex(ValueError,'exceeds'):operation_for_app({'implementations':{'android':{'androidMinSdk':36,'androidCompileSdk':36}}},{'minimum':35,'compile':36})
 def test_covariant_declaration_identity(self):
  text='''public class fixture.C {
  public java.lang.String value();
    descriptor: ()Ljava/lang/String;
  public java.lang.Object value();
    descriptor: ()Ljava/lang/Object;
}
''';bindings={}
  _convert('\n'.join(l for l in text.splitlines() if 'descriptor:' not in l),jvm_descriptors=declaration_descriptors(text),declaration_bindings=bindings)
  self.assertEqual(len(bindings),2)
  self.assertEqual({next(iter(v))[-1] for v in bindings.values()},{'()Ljava/lang/String;','()Ljava/lang/Object;'})
 def test_application_context_and_sdk_guard(self):
  from dcflight.compiler import compile_app
  from dcflight.platforms.ios_api import API
  self.fixture()
  with Catalog(self.db,write=True) as c:c.import_records('ios','Fixture','26.2',[API('iosvalue','Fixture',('answer',),'function',(),'Int',(),()).to_dict()],{})
  operation={'name':'answer','result':'int','execution':'main','implementations':{'ios':{'steps':[{'id':'iosvalue','bind':'v'}],'return':{'ref':'v'}},'android':{'steps':[{'id':'fixture.C#newer()','scope':'sdk-bytecode:36','bind':'v'}],'return':{'ref':'v'}}}}
  doc={'version':2,'id':'com.example.version','name':'Version','sdkCatalog':str(self.db),'nativeOperations':[operation],'nativeConfiguration':{'android':{'compileSdk':36,'minSdk':36,'targetSdk':36,'validateNativeAvailability':True}},'root':{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Home','body':{'id':'label','type':'text','props':{'text':'Hello'}}}]}
  path=self.root/'app.json';path.write_text(json.dumps(doc));out=self.root/'native';compile_app(path,out,targets=('android',))
  self.assertIn('a'*64,(out/'android/app/verified-android-sdk.gradle').read_text())
  self.assertTrue((out/'android/app/native-versions.gradle').exists())
  doc['nativeConfiguration']['android']['minSdk']=35
  with self.assertRaisesRegex(ValueError,'introduced'):compile_app(path,self.root/'invalid',targets=('android',),document=doc)
  operation['implementations']['android'].update(androidMinSdk=36,androidCompileSdk=36)
  with self.assertRaisesRegex(ValueError,'exceeds'):compile_app(path,self.root/'invalid',targets=('android',),document=doc)
 def test_evaluated_dart_operation_reaches_strict_check(self):
  import shutil
  from dcflight.evaluated_frontend import load_evaluated_operation
  from dcflight.native_operation import emit_operation
  dart=shutil.which('dart')
  if dart is None:self.skipTest('Dart authoring SDK required')
  self.fixture();path=self.root/'operation.dart';path.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeOperation buildOperation() => NativeOperation(name:'answer',result:NativeScalar.int,
 ios:const NativeImplementation(steps:[NativeCall('unused',bind:'v')],result:NativeRef('v')),
 android:const NativeImplementation(androidMinSdk:36,androidCompileSdk:36,
 steps:[NativeCall('fixture.C#newer()',scope:'sdk-bytecode:36',bind:'v')],result:NativeRef('v')));
""")
  doc=load_evaluated_operation(path,dart);self.assertEqual(doc['implementations']['android']['androidMinSdk'],36)
  result=emit_operation(NativeAPI(self.db),doc,targets=('android',));self.assertEqual(result['targets']['android']['versionAvailability'][0]['status'],'base-version-checked')
  doc['implementations']['android']['androidMinSdk']=35
  with self.assertRaisesRegex(ValueError,'introduced'):emit_operation(NativeAPI(self.db),doc,targets=('android',))

 def test_extension_only_and_base_alternative(self):
  self.fixture(since=1,sdks='1000000:4')
  with self.assertRaisesRegex(ValueError,'extension-only'):NativeAPI(self.db).emit(self.request())
  request={k:v for k,v in self.request().items() if not k.startswith('android')}
  api=NativeAPI(self.db,android_deployment={'minimum':36,'compile':36,'requireKnown':False})
  self.assertEqual(api.emit(request)['versionAvailability']['status'],'unknown')
  self.fixture(since=1,sdks='0:36,1000000:4')
  with self.assertRaisesRegex(ValueError,'introduced'):NativeAPI(self.db).emit(self.request(35))
  self.assertEqual(NativeAPI(self.db).emit(self.request())['versionAvailability']['minimumApi'],36)

 def test_base_level_helper_matches_extension_policy(self):
  identity={'owner':'fixture/C','kind':'method','name':'newer','descriptor':'()I'}
  def table(sdks):return APIVersions(('<api version="3"><class name="fixture/C" since="1"><method name="newer()I" sdks="'+sdks+'"/></class></api>').encode())
  with self.assertRaisesRegex(ValueError,'extension-only'):table('1000000:4').check_base_level(identity,36)
  with self.assertRaisesRegex(ValueError,'introduced'):table('0:36,1000000:4').check_base_level(identity,35)
  self.assertIsNone(table('0:36,1000000:4').check_base_level(identity,36)['runtimeSupported'])
