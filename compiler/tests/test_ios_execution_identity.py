import importlib.util,sys,tempfile,unittest,json,os,time
from pathlib import Path
from unittest.mock import patch
from dcflight import ios_execution_identity as m
class ExecutionIdentityTests(unittest.TestCase):
 def fixture(self,root):
  sdk=root/'sdk';sdk.mkdir();(sdk/'SDKSettings.json').write_text('{}');(sdk/'A.swiftinterface').write_text('public struct A {}');tools=root/'tools';tools.mkdir();(tools/'swift-frontend').write_bytes(b'frontend');return {'sdk':sdk,'toolchain':tools}
 def test_sdk_interface_change_detects_unchanged_settings(self):
  with tempfile.TemporaryDirectory() as t:
   roots=self.fixture(Path(t));before=m.snapshot(roots);(roots['sdk']/'A.swiftinterface').write_text('public struct B {}')
   with self.assertRaisesRegex(ValueError,'changed'):m.same_snapshot(before,m.snapshot(roots))
 def test_frontend_change_detects(self):
  with tempfile.TemporaryDirectory() as t:
   roots=self.fixture(Path(t));before=m.snapshot(roots);(roots['toolchain']/'swift-frontend').write_bytes(b'other')
   with self.assertRaisesRegex(ValueError,'changed'):m.same_snapshot(before,m.snapshot(roots))
 def test_symlink_topology_and_external_links(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);roots=self.fixture(r);link=roots['toolchain']/'swiftc';link.symlink_to('swift-frontend');before=m.snapshot(roots);self.assertTrue(any(x['kind']=='symlink' for x in before['entries']));link.unlink();link.symlink_to(r/'outside');(r/'outside').write_bytes(b'outside')
   with self.assertRaisesRegex(ValueError,'external'):m.snapshot(roots)
 def test_new_file_detected(self):
  with tempfile.TemporaryDirectory() as t:
   roots=self.fixture(Path(t));before=m.snapshot(roots);(roots['sdk']/'new.modulemap').write_bytes(b'new')
   with self.assertRaisesRegex(ValueError,'changed'):m.same_snapshot(before,m.snapshot(roots))
 def test_scan_byte_bound(self):
  with tempfile.TemporaryDirectory() as t:
   roots=self.fixture(Path(t))
   with patch.object(m,'MAX_BYTES',1):
    with self.assertRaisesRegex(ValueError,'bounded'):m.snapshot(roots)
 def test_options_and_existing_output_fail_before_discovery(self):
  with tempfile.TemporaryDirectory() as t:
   with patch.object(m,'discover',side_effect=AssertionError('must not discover')):
    for kw in ({'swift_version':'7'},{'timeout':0},{'sdk_environment':'iphoneos','ios_version':(-1,0)}):
     with self.assertRaises(ValueError):m.run('let a = 1',Path(t)/'new',**kw)
    with self.assertRaisesRegex(ValueError,'fresh'):m.run('let a = 1',t)
 def test_changed_snapshot_does_not_publish_receipt(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);roots=self.fixture(r);context=({'sdk':str(roots['sdk'])},{'swiftc':{'path':'/usr/bin/true'}},roots)
   with patch.object(m,'discover',return_value=context), patch.object(m.subprocess,'check_output',return_value='fixture-build'), patch.object(m,'snapshot',side_effect=[{'value':1},{'value':2}]):
    with self.assertRaisesRegex(ValueError,'changed'):m.run('let a = 1',r/'proof')
   self.assertFalse((r/'proof').exists());self.assertEqual([],list(r.glob('.native-execution-*')))
 def test_fifo_and_expired_scan_reject(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);fifo=r/'fifo';os.mkfifo(fifo)
   with self.assertRaisesRegex(ValueError,'Unsupported'):m.stable_file(fifo)
   f=r/'file';f.write_bytes(b'a')
   with self.assertRaisesRegex(ValueError,'deadline'):m.stable_file(f,deadline=time.monotonic()-1)
 def test_directory_scheduling_bound(self):
  with tempfile.TemporaryDirectory() as t:
   roots=self.fixture(Path(t))
   with patch.object(m,'MAX_FILES',2):
    with self.assertRaisesRegex(ValueError,'bounded'):m.snapshot(roots)
 def test_normal_driver_exit_cleans_descendant(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);roots=self.fixture(r);marker=r/'late';driver=roots['toolchain']/'driver';driver.write_text('#!/bin/sh\n(sleep 0.4; echo late > "'+str(marker)+'") &\nexit 0\n');driver.chmod(0o755)
   context=({'sdk':str(roots['sdk'])},{'swiftc':{'path':str(driver)}},roots)
   with patch.object(m,'discover',return_value=context),patch.object(m.subprocess,'check_output',return_value='fixture-build'):
    receipt=m.run('let a = 1',r/'proof')
   time.sleep(0.6);self.assertFalse(marker.exists());self.assertTrue((r/'proof/execution-receipt.json').exists())
if __name__=='__main__':unittest.main()
