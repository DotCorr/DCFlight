import json,struct,tempfile,unittest,zipfile,hashlib
from pathlib import Path
from unittest.mock import patch
from dcflight.audit_references import source_reference,dex_references
from dcflight.audit import audit,audit_apk
APP='com.dotcorr.dcflight.deviceqa'
def dex(strings,types=(),classes=()):
 data=bytearray(112+4*len(strings)+4*len(types)+32*len(classes));data[:8]=b'dex\n035\0';so=112;to=so+4*len(strings);co=to+4*len(types)
 struct.pack_into('<II',data,56,len(strings),so);struct.pack_into('<II',data,64,len(types),to);struct.pack_into('<II',data,96,len(classes),co)
 for i,value in enumerate(strings):
  b=value.encode();assert len(b)<128;struct.pack_into('<I',data,so+4*i,len(data));data+=bytes([len(b)])+b+b'\0'
 for i,value in enumerate(types):struct.pack_into('<I',data,to+4*i,value)
 for i,value in enumerate(classes):struct.pack_into('<I',data,co+32*i,value)
 struct.pack_into('<III',data,32,len(data),112,0x12345678);return bytes(data)
class AuditIdentityTests(unittest.TestCase):
 def test_normal_package_import_and_patch_identity(self):
  import dcflight.audit_references as refs
  import dcflight.audit as scanner
  self.assertIs(source_reference,refs.source_reference)
  self.assertIs(dex_references,refs.dex_references)
  self.assertIs(audit,scanner.audit)
  self.assertIs(audit_apk,scanner.audit_apk)
  self.assertIs(dex_references.__globals__,refs.__dict__)
  with patch.object(refs,'MAX_STRINGS',0),self.assertRaises(ValueError):
   dex_references(dex(['ordinary']))

 def test_identity_and_ui_only_data_positions(self):
  cases=[('package '+APP+'; class App {}','.java'),("namespace '"+APP+"'",'.gradle'),('PRODUCT_BUNDLE_IDENTIFIER = '+APP+';', '.pbxproj'),('Text("DCFlight Device QA")','.swift'),('<resources><string name="native_app_name">DCFlight Device QA</string></resources>','.xml')]
  for text,suffix in cases:self.assertFalse(source_reference(text,suffix,APP),text)
 def test_dependency_imports_and_dynamic_strings_stay_rejected(self):
  for text in ['import dcflight','import io.flutter.embedding.Engine',"implementation 'com.example:dcflight:1.0'",'System.loadLibrary("dart")','Class.forName("dcflight.Runtime")','let engine = WKWebView()','import android.webkit.WebView']:
   self.assertTrue(source_reference(text,'.swift',APP),text)
 def test_string_exception_does_not_hide_other_code(self):
  self.assertTrue(source_reference('Text("DCFlight Device QA"); import dcflight','.swift',APP))
  self.assertTrue(source_reference("namespace '"+APP+"'; implementation 'dcflight:runtime:1'",'.gradle',APP))
 def test_interpolated_ui_strings_preserve_executable_references(self):
  for text in [r'Text("label \(DartVM())")','Text("${DartVM()}")',r'Text("label \(FlutterEngine())")','Text("$FlutterEngine")']:
   self.assertTrue(source_reference(text,'.swift',APP),text)
 def test_runtime_class_names_stay_visible_in_self_namespace(self):
  for cls in ['FlutterEngine','DartExecutor','FlutterJNI','ReactNativeHost','HermesExecutor']:
   self.assertTrue(source_reference(APP+'.'+cls+'()','.kt',APP))
   self.assertTrue(dex_references(dex(['L'+APP.replace('.','/')+'/'+cls+';'],[0],[0]),APP)['prohibitedTypes'])
 def test_real_generated_identity_receipt(self):
  with tempfile.TemporaryDirectory() as d:
   r=Path(d);(r/'ios').mkdir();(r/'.dcflight').mkdir();(r/'.dcflight/source.json').write_text(json.dumps({'appId':APP,'targets':{}}));(r/'ios/Node.swift').write_text('Text("DCFlight Device QA")');self.assertTrue(audit(r)['passed']);(r/'ios/Injected.swift').write_text('import dcflight');self.assertFalse(audit(r)['passed'])
 def test_dex_identity_and_prose_not_runtime(self):
  data=dex(['Lcom/dotcorr/dcflight/deviceqa/MainActivity;','DCFlight Device QA'],[0],[0]);r=dex_references(data,APP);self.assertEqual(1,r['definedClasses']);self.assertFalse(r['prohibitedTypes']);self.assertFalse(r['dynamicRuntimeNames']);self.assertTrue(dex_references(data)['prohibitedTypes'])
 def test_dex_types_references_and_dynamic_loads_reject(self):
  for name in ['Ldcflight/Runtime;','Lio/flutter/Engine;','Lcom/facebook/react/Engine;']:
   self.assertTrue(dex_references(dex([name],[0],[]),APP)['prohibitedTypes'],name)
  for name in ['libdart.so','dcflight.Runtime','android.webkit.WebView']:
   self.assertTrue(dex_references(dex([name]),APP)['dynamicRuntimeNames'],name)
  self.assertTrue(dex_references(dex(['Lio/flutter/Engine;'],[0],[0]),'io.flutter')['prohibitedTypes'])
 def test_runtime_namespace_cannot_be_claimed_as_app_identity(self):
  self.assertTrue(dex_references(dex(['Ldcflight/runtime/Engine;'],[0],[0]),'dcflight.runtime')['prohibitedTypes'])
  self.assertTrue(source_reference('import dcflight.runtime.Engine','.java','dcflight.runtime'))
 def test_os_web_types_are_references_not_bundled_engine(self):
  r=dex_references(dex(['Landroid/webkit/WebView;','v8'],[0],[]),APP)
  self.assertFalse(r['prohibitedTypes']);self.assertEqual(['Landroid/webkit/WebView;'],r['platformWebTypeReferences']);self.assertFalse(r['dynamicRuntimeNames'])
  self.assertTrue(dex_references(dex(['Landroid/webkit/WebView;'],[0],[0]),APP)['prohibitedTypes'])
 def test_bad_dex_and_expansion_bounds(self):
  for data in [b'dex\n035\0',dex(['okay'])[:-1],bytes(112)]:
   with self.assertRaises(ValueError):dex_references(data)
  import dcflight.audit_references as refs
  with patch.object(refs,'MAX_STRINGS',0):
   with self.assertRaises(ValueError):dex_references(dex(['okay']))
 def test_apk_library_payload_and_dex_checks(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'app.apk'
   with zipfile.ZipFile(p,'w') as z:z.writestr('classes.dex',dex(['Lcom/dotcorr/dcflight/deviceqa/App;','DCFlight Device QA'],[0],[0]))
   self.assertTrue(audit_apk(p,application_id=APP)['passed'])
   for name,content in [('assets/runtime.dill',b'x'),('assets/ENGINE.JS',b'x'),('lib/arm64-v8a/libdart.so',b'x'),('classes.dex',dex(['dcflight.Runtime']))]:
    with zipfile.ZipFile(p,'w') as z:z.writestr(name,content)
    expected={name:hashlib.sha256(content).hexdigest()} if name.startswith('lib/') else {}
    with self.assertRaises(ValueError):audit_apk(p,expected,application_id=APP)
if __name__=='__main__':unittest.main()
