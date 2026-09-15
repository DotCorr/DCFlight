import unittest
from dataclasses import replace
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.backends.ios_routed import generate
from dcflight.media_ir import MediaState

def app():
 return lower({'version':2,'id':'com.example.observation','name':'Observation','state':{'name':''},'root':{'id':'tabs','type':'tabs','props':{},'children':[{'id':'tab','type':'tab','props':{'title':'Home','icon':'chat'},'children':[{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}}]}]},'routes':[{'id':'home','title':'Home','body':{'id':'field','type':'textField','props':{'placeholder':'Name','value':{'ref':'name'}}}}]},Registry())

def doc_with(body,actions=None):
 return {'version':2,'id':'com.example.observation','name':'Observation','state':{'name':''},
  'root':{'id':'tabs','type':'tabs','props':{},'children':[{'id':'tab','type':'tab','props':{'title':'Home','icon':'chat'},'children':[{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}}]}]},
  'routes':[{'id':'home','title':'Home','body':body}],'actions':actions or [],
  'navigationActions':[{'id':'back','op':'back'}]}

class ObservationOwnershipTests(unittest.TestCase):
 def test_static_navigation_passes_model_without_subscribing_to_every_edit(self):
  files=generate(app(),Registry())
  for relative in ['RootView.swift','RouteContent.swift','NavigationRouter.swift','Nodes/n_tabs.swift','Nodes/n_tab.swift','Nodes/n_stack.swift']:
   source=files['ios/App/Generated/'+relative].content
   self.assertIn('let model: AppModel',source)
   self.assertNotIn('@ObservedObject var model',source)
  self.assertIn('@StateObject private var router',files['ios/App/Generated/NavigationRouter.swift'].content)
  self.assertIn('@State private var selection',files['ios/App/Generated/Nodes/n_tabs.swift'].content)
 def test_bound_leaf_keeps_shared_model_observation(self):
  source=generate(app(),Registry())['ios/App/Generated/Nodes/n_field.swift'].content
  self.assertIn('@ObservedObject var model: AppModel',source)
  self.assertIn('text: $model.s_name',source)
 def test_root_media_presenter_still_observes_its_request(self):
  source=generate(replace(app(),media_states=(MediaState('photo'),)),Registry())['ios/App/Generated/RootView.swift'].content
  self.assertIn('@ObservedObject var model: AppModel',source)
  self.assertIn('NativePhotoPresenter(request: model.nativePhotoRequest)',source)
 def test_leaf_observation_follows_dataflow_not_node_kind(self):
  files=generate(lower(doc_with({'id':'col','type':'column','props':{},'children':[
   {'id':'label','type':'text','props':{'text':'Static heading'}},
   {'id':'field','type':'textField','props':{'placeholder':'Name','value':{'ref':'name'}}},
   {'id':'open','type':'button','props':{'text':'Back'},'action':'back'}]}),Registry()),Registry())
  label=files['ios/App/Generated/Nodes/n_label.swift'].content
  self.assertIn('let model: AppModel',label)
  self.assertNotIn('@ObservedObject',label)
  self.assertIn('@ObservedObject var model: AppModel',files['ios/App/Generated/Nodes/n_field.swift'].content)
  button=files['ios/App/Generated/Nodes/n_open.swift'].content
  self.assertIn('let model: AppModel',button)
  self.assertNotIn('@ObservedObject',button)
  self.assertIn('router.a_back',button)
 def test_logic_action_button_keeps_observation(self):
  files=generate(lower(doc_with({'id':'save','type':'button','props':{'text':'Save'},'action':'saveName'},
   actions=[{'id':'saveName','op':'set','target':'name','value':{'ref':'name'}}]),Registry()),Registry())
  source=files['ios/App/Generated/Nodes/n_save.swift'].content
  self.assertIn('@ObservedObject var model: AppModel',source)
  self.assertIn('model.a_saveName',source)
