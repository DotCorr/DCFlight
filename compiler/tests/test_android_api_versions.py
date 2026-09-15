import unittest
from dcflight.android_api_versions import APIVersions

def xml(body):return ('<api version="3">'+body+'</api>').encode()
class APIVersionsTests(unittest.TestCase):
 def test_exact_full_descriptor_and_nested_owner(self):
  a=APIVersions(xml('<class name="a/Outer$Inner" since="8"><method name="run(I)Ljava/lang/String;" since="12"/><method name="run(J)Ljava/lang/String;" since="15"/></class>'))
  identity=dict(owner='a/Outer$Inner',kind='method',name='run',descriptor='(I)Ljava/lang/String;')
  self.assertEqual(a.lookup(**identity)['minimumApi'],12)
  self.assertIsNone(a.lookup(**{**identity,'descriptor':'(I)Ljava/lang/Object;'}))
  self.assertIsNone(a.lookup(**{**identity,'owner':'a/Outer/Inner'}))
  with self.assertRaisesRegex(ValueError,'introduced'):a.check_base_level(identity,11)
  self.assertIsNone(a.check_base_level(identity,12)['runtimeSupported'])
 def test_inherited_class_since_and_removed_bound(self):
  a=APIVersions(xml('<class name="a/C" since="10" removed="20" deprecated="18"><method name="run()V" removed="17"/></class>'))
  identity=dict(owner='a/C',kind='method',name='run',descriptor='()V');facts=a.lookup(**identity)
  self.assertEqual(facts['minimumApi'],10);self.assertEqual(facts['removedApi'],17)
  self.assertIsNone(facts['memberFacts']['since']);self.assertEqual(facts['classFacts']['deprecated'],18)
  a.check_base_level(identity,16)
  with self.assertRaisesRegex(ValueError,'removed'):a.check_base_level(identity,17)
 def test_unknown_stays_unknown(self):
  a=APIVersions(xml('<class name="a/C"><field name="value"/></class>'));identity=dict(owner='a/C',kind='field',name='value',descriptor='I');f=a.lookup(**identity)
  self.assertIsNone(f['minimumApi'])
  for key in ('permissions','flags','threadRequirement','nullability','runtimeSupported'):self.assertIsNone(f[key])
  with self.assertRaisesRegex(ValueError,'Unknown minimum'):a.check_base_level(identity,36)
 def test_extensions_preserved_without_general_runtime_claim(self):
  a=APIVersions(xml('<class name="a/C" module="framework-adservices" since="34" sdks="1000000:4,0:34"><field name="value"/></class>'))
  f=a.lookup('a/C','field','value','I');self.assertEqual(f['classFacts']['sdks'],((0,34),(1000000,4)));self.assertIsNone(f['runtimeSupported'])
 def test_reject_duplicate_decimal_unknown_schema_entities(self):
  values=[b'<api version="4"/>',xml('<class name="a/C" since="36.1"/>'),xml('<class name="a/C" since="0"/>'),xml('<class name="a/C"/><class name="a/C"/>'),xml('<class name="a/C"><field name="x"/><field name="x"/></class>'),b'<!DOCTYPE api [<!ENTITY x "y">]><api version="3"/>']
  for value in values:
   with self.subTest(value=value),self.assertRaises(ValueError):APIVersions(value)
 def test_invalid_jvm_descriptors_reject(self):
  a=APIVersions(xml('<class name="a/C"/>'))
  for desc in ('(V)V','()Igarbage','(Ljava.lang.String;)V','()','['*256+'I','()L;'):
   with self.subTest(desc=desc),self.assertRaises(ValueError):a.lookup('a/C','method','run',desc)

