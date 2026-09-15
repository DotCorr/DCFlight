import tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from dcflight.native_configuration import lower_native_configuration
from dcflight.android_deployment import finish,gradle_configuration,DIRECTIVE
from dcflight.android_sdk_guard import active_guard_hook
from dcflight.backends import Artifact
from dcflight.validate import Diagnostic,lower
from dcflight.registry import Registry

class AndroidBuildVersionsTests(unittest.TestCase):
 def test_defaults_and_authored_levels(self):
  c=lower_native_configuration({});self.assertEqual((c.android_compile_sdk,c.android_min_sdk,c.android_target_sdk),(35,26,35));self.assertFalse(c.android_validate_native_availability)
  c=lower_native_configuration({'android':{'compileSdk':36,'minSdk':28,'targetSdk':35,'validateNativeAvailability':True}})
  self.assertEqual((c.android_compile_sdk,c.android_min_sdk,c.android_target_sdk),(36,28,35));self.assertTrue(c.android_validate_native_availability)
 def test_invalid_versions_reject_before_generation(self):
  for field in ('compileSdk','minSdk','targetSdk'):
   for value in (True,False,0,-1,1000,36.1,'36',None,[36,1]):
    with self.subTest(field=field,value=value),self.assertRaises(Diagnostic):lower_native_configuration({'android':{field:value}})
  for value in ({'minSdk':25},{'compileSdk':35,'targetSdk':36},{'minSdk':36,'targetSdk':35},{'validateNativeAvailability':1}):
   with self.subTest(value=value),self.assertRaises(Diagnostic):lower_native_configuration({'android':value})
 def test_hooks_cannot_substitute_or_hide_each_other(self):
  self.assertTrue(active_guard_hook(DIRECTIVE,filename='native-versions.gradle'))
  self.assertFalse(active_guard_hook(DIRECTIVE))
  for source in ("// "+DIRECTIVE,"if (false) {\n"+DIRECTIVE+'\n}',"def text = \""+DIRECTIVE+'\"',"apply from: 'verified-android-sdk.gradle'",'if (false)\n'+DIRECTIVE):
   with self.subTest(source=source):self.assertFalse(active_guard_hook(source,filename='native-versions.gradle'))
 def test_both_backend_templates_bind_same_configuration(self):
  from dcflight.backends.android import Android
  from dcflight.backends.android_routed import AndroidRouted
  registry=Registry()
  docs=[({'version':1,'id':'com.example.versions','name':'Versions','root':{'id':'text','type':'text','props':{'text':'Hello'}}},Android()),({'version':2,'id':'com.example.versions','name':'Versions','root':{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Home','body':{'id':'text','type':'text','props':{'text':'Hello'}}}]},AndroidRouted())]
  with tempfile.TemporaryDirectory() as tmp:
   for doc,backend in docs:
    doc['nativeConfiguration']={'android':{'compileSdk':36,'minSdk':28,'targetSdk':36}};app=lower(doc,registry);artifacts=backend.generate(app,registry);finish(app,artifacts,Path(tmp))
    self.assertTrue(active_guard_hook(artifacts['android/app/build.gradle'].content,filename='native-versions.gradle'))
    self.assertEqual(artifacts['android/app/native-versions.gradle'].content,gradle_configuration(app.native_configuration))
 def test_user_project_is_preserved_and_missing_binding_rejects(self):
  app=SimpleNamespace(native_configuration=lower_native_configuration({'android':{'compileSdk':36}}))
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);p=root/'android/app/build.gradle';p.parent.mkdir(parents=True);p.write_text('// user-owned\n'+DIRECTIVE+'\n')
   before=p.read_bytes();artifacts={'android/app/build.gradle':Artifact(DIRECTIVE,'user')};finish(app,artifacts,root);self.assertEqual(p.read_bytes(),before)
   p.write_text('// user-owned without hook\n');before=p.read_bytes()
   with self.assertRaisesRegex(Diagnostic,'top-level'):finish(app,artifacts,root)
   self.assertEqual(p.read_bytes(),before)

class AndroidBuildVersionsDartTests(unittest.TestCase):
 def test_dart_configuration_and_operation_json(self):
  import json,os,shutil,subprocess
  dart=shutil.which('dart')
  if dart is None:self.skipTest('Dart SDK required')
  library=os.environ.get('DCFLIGHT_TEST_AUTHORING_LIBRARY',str(Path(__file__).resolve().parents[1]/'authoring/lib/dcflight.dart'))
  with tempfile.TemporaryDirectory() as tmp:
   source=Path(tmp)/'main.dart';source.write_text("import 'dart:convert';\nimport '"+Path(library).as_uri()+"';\nvoid main(){print(jsonEncode([const AndroidConfiguration(compileSdk:36,minSdk:28,targetSdk:36,validateNativeAvailability:true).toJson(),const NativeImplementation(steps:[NativeCall('api',bind:'value')],result:NativeRef('value'),androidMinSdk:28,androidCompileSdk:36).toJson()]));}\n")
   result=subprocess.run([dart,str(source)],capture_output=True,text=True,check=True,timeout=60);config,operation=json.loads(result.stdout)
   ir=lower_native_configuration({'android':config});self.assertEqual((ir.android_compile_sdk,ir.android_min_sdk,ir.android_target_sdk),(36,28,36));self.assertTrue(ir.android_validate_native_availability)
   self.assertEqual(operation,{'steps':[{'id':'api','bind':'value'}],'return':{'ref':'value'},'androidMinSdk':28,'androidCompileSdk':36})
