import unittest
from dataclasses import replace
from dcflight.registry import Registry
from dcflight.validate import lower
from dcflight.navigation_ir import RouteViewportAlignment
from dcflight.backends.ios_routed import generate
from dcflight.backends.android_routed import AndroidRouted


def fixture(style=None):
 body={'id':'body','type':'column','props':{},'children':[{'id':'text','type':'text','props':{'text':'Hello'}}]}
 if style is not None:body['style']=style
 return {'version':2,'id':'com.example.viewport','name':'Viewport','root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Home','body':body}]}

class RouteViewportTests(unittest.TestCase):
 def outputs(self,data):
  app=lower(data,Registry());ios=generate(app,Registry());android=AndroidRouted().generate(app,Registry())
  swift=ios['ios/App/Generated/RouteContent.swift'].content
  kotlin=next(a.content for name,a in android.items() if name.endswith('AuthoredApplication.kt'))
  return app,ios,swift,kotlin
 def test_default_viewport_is_typed_and_matches_native_emitters(self):
  app,ios,swift,kotlin=self.outputs(fixture())
  self.assertIs(app.routes[0].viewport_alignment,RouteViewportAlignment.TOP_START)
  with self.assertRaisesRegex(ValueError,'canonical RouteViewportAlignment'):replace(app.routes[0],viewport_alignment='topStart')
  self.assertIn('n_body(model: model).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)',swift)
  self.assertIn('Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding), contentAlignment=Alignment.TopStart)',kotlin)
 def test_authored_root_geometry_and_cross_axis_alignment_remain_on_node(self):
  app,ios,swift,kotlin=self.outputs(fixture({'width':180,'height':120,'align':'center','padding':8}))
  node=ios['ios/App/Generated/Nodes/n_body.swift'].content
  self.assertIn('.frame(width: 180, height: 120, alignment: .center)',node)
  self.assertIn('VStack(alignment: .center',node)
  self.assertNotIn('maxHeight: .infinity',node)
  self.assertIn('.width(180.dp).height(120.dp)',kotlin)
  self.assertIn('horizontalAlignment=Alignment.CenterHorizontally',kotlin)
  self.assertIn('.padding(8.dp)',kotlin)
 def test_root_placement_does_not_change_intrinsic_nested_columns(self):
  data=fixture();data['routes'][0]['body']['children']=[{'id':'nested','type':'column','props':{},'children':[{'id':'text','type':'text','props':{'text':'Hello'}}]}]
  app,ios,swift,kotlin=self.outputs(data)
  for name in ('body','nested'):
   text=ios['ios/App/Generated/Nodes/n_'+name+'.swift'].content
   self.assertIn('VStack(alignment: .leading, spacing: 0)',text)
   self.assertNotIn('maxHeight: .infinity',text)
  self.assertEqual(swift.count('maxHeight: .infinity'),1)
