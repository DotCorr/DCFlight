import base64
from dataclasses import FrozenInstanceError, asdict
import json
import importlib.util
from pathlib import Path
import plistlib
import sys
import unittest
import xml.etree.ElementTree as ET

from dcflight import native_configuration as nc

class ConfigurationIRTests(unittest.TestCase):
 def test_extension_namespaces(self):
  uri='http://schemas.android.com/apk/distribution'
  raw={'android':{'namespaces':{'dist':uri},'manifest':{'tag':'manifest','children':[{'tag':'dist:module','attributes':{'dist:instant':'false'},'children':[{'tag':'dist:delivery','children':[{'tag':'dist:install-time'}]}]}]}}}
  parsed=nc.lower_native_configuration(raw)
  self.assertEqual(tuple(sorted({**nc.NAMESPACES,'dist':uri}.items())),parsed.android_namespaces)
  xml=ET.tostring(nc.manifest_xml(parsed.android_manifest,parsed.android_namespaces))
  node=ET.fromstring(xml)[0]
  self.assertEqual('{'+uri+'}module',node.tag)
  self.assertEqual('false',node.get('{'+uri+'}instant'))
  import jsonschema
  jsonschema.validate(raw,nc.schema())
  for namespaces in [{},{'android':'urn:changed'},{'xml':'urn:custom'},{'xmlns':'urn:custom'},{'dist':'relative'},{'dist':'urn:space here'}]:
   with self.subTest(namespaces=namespaces),self.assertRaises(ValueError):nc.lower_native_configuration({'android':{**raw['android'],'namespaces':namespaces}})
  with self.assertRaisesRegex(ValueError,'unbound'):nc.lower_native_configuration({'android':{'manifest':{'tag':'manifest','attributes':{'dist:instant':'false'}}}})
 def test_plist_all_types_roundtrip_and_freeze(self):
  raw={'ios':{'infoPlist':{k:{'type':k,'value':v} for k,v in {'string':'hello <world>','integer':-9223372036854775808,'real':1.25,'boolean':True,'data':'AQID','date':'2026-09-14T00:00:00Z','array':[{'type':'integer','value':1}],'dictionary':{'child':{'type':'boolean','value':False}}}.items()}}}
  parsed=nc.lower_native_configuration(raw)
  receipt=json.loads(json.dumps(asdict(parsed),sort_keys=True,allow_nan=False))
  self.assertEqual('AQID',dict(parsed.ios_info_plist)['data'].value)
  self.assertEqual('2026-09-14T00:00:00Z',dict(parsed.ios_info_plist)['date'].value)
  values=nc.plist_dict(parsed.ios_info_plist)
  self.assertEqual(values,plistlib.loads(plistlib.dumps(values)))
  self.assertEqual(b'\x01\x02\x03',values['data'])
  with self.assertRaises(FrozenInstanceError): parsed.android_manifest=None
  raw['ios']['infoPlist']['array']['value'].append({'type':'integer','value':2})
  self.assertEqual([1],nc.plist_dict(parsed.ios_info_plist)['array'])
 def test_manifest_namespaces_and_escaping(self):
  raw={'android':{'sourceSets':['debug','release','freeRelease'],'manifest':{'tag':'manifest','children':[{'tag':'application','attributes':{'android:label':'a < b & c','tools:replace':'android:label'},'children':[{'tag':'meta-data','attributes':{'android:name':'a','android:value':'x'}}]}]}}}
  parsed=nc.lower_native_configuration(raw)
  xml=ET.tostring(nc.manifest_xml(parsed.android_manifest))
  again=ET.fromstring(xml)
  self.assertEqual('a < b & c',again[0].get('{'+nc.ANDROID_NAMESPACE+'}label'))
  self.assertEqual(('debug','release','freeRelease'),parsed.android_source_sets)
 def test_invalid_scalar_types(self):
  for kind,value in [('boolean',1),('integer',True),('integer',2**63),('real',float('inf')),('real',True),('data','AB=='),('data','a\n'),('date','2026-02-30T00:00:00Z'),('date','2026-01-01T00:00:00+01:00'),('string','\x00'),('string','\ud800'),('string','x'*1048577)]:
   with self.subTest(kind=kind,value=str(value)[:20]),self.assertRaises(ValueError):nc.lower_native_configuration({'ios':{'infoPlist':{'key':{'type':kind,'value':value}}}})
 def test_malformed_shapes(self):
  for raw in [None,[],{'other':{}},{'ios':{'unknown':{}}},{'android':{'manifest':{'tag':'application'}}},{'ios':{'infoPlist':{'key':{'type':'string','value':'a','extra':1}}}}]:
   with self.subTest(raw=raw),self.assertRaises(ValueError):nc.lower_native_configuration(raw)
 def test_xml_injection_and_names(self):
  for key in ['xmlns','xmlns:android','other:name','android:a:b','a b','><x','{a}b']:
   with self.subTest(key=key),self.assertRaises(ValueError):nc.lower_native_configuration({'android':{'manifest':{'tag':'manifest','attributes':{key:'x'}}}})
  for tag in ['a:b','a b','!DOCTYPE','x/><script','xmlThing']:
   with self.subTest(tag=tag),self.assertRaises(ValueError):nc.lower_native_configuration({'android':{'manifest':{'tag':'manifest','children':[{'tag':tag}]}}})
 def test_limits(self):
  deep={'type':'string','value':'x'}
  for _ in range(33):deep={'type':'array','value':[deep]}
  with self.assertRaisesRegex(ValueError,'depth'):nc.lower_native_configuration({'ios':{'infoPlist':{'key':deep}}})
  with self.assertRaisesRegex(ValueError,'node count'):nc.lower_native_configuration({'ios':{'infoPlist':{'key':{'type':'array','value':[{'type':'boolean','value':True}]*10000}}}})
 def test_source_sets(self):
  self.assertEqual(('debug','release'),nc.lower_native_configuration({}).android_source_sets)
  for names in [[],['main'],['androidTest'],['test'],['debug','debug'],['../escape'],None]:
   with self.subTest(names=names),self.assertRaises(ValueError):nc.lower_native_configuration({'android':{'sourceSets':names}})
 def test_schema(self):
  import jsonschema
  schema=nc.schema();jsonschema.Draft202012Validator.check_schema(schema)
  for raw in [{},{'ios':{'entitlements':{'com.apple.example':{'type':'array','value':[{'type':'string','value':'hello'}]}}}},{'android':{'manifest':{'tag':'manifest','children':[{'tag':'uses-permission','attributes':{'android:name':'android.permission.CAMERA'}}]}}}]:jsonschema.validate(raw,schema)
  for raw in [None,{'android':{'sourceSets':['main']}},{'ios':{'infoPlist':{'x':{'type':'unknown','value':1}}}}]:
   with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(raw,schema)

if __name__=='__main__':unittest.main()