class JVMImportTests(unittest.TestCase):
 def test_real_generic_and_nested_descriptor_binding(self):
  import os,shutil,subprocess,tempfile,zipfile
  from pathlib import Path
  from dcflight.modules.export import index_android_sdk
  from dcflight.catalog import Catalog
  home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac');javap=str(Path(home)/'bin/javap') if home else shutil.which('javap')
  if not javac or not javap:self.skipTest('Configure JAVA_HOME or javac/javap')
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);src=root/'fixture/Owner.java';src.parent.mkdir();src.write_text('package fixture;public class Owner<T>{public T echo(T x){return x;}public static class Nested{public static int value;}}')
   subprocess.run([javac,'--release','8',str(src)],check=True,capture_output=True,timeout=30)
   jar=root/'android.jar'
   with zipfile.ZipFile(jar,'w') as z:
    for p in root.rglob('*.class'):z.write(p,str(p.relative_to(root)))
   (root/'source.properties').write_text('AndroidVersion.ApiLevel=36\nAndroidVersion.IsBaseSdk=true\n')
   xmlpath=root/'api-versions.xml';xmlpath.write_bytes(xml('<class name="fixture/Owner" since="8"><method name="echo(Ljava/lang/Object;)Ljava/lang/Object;" since="12"/></class><class name="fixture/Owner$Nested" since="9"><field name="value" since="15"/></class>'))
   db=root/'catalog.sqlite';result=index_android_sdk(jar,db,javap=javap,api_versions=xmlpath)
   self.assertEqual(result['provenance']['availabilityExactMatches'],2)
   with Catalog(db) as c:
    generic=c.get('android','fixture.Owner#echo(T)','sdk-bytecode:36')['api'];field=c.get('android','fixture.Owner.Nested#value','sdk-bytecode:36')['api']
   self.assertEqual(generic['availability']['jvmIdentity']['descriptor'],'(Ljava/lang/Object;)Ljava/lang/Object;');self.assertEqual(generic['availability']['minimumApi'],12)
   self.assertEqual(field['availability']['jvmIdentity']['owner'],'fixture/Owner$Nested');self.assertEqual(field['availability']['minimumApi'],15)
   snap=root/result['provenance']['availabilityXml']['sourceRelativePath'];self.assertEqual(snap.read_bytes(),xmlpath.read_bytes())
 def test_cli_explicit_xml_path(self):
  import contextlib,io
  from unittest.mock import patch
  from dcflight.cli import main
  with patch('dcflight.modules.export.index_android_sdk',return_value={}) as call,contextlib.redirect_stdout(io.StringIO()):main(['sdk','index-android-sdk','sdk/android.jar','--catalog','new.sqlite','--api-versions','sdk/data/api-versions.xml'])
  self.assertEqual(call.call_args.kwargs['api_versions'],'sdk/data/api-versions.xml')
 def test_xml_reader_rejects_nonregular_and_oversized_input(self):
  import os,tempfile
  from pathlib import Path
  from unittest.mock import patch
  from dcflight import android_api_versions as module
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);fifo=root/'fifo';os.mkfifo(fifo)
   with self.assertRaisesRegex(ValueError,'regular'):module.read_api_versions(fifo)
   path=root/'xml';path.write_bytes(b'12345')
   with patch.object(module,'MAX_BYTES',4),self.assertRaisesRegex(ValueError,'bounded'):module.read_api_versions(path)
   self.assertEqual(module.read_api_versions(path),b'12345')
 def test_parser_counts_nodes_and_depth_during_feeding(self):
  from unittest.mock import patch
  from dcflight import android_api_versions as module
  real=module.ET.XMLPullParser;feeds=[]
  class TrackingParser:
   def __init__(self,*a,**kw):self.parser=real(*a,**kw)
   def feed(self,text):feeds.append(len(text));return self.parser.feed(text)
   def read_events(self):return self.parser.read_events()
   def close(self):return self.parser.close()
  data=xml(''.join('<class name="a/C'+str(n)+'"/>' for n in range(10000)))
  with patch.object(module,'MAX_NODES',5),patch.object(module.ET,'XMLPullParser',TrackingParser),self.assertRaisesRegex(ValueError,'node bound'):APIVersions(data)
  self.assertEqual(len(feeds),1);self.assertLessEqual(sum(feeds),4096)
  with self.assertRaisesRegex(ValueError,'depth bound'):APIVersions(xml('<class name="a/C"><method name="run()V"><field name="nested"/></method></class>'))
 def test_extension_attribute_bound_before_pair_expansion(self):
  with self.assertRaisesRegex(ValueError,'attribute bound'):APIVersions(xml('<class name="a/C" sdks="'+('1:1,'*10000)+'1:1"/>'))
