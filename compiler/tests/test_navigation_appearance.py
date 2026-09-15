import copy,json,os,shutil,subprocess,tempfile,unittest
from pathlib import Path
from dataclasses import FrozenInstanceError,asdict
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.navigation_ir import schema
from dcflight.navigation_appearance import NavigationAppearance,TabAppearance
from dcflight.backends.ios_routed import generate
from dcflight.backends.android_routed import AndroidRouted


def fixture():
 return {'version':2,'id':'com.example.appearance','name':'Appearance','root':{'id':'tabs','type':'tabs','props':{},'appearance':{'selectedForeground':'#A73522','unselectedForeground':'#4E5965','surface':'#FFF4E8'},'children':[
  {'id':'homeTab','type':'tab','props':{'title':'Home','icon':'chat'},'children':[{'id':'homeStack','type':'navigationStack','props':{'initialRoute':'home'},'appearance':{'accent':'#A73522','surface':'#FFF4E8'}}]},
  {'id':'profileTab','type':'tab','props':{'title':'Profile','icon':'user'},'children':[{'id':'profileStack','type':'navigationStack','props':{'initialRoute':'profile'},'appearance':{'accent':'#224499','surface':'#F1F2F3'}}]}]},
  'routes':[{'id':'home','title':'Home','body':{'id':'hello','type':'text','props':{'text':'Hello'}}},{'id':'profile','title':'Profile','body':{'id':'world','type':'text','props':{'text':'World'}}}]}

