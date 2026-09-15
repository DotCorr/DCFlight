import contextlib,io,json,os,shutil,subprocess,sys,tempfile,time,unittest
from pathlib import Path
from dcflight.android_specialization_verification import _read,_capture,_run,verify
from dcflight.native_api import index_android
from dcflight.catalog import Catalog
from dcflight.mcp import Server
SDK='''package java.util {
 public class Collections {
  method public static <T> java.util.List<T> singletonList(T);
 }
}'''
class SpecializationVerifierTests(unittest.TestCase):
 def test_bound_reads_and_snapshot_ownership(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);p=root/'input';p.write_bytes(b'12345')
   with self.assertRaisesRegex(ValueError,'bounded'):_read(p,4,time.monotonic()+2)
   with self.assertRaisesRegex(ValueError,'bounded'):_capture(p,root/'out',4,time.monotonic()+2,root,1)
   fifo=root/'fifo';os.mkfifo(fifo)
   with self.assertRaisesRegex(ValueError,'regular'):_read(fifo,100,time.monotonic()+2)
   linked=root/'linked';linked.symlink_to(p)
   with self.assertRaises(OSError):_read(linked,100,time.monotonic()+2)
 def test_timeout_terminates_descendant_writer(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);marker=root/'ticks';child="import time;from pathlib import Path;p=Path("+repr(str(marker))+");\nwhile True:\n p.write_text(str(time.monotonic()));time.sleep(.02)"
   parent="import subprocess,sys,time;subprocess.Popen([sys.executable,'-c',"+repr(child)+"]);time.sleep(60)"
   with self.assertRaisesRegex(ValueError,'deadline'):_run([sys.executable,'-c',parent],root/'log',time.monotonic()+.3,root,1)
   before=marker.read_bytes();time.sleep(.1);self.assertEqual(marker.read_bytes(),before)
 def test_mcp_describes_typed_arguments_without_execution(self):
  with tempfile.TemporaryDirectory() as folder:
   source=Path(folder)/'sdk';source.write_text(SDK);db=Path(folder)/'catalog';index_android(db,source)
   server=Server(db);server.handle({'jsonrpc':'2.0','id':1,'method':'initialize'})
   response=server.handle({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'sdk_android_invocation_schema','arguments':{}}})['result'];self.assertFalse(response['isError']);schema=json.loads(response['content'][0]['text']);self.assertIn('typeArguments',schema['properties'])
   with Catalog(db) as c:record=c.get('android','java.util.Collections#singletonList(T)')['api']
   self.assertEqual(record['invocationRequirements']['inputFields']['typeArguments']['count'],1);self.assertFalse(record['emittable'])
 def test_native_exact_request_and_rejected_bound_leave_catalog_unchanged(self):
  sdk=os.environ.get('DCFLIGHT_ANDROID_SDK_JAR');home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac')
  if not sdk or not javac:self.skipTest('Configured native Android SDK and JDK required')
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);source=root/'sdk';source.write_text(SDK);db=root/'catalog';index_android(db,source,sdk=35)
   valid={'platform':'android','id':'java.util.Collections#singletonList(T)','typeArguments':['java.lang.String'],'arguments':[{'literal':'native'}]}
   invalid={**valid,'typeArguments':['int']}
   with Catalog(db) as c:before=c.get('android',valid['id'])
   report=verify(db,[valid,invalid],sdk,javac,root/'proof',api_level=35,min_free_mb=1,timeout=60)
   self.assertEqual(report['compiledCount'],1);self.assertFalse(report['passed']);self.assertIn('emissionRejected',report['rows'][1]);self.assertTrue(report['compilerUnchanged'])
   with Catalog(db) as c:self.assertEqual(c.get('android',valid['id']),before)
 def test_callbacks_cannot_relabel_requests_or_captured_sdk(self):
  import hashlib
  sdk=os.environ.get('DCFLIGHT_ANDROID_SDK_JAR');home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac')
  if not sdk or not javac:self.skipTest('Configured native Android SDK and JDK required')
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);source=root/'sdk';source.write_text(SDK);db=root/'catalog';index_android(db,source,sdk=35)
   request={'platform':'android','id':'java.util.Collections#singletonList(T)','typeArguments':['java.lang.String'],'arguments':[{'literal':'original'}]}
   report=verify(db,[request],sdk,javac,root/'frozen',api_level=35,min_free_mb=1,timeout=60,progress=lambda _:request['arguments'][0].update(literal='changed'))
   retained=(root/'frozen/requests.json').read_bytes()
   self.assertTrue(report['passed']);self.assertEqual(report['requestsSHA256'],hashlib.sha256(retained).hexdigest());self.assertEqual(json.loads(retained)[0]['arguments'][0]['literal'],'original')
   with self.assertRaisesRegex(ValueError,'Captured SDK changed'):
    verify(db,[request],sdk,javac,root/'changed',api_level=35,min_free_mb=1,timeout=60,progress=lambda _:(root/'changed/android.jar').write_bytes(b'changed'))
   self.assertFalse((root/'changed/report.json').exists())
 def test_contradictory_base_minor_properties_rejected(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);sdk=root/'android.jar';sdk.write_bytes(b'unused')
   (root/'source.properties').write_text('AndroidVersion.ApiLevel=36\nAndroidVersion.IsBaseSdk=true\nAndroidVersion.ApiLevelMinor=2\n')
   with self.assertRaisesRegex(ValueError,'minor SDKs'):
    verify(root/'absent-catalog',[{'platform':'android','id':'unused'}],sdk,'unused',root/'proof',min_free_mb=1)
 def test_public_cli_plans_then_verifies_exact_calls(self):
  from dcflight.cli import main
  sdk=os.environ.get('DCFLIGHT_ANDROID_SDK_JAR');home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac')
  if not sdk or not javac:self.skipTest('Configured native Android SDK and JDK required')
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);source=root/'sdk';source.write_text(SDK);db=root/'catalog';index_android(db,source,sdk=35)
   with Catalog(db) as c:scope=c.get('android','java.util.Collections#singletonList(T)')['scope']
   with contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(main(['sdk','plan-android-specializations','--catalog',str(db),'--scope',scope,'--output',str(root/'plan.json')]),0)
   plan=json.loads((root/'plan.json').read_text());self.assertEqual(plan['candidateCount'],1);self.assertFalse(plan['nativeVerified'])
   with contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()):
    self.assertEqual(main(['sdk','verify-android-specializations',str(root/'plan.json'),'--catalog',str(db),'--sdk',sdk,'--javac',javac,'--api-level','35','--output',str(root/'proof'),'--min-free-mb','1']),0)
   report=json.loads((root/'proof/report.json').read_text());self.assertEqual(report['compiledCount'],1)
