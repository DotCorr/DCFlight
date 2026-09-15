import unittest
from dcflight.ir import Node,Motion,Literal,ScalarType,Reference
from dcflight.backends.android_motion import wrap

class AndroidMotionTests(unittest.TestCase):
 def test_declared_motion_duration_and_visibility_reach_native_transition(self):
  for kind,expected in [('fade','fadeIn'),('slide','slideInVertically'),('scale','scaleIn')]:
   node=Node('panel','text',(),(),motion=Motion(kind,320),visible_when=Reference('shown',ScalarType.BOOL))
   source=wrap(node,'Text("Shared content")',lambda _: 'model.s_shown')
   self.assertIn('motionState.targetState = model.s_shown',source)
   self.assertIn('core.tween(320)',source)
   self.assertIn(expected,source)
   self.assertIn('Text("Shared content")',source)
 def test_absent_motion_keeps_immediate_visibility(self):
  node=Node('panel','text',(),(),visible_when=Reference('shown',ScalarType.BOOL))
  self.assertEqual(wrap(node,'Text("x")',lambda _: 'model.s_shown'),'if(model.s_shown) { Text("x") }')
 def test_invalid_motion_fails_closed(self):
  with self.assertRaises(ValueError):wrap(Node('panel','text',(),(),motion=Motion('spin',100)),'Text("x")',str)
