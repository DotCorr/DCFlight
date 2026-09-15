import unittest
from dcflight.platforms.android_api import AndroidAPI
from dcflight.android_generic_invocation import requirements,WitnessPlanner
SDK='''package nativeproof {
 public interface Owner<T, U, S extends nativeproof.Owner<T, U, S>> {
  method public T read();
 }
 public final class Concrete implements nativeproof.Owner<java.lang.String, java.lang.Integer, nativeproof.Concrete> {
 }
 public class Generic<T extends java.lang.Number> {
  method public <T extends java.lang.CharSequence> T convert(T);
 }
}'''
class GenericRequirementTests(unittest.TestCase):
 def test_discovery_retains_scopes_bounds_and_unbound_credit(self):
  api=AndroidAPI(SDK);m=api.get('nativeproof.Generic#convert(T)');info=requirements(api,m)
  self.assertEqual(info['ownerParameters'][0],{'name':'T','scope':'owner','bounds':['java.lang.Number']})
  self.assertEqual(info['callableParameters'][0],{'name':'T','scope':'method','bounds':['java.lang.CharSequence']})
  self.assertEqual(info['inputFields']['typeArguments']['parametersInOrder'],['T'])
  record=next(x for x in api.records() if x['id']==m.id);self.assertFalse(record['emittable']);self.assertFalse(record['nativeTested']);self.assertFalse(record['invocationRequirements']['nativeVerified'])
 def test_constraint_witness_unifies_actual_inherited_arguments(self):
  api=AndroidAPI(SDK);planner=WitnessPlanner(api);request=planner.request('nativeproof.Owner#read()','test')
  self.assertEqual(request['receiver']['type'],'nativeproof.Owner<java.lang.String, java.lang.Integer, nativeproof.Concrete>')
  m=api.resolve_member(request['id'],receiver_type=request['receiver']['type']);self.assertEqual(m.java_type,'java.lang.String')
 def test_budget_exhaustion_is_explicit(self):
  with self.assertRaisesRegex(ValueError,'budget'):WitnessPlanner(AndroidAPI(SDK),max_trials=1).request('nativeproof.Owner#read()','test')
 def test_witness_pool_rejects_inaccessible_enclosing_owner(self):
  sdk='''package nativeproof {
 class Hidden {
 }
 public static class Hidden.Child {
 }
 public class Visible {
 }
 public static class Visible.Child {
 }
 public static class Missing.Child {
 }
}'''
  planner=WitnessPlanner(AndroidAPI(sdk))
  self.assertNotIn('nativeproof.Hidden.Child',planner.pool)
  self.assertNotIn('nativeproof.Missing.Child',planner.pool)
  self.assertIn('nativeproof.Visible.Child',planner.pool)
