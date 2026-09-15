import unittest
from dataclasses import replace
from test_android_flow import flow_fixture,lit
from dcflight.ir import Node,MediaRef
from dcflight.media_ir import MediaState,PhotoOptions,PickPhotoEffect,ClearMediaEffect,MediaBody,MediaProjection
from dcflight.flow_ir import FlowAction,FlowCase
from dcflight.backends.android_routed import AndroidRouted

def fixture():
 app=flow_fixture();photo=MediaRef('photo')
 request=replace(app.flow_actions[0].cases[0].effects[0],body=MediaBody(photo))
 pick=FlowAction('pick',None,(),(FlowCase(0,(PickPhotoEffect('photo',PhotoOptions(),'success','failure','failure'),)),))
 clear=FlowAction('clear',None,(),(FlowCase(0,(ClearMediaEffect('photo'),)),))
 image=Node('image','localImage',(('source',photo),('fit',lit('fit')),('accessibilityLabel',lit('Authored image'))),(Node('loading','text',(('text',lit('Authored loading')),),()),Node('failed','text',(('text',lit('Authored failure')),),())))
 return replace(app,media_states=(MediaState('photo'),),flow_actions=(replace(app.flow_actions[0],cases=(FlowCase(0,(request,)),)),)+app.flow_actions[1:]+(pick,clear),routes=(replace(app.routes[0],body=image),app.routes[1]))

class AndroidMediaTests(unittest.TestCase):
 def test_native_media_and_authored_composition(self):
  app=fixture();files=AndroidRouted().generate(app,None);source=files['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
  adapter=files['android/app/src/main/java/com/example/routes/NativeMedia.kt'].content
  transport=files['android/app/src/main/java/com/example/routes/NativeEffects.kt'].content
  self.assertIn('PickVisualMedia.ImageOnly',source)
  self.assertIn('m_photo by mutableStateOf<NativePhoto?>(null)',source)
  self.assertIn('media.clear("photo"); m_photo = null',source)
  self.assertIn('NativePhotoOptions(2048,85,33554432,8388608,20000000)',source)
  self.assertIn('if(body is NativePhoto)body.bytes',transport)
  self.assertIn('"image/jpeg"',transport)
  self.assertIn('Authored image',source);self.assertNotIn('Authored image',adapter)
  for token in ('maxDecodedPixels','ExifInterface','maxOutputBytes','generation.get()','context.contentResolver','launched!=null') :self.assertIn(token,adapter)
 def test_typed_metadata_projection(self):
  from dcflight.backends.android_flow import AndroidFlow
  from dcflight.backends.android_routed import quoted
  flow=AndroidFlow(fixture(),quoted)
  self.assertEqual('(m_photo?.bytes?.size ?: 0)',flow.expression(MediaProjection('mediaBytes',MediaRef('photo'))))
  self.assertEqual('(m_photo != null)',flow.expression(MediaProjection('hasMedia',MediaRef('photo'))))
 def test_origin_host_bridge_is_bound_and_detached(self):
  source=AndroidRouted().generate(fixture(),None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
  self.assertIn('model.navigationPort("stack")',source)
  self.assertIn('navigationPort.detach(',source)
  self.assertIn('isChangingConfigurations',source)
  self.assertIn('if(navigate is NativeNavigationPort && !navigate.alive) return@request',source)
  self.assertIn('if(navigate is NativeNavigationPort && !navigate.alive) return@pick',source)

 def test_media_motion_and_readonly_media_keep_native_model(self):
  from dcflight.ir import Motion
  app=fixture();app=replace(app,routes=(replace(app.routes[0],body=replace(app.routes[0].body,motion=Motion('scale',160))),app.routes[1]))
  source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
  self.assertIn('androidx.compose.animation.AnimatedVisibility',source)
  self.assertIn('tween(160)',source)
  empty=replace(fixture(),flow_actions=(),initial_action=None)
  source=AndroidRouted().generate(empty,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
  self.assertIn('val media=NativeMedia(context)',source)
  self.assertIn('androidx.lifecycle.ViewModel()',source)
