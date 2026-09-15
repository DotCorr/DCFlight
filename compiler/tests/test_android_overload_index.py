import importlib.util
import sys
import unittest
from dataclasses import asdict
from pathlib import Path

from dcflight.platforms import android_api as module
class ScanningAPI(module.AndroidAPI):
 def _overload_peers(self,member):return self.members.values()
SDK='''package sample {
 public class Box<T> {
  ctor public Box(T);
  ctor public Box(java.lang.String);
  method public T read();
  method public void write(T);
  method public void write(java.lang.String);
  method public static <R> R select(R);
  method public static <R> R[] select(R...);
 }
 public class Packet<T> {
  ctor public <R extends T> Packet(R);
 }
 @FlaggedApi("feature") public class Guarded {
  method public void write(java.lang.String);
 }
 public class Other {
  method public void write(java.lang.String);
  method public int value();
 }
}'''

class OverloadIndexTests(unittest.TestCase):
 def test_index_matches_full_scan_calls_and_errors(self):
  fast=module.AndroidAPI(SDK);slow=ScanningAPI(SDK)
  value=module.JavaValue
  cases=[('sample.Box#<init>(T)',[value.literal('hi')],None,{'constructed_type':'sample.Box<java.lang.String>'}),
         ('sample.Box#write(T)',[value.literal('hi')],value.reference('box','sample.Box<java.lang.String>'),{}),
         ('sample.Box#read()',[],value.reference('box','sample.Box<java.lang.String>'),{}),
         ('sample.Box#select(R)',[value.literal('hi')],None,{'type_arguments':['java.lang.String']}),
         ('sample.Box#select(R)',[value.array(['hi'],'java.lang.String[]')],None,{'type_arguments':['java.lang.String[]']}),
         ('sample.Box#select(R[])',[value.array(['hi'],'java.lang.String[]')],None,{'type_arguments':['java.lang.String']}),
         ('sample.Packet#<init>(R)',[value.literal('hi')],None,{'type_arguments':['java.lang.String'],'constructed_type':'sample.Packet<java.lang.Object>'}),
         ('sample.Guarded#write(java.lang.String)',[value.literal('hi')],value.reference('g','sample.Guarded'),{}),
         ('sample.Other#value()',[],value.reference('o','sample.Other'),{})]
  def outcome(api,case):
   identifier,args,receiver,options=case
   try:return ('value',asdict(api.emit(identifier,args,receiver,**options)))
   except ValueError as error:return ('error',str(error))
  outcomes=[]
  for case in cases:
   with self.subTest(id=case[0],options=case[3]):
    a=outcome(fast,case);self.assertEqual(outcome(slow,case),a);outcomes.append(a[0])
  self.assertIn('error',outcomes);self.assertIn('value',outcomes)
 def test_candidates_are_narrow_and_restrictions_preserved(self):
  api=module.AndroidAPI(SDK)
  member=api.get('sample.Box#write(T)')
  self.assertEqual(['sample.Box#write(T)','sample.Box#write(java.lang.String)'],[m.id for m in api._overload_peers(member)])
  guarded=api.get('sample.Guarded#write(java.lang.String)')
  self.assertEqual(guarded,api._overload_peers(guarded)[0]);self.assertFalse(guarded.emittable)
 def test_members_freeze_after_parse_specialization_does_not_mutate(self):
  api=module.AndroidAPI(SDK);before=dict(api.members)
  with self.assertRaises(TypeError):api.members['new']=api.get('sample.Other#value()')
  with self.assertRaises(TypeError):del api.members['sample.Other#value()']
  api.resolve_member('sample.Box#read()',receiver_type='sample.Box<java.lang.String>')
  self.assertEqual(before,dict(api.members))

if __name__=='__main__':unittest.main()