class NavigationAppearanceTests(unittest.TestCase):
 def test_typed_ir_and_schema(self):
  import jsonschema
  data=fixture();jsonschema.validate(data,schema(Registry()));app=lower(data,Registry())
  self.assertEqual(app.root.navigation_appearance,TabAppearance('#A73522','#4E5965','#FFF4E8'))
  self.assertEqual(app.root.children[0].children[0].navigation_appearance,NavigationAppearance('#A73522','#FFF4E8'))
  with self.assertRaises(FrozenInstanceError):app.root.navigation_appearance.surface='#FFFFFF'
  json.dumps(asdict(app))
 def test_reject_unsupported_fields_values_and_hosts(self):
  import jsonschema
  for appearance in ({'fontSize':20},{'surface':None},{'surface':'red'},{'accent':'#000000'}):
   data=fixture();data['root']['appearance']=appearance
   with self.assertRaises(ValueError):lower(data,Registry())
   with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(data,schema(Registry()))
  for key,value in [('style',{'background':'#112233'}),('motion',{'kind':'fade','durationMs':100})]:
   data=fixture();data['root'][key]=value
   with self.assertRaises(ValueError):lower(data,Registry())
  data=fixture();data['root']['children'][0]['appearance']={'surface':'#112233'}
  with self.assertRaises(ValueError):lower(data,Registry())
 def test_native_mapping_is_scoped_and_no_appearance_proxy(self):
  app=lower(fixture(),Registry());ios=generate(app,Registry());android=AndroidRouted().generate(app,Registry());swift='\n'.join(x.content for x in ios.values() if isinstance(x.content,str));kotlin='\n'.join(x.content for x in android.values() if isinstance(x.content,str))
  self.assertIn('UITabBarController()',swift);self.assertIn('coordinator.hosts[item.id]',swift);self.assertIn('host.rootView = content',swift);self.assertIn('context.environment',swift)
  self.assertNotIn('UITabBar.appearance()',swift);self.assertIn('unselectedItemTintColor',swift)
  for phrase in ('selectedIconColor=Color(0xFFA73522)','unselectedTextColor=Color(0xFF4E5965)','NavigationBar(containerColor=Color(0xFFFFF4E8))','Color(0xFF224499), Color(0xFFF1F2F3)'):
   self.assertIn(phrase,kotlin)
 def test_unstyled_tabs_keep_existing_swiftui_host(self):
  data=fixture();del data['root']['appearance'];app=lower(data,Registry());files=generate(app,Registry())
  self.assertNotIn('ios/App/Generated/AuthoredNativeTabs.swift',files)
  self.assertIn('TabView(selection: $selection)',files['ios/App/Generated/Nodes/n_tabs.swift'].content)
 def test_compatibility_design_is_explicit_app_configuration(self):
  import plistlib
  from dcflight.compiler import compile_app
  for explicit in (None,False,True):
   with self.subTest(explicit=explicit), tempfile.TemporaryDirectory() as folder:
    root=Path(folder);data=fixture()
    if explicit is not None:
     data['nativeConfiguration']={'ios':{'infoPlist':{'UIDesignRequiresCompatibility':{'type':'boolean','value':explicit}}}}
    source=root/'app.json';source.write_text(json.dumps(data));output=root/'native'
    compile_app(source,output,targets=('ios',))
    info=plistlib.loads((output/'ios/Native/AppInfo.plist').read_bytes())
    if explicit is None:self.assertNotIn('UIDesignRequiresCompatibility',info)
    else:self.assertIs(info['UIDesignRequiresCompatibility'],explicit)
 def test_empty_and_mixed_host_appearance_never_changes_app_design(self):
  import plistlib
  from dcflight.compiler import compile_app
  for appearance in ({},fixture()['root']['appearance']):
   with self.subTest(appearance=appearance), tempfile.TemporaryDirectory() as folder:
    data=fixture();data['root']['appearance']=appearance
    del data['root']['children'][1]['children'][0]['appearance']
    root=Path(folder);source=root/'app.json';source.write_text(json.dumps(data));output=root/'native'
    compile_app(source,output,targets=('ios',))
    self.assertNotIn('UIDesignRequiresCompatibility',plistlib.loads((output/'ios/Native/AppInfo.plist').read_bytes()))
 def test_evaluated_dart_and_json_share_typed_contract(self):
  from dcflight.evaluated_frontend import load_evaluated
  import jsonschema
  dart=os.environ.get('DCFLIGHT_DART') or shutil.which('dart')
  if not dart:self.skipTest('Dart SDK required')
  root=Path(__file__).resolve().parents[1]
  data=load_evaluated(root/'examples/navigation-appearance/app.dart',dart=dart,authoring=root/'authoring')
  jsonschema.validate(data,schema(Registry()))
  self.assertEqual(data['nativeConfiguration']['ios']['infoPlist']['UIDesignRequiresCompatibility'], {'type':'boolean','value':True})
  expected={'selectedForeground':'#A73522','unselectedForeground':'#4E5965','surface':'#FFF4E8'}
  tabs=next(route['body'] for route in data['routes'] if route['id']=='main')
  self.assertEqual(tabs['appearance'],expected)
  for tab in tabs['children']:self.assertEqual(tab['children'][0]['appearance'],{'accent':'#A73522','surface':'#FFF4E8'})
  self.assertEqual(lower(data,Registry()),lower(json.loads(json.dumps(data)),Registry()))
 def test_canonical_wrong_host_is_rejected_by_both_emitters(self):
  from dataclasses import replace
  app=lower(fixture(),Registry())
  body=replace(app.routes[0].body,navigation_appearance=TabAppearance(surface='#FFFFFF'))
  app=replace(app,routes=(replace(app.routes[0],body=body),app.routes[1]))
  for emitter in (generate,AndroidRouted().generate):
   with self.assertRaisesRegex(ValueError,'Appearance type'):emitter(app,Registry())
 def test_generated_native_host_preserves_source_conflict_boundary(self):
  from dcflight.compiler import compile_app
  from dcflight.sync import Conflict
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);source=root/'app.json';source.write_text(json.dumps(fixture()));output=root/'native'
   compile_app(source,output,targets=('ios',))
   host=output/'ios/App/Generated/AuthoredNativeTabs.swift';original=host.read_text();host.write_text(original+'\n// Developer-owned edit for conflict verification.\n')
   data=fixture();data['root']['appearance']['surface']='#112233'
   with self.assertRaises(Conflict):compile_app(source,output,targets=('ios',),document=data)
   self.assertTrue(host.read_text().endswith('// Developer-owned edit for conflict verification.\n'))
