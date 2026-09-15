import copy,json,tempfile,unittest,os,shutil
from pathlib import Path
from dcflight.native_configuration import lower_native_configuration
from dcflight.ios_deployment import check_binding,operation_for_app
from dcflight.compiler import compile_app
from dcflight.catalog import Catalog
from dcflight.native_api import index_android
from dcflight.platforms.ios_api import API
from dcflight.backends.ios import PROJECT
from dcflight.registry import Registry
from dcflight.navigation_ir import schema

class DeploymentTests(unittest.TestCase):
 def test_typed_schema(self):
  import jsonschema
  from dcflight.validate import lower
  d={'version':1,'id':'com.test.deploy','name':'Deployment','root':{'id':'text','type':'text','props':{'text':'Hello'}},'nativeConfiguration':{'ios':{'deploymentTarget':[18,2]}}}
  self.assertEqual(lower(d,Registry()).native_configuration.ios_deployment_target,(18,2))
  jsonschema.validate(d,Registry().schema())
  for v in ([16,9],[18],[18,True],'18.0',[100,0],[18,-1]):
   bad=copy.deepcopy(d);bad['nativeConfiguration']['ios']['deploymentTarget']=v
   with self.subTest(value=v),self.assertRaises(ValueError):lower(bad,Registry())
   with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(bad,Registry().schema())
 def test_evaluated_dart_target_parity(self):
  from dcflight.evaluated_frontend import load_evaluated
  from dcflight.validate import lower
  dart=os.environ.get('DCFLIGHT_TEST_DART') or shutil.which('dart')
  if not dart:self.skipTest('Dart SDK required')
  with tempfile.TemporaryDirectory() as directory:
   path=Path(directory)/'app.dart'
   path.write_text("import 'package:dcflight_authoring/dcflight.dart'; App buildApp() => App(id: 'com.test.deploy', name: 'Deployment', nativeConfiguration: NativeConfiguration(ios: IOSConfiguration(deploymentTarget: [18, 2])), root: Text('Hello', id: 'label'));")
   document=load_evaluated(path,dart)
   self.assertEqual(document['nativeConfiguration']['ios']['deploymentTarget'],[18,2])
   self.assertEqual(lower(document,Registry()).native_configuration.ios_deployment_target,(18,2))
 def test_strict_real_project_binding(self):
  project=PROJECT.replace('__APP_ID__','com.test.deploy').replace('__APP_NAME__','"Test"')
  check_binding(project,(18,0))
  for text in [project.replace('baseConfigurationReference = 100000000000000000000014;',''),project.replace('path = Native/Logic.xcconfig;','path = Elsewhere.xcconfig;'),project.replace('PRODUCT_NAME = App;','PRODUCT_NAME = App; IPHONEOS_DEPLOYMENT_TARGET = 17.0;'),project.replace('baseConfigurationReference = 100000000000000000000014;','/* baseConfigurationReference = 100000000000000000000014; */')]:
   with self.assertRaises(ValueError):check_binding(text,(18,0))
 def test_operation_defaults_and_no_implicit_raise(self):
  op={'name':'test','implementations':{'ios':{'steps':[]}}}
  self.assertEqual(operation_for_app(op,(17,0))['implementations']['ios']['iosVersion'],[17,0])
  self.assertNotIn('iosVersion',op['implementations']['ios'])
  op['implementations']['ios']['iosVersion']=[18,0]
  with self.assertRaises(ValueError):operation_for_app(op,(17,0))
  self.assertEqual(operation_for_app(op,(19,0))['implementations']['ios']['iosVersion'],[18,0])
 def test_generated_target_regeneration_preserves_user_project(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);d={'version':1,'id':'com.test.deploy','name':'Deployment','root':{'id':'text','type':'text','props':{'text':'Hello'}},'nativeConfiguration':{'ios':{'deploymentTarget':[17,0]}}}
   source=root/'app.json';source.write_text(json.dumps(d));out=root/'app'
   compile_app(source,out,targets=('ios',));project=out/'ios/App.xcodeproj/project.pbxproj';before=project.read_bytes()
   d['nativeConfiguration']['ios']['deploymentTarget']=[18,2];compile_app(source,out,targets=('ios',),document=d)
   self.assertEqual(project.read_bytes(),before);self.assertIn('IPHONEOS_DEPLOYMENT_TARGET = 18.2',(out/'ios/Native/Logic.xcconfig').read_text())
   project.write_text(project.read_text().replace('baseConfigurationReference = 100000000000000000000014;',''))
   config=(out/'ios/Native/Logic.xcconfig').read_bytes();d['nativeConfiguration']['ios']['deploymentTarget']=[19,0]
   with self.assertRaises(ValueError):compile_app(source,out,targets=('ios',),document=d)
   self.assertEqual((out/'ios/Native/Logic.xcconfig').read_bytes(),config)
 def test_normal_operation_availability_checked_before_writes(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);db=root/'api.sqlite'
   old=API('old','UIKit',('UIApplication','openSettingsURLString'),'static_property',(),'String',({'domain':'iOS','introduced':{'major':8,'minor':0}},),()).to_dict()
   new=API('new','UIKit',('UIAccessibilityCustomAction','editCategory'),'static_property',(),'String',({'domain':'iOS','introduced':{'major':18,'minor':0}},),()).to_dict()
   # Only the harmless real spelling is used; parser/compiler availability is the test.
   with Catalog(db,write=True) as c:c.import_records('ios','test','26',[old,new],{})
   a=root/'android.txt';a.write_text('package java.lang {\n public class Boolean {\n method public static java.lang.String toString(boolean);\n }\n}');index_android(db,a)
   d={'version': 2, 'id': 'com.dotcorr.deploymentaudit', 'name': 'Deployment audit', 'state': {'value': '', 'status': ''}, 'sdkCatalog': '/Users/ghostportal/Desktop/Dotcorr/DCFlight/compiler/registry/sdk/current.sqlite', 'nativeOperations': [{'name': 'readIOS18Constant', 'execution': 'main', 'parameters': [], 'result': 'string', 'throws': True, 'implementations': {'ios': {'steps': [{'id': 'c:@UIAccessibilityCustomActionCategoryEdit', 'scope': 'UIKit', 'bind': 'value'}], 'return': {'ref': 'value'}}, 'android': {'steps': [{'id': 'java.lang.Boolean#toString(boolean)', 'scope': 'core-bytecode', 'arguments': [{'literal': True}], 'bind': 'value'}], 'return': {'ref': 'value'}}}}], 'root': {'id': 'stack', 'type': 'navigationStack', 'props': {'initialRoute': 'home'}}, 'routes': [{'id': 'home', 'title': 'Audit', 'body': {'id': 'label', 'type': 'text', 'props': {'text': {'ref': 'status'}}}}], 'flowActions': [{'id': 'read', 'cases': [{'code': 0, 'effects': [{'op': 'nativeOperation', 'operation': 'readIOS18Constant', 'target': 'value', 'success': 'accepted', 'failure': 'rejected'}]}]}, {'id': 'accepted', 'cases': [{'code': 0, 'effects': [{'op': 'set', 'target': 'status', 'value': 'passed'}]}]}, {'id': 'rejected', 'cases': [{'code': 0, 'effects': [{'op': 'set', 'target': 'status', 'value': 'unavailable'}]}]}], 'initialAction': 'read'};d['sdkCatalog']=str(db);ios=d['nativeOperations'][0]['implementations']['ios'];ios['steps']=[{'id':'new','bind':'value'}]
   d['nativeOperations'][0]['implementations']['android']['steps'][0].pop('scope')
   source=root/'app.json';source.write_text(json.dumps(d));out=root/'output'
   with self.assertRaisesRegex(ValueError,'availability'):compile_app(source,out,targets=('ios',))
   self.assertFalse(out.exists())
   ios['steps'][0]['id']='old'
   compile_app(source,root/'old-api',targets=('ios',),document=d)
   ios['steps'][0]['id']='new'
   ios['iosVersion']=[18,0]
   with self.assertRaisesRegex(ValueError,'above app deployment'):compile_app(source,out,targets=('ios',),document=d)
   self.assertFalse(out.exists())
   d['nativeConfiguration']={'ios':{'deploymentTarget':[18,0]}}
   compile_app(source,out,targets=('ios',),document=d)
   self.assertIn('IPHONEOS_DEPLOYMENT_TARGET = 18.0',(out/'ios/Native/Logic.xcconfig').read_text())
if __name__=='__main__':unittest.main()
