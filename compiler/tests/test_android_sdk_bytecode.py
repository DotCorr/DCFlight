import contextlib,io,json,os,shutil,subprocess,tempfile,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
from dcflight.modules.export import index_android_sdk

class AndroidSDKBytecodeTests(unittest.TestCase):
    def fixture(self,root,level='36',extra=''):
        jar=root/'android.jar';jar.write_bytes(b'fixture')
        (root/'source.properties').write_text('AndroidVersion.ApiLevel='+level+'\nAndroidVersion.IsBaseSdk=true\n'+extra)
        return jar
    def test_full_platform_scope_is_separate_and_not_runtime_module(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);jar=self.fixture(root)
            with patch('dcflight.modules.export._export_bytecode',return_value={'ok':True}) as export:
                self.assertEqual(index_android_sdk(jar,root/'new.db'),{'ok':True})
            kwargs=export.call_args.kwargs
            self.assertEqual(kwargs['scope'],'sdk-bytecode:36');self.assertEqual(kwargs['sdk'],36)
            self.assertNotIn('prefixes',kwargs);self.assertEqual(kwargs['origin']['dependencyKind'],'platform-sdk')
            self.assertNotIn('nativeModule',kwargs['origin']);self.assertIn('not recovered',kwargs['origin']['availabilityMetadata'])
    def test_minor_preview_and_mismatched_metadata_reject_before_catalog(self):
        for level,extra,sdk in [('37.2','',None),('36','',35),('36','AndroidVersion.CodeName=Preview\n',None),('36','AndroidVersion.PreviewSdkInt=1\n',None),('36','AndroidVersion.ApiLevel=36\n',None)]:
            with self.subTest(level=level,extra=extra),tempfile.TemporaryDirectory() as temp:
                root=Path(temp);jar=self.fixture(root,level,extra)
                with patch('dcflight.modules.export._export_bytecode') as export,self.assertRaises(ValueError):index_android_sdk(jar,root/'new.db',sdk=sdk)
                export.assert_not_called();self.assertFalse((root/'new.db').exists())
    def test_public_cli_forwards_platform_sdk_without_default35(self):
        from dcflight.cli import main
        with patch('dcflight.modules.export.index_android_sdk',return_value={'ok':True}) as export,contextlib.redirect_stdout(io.StringIO()):
            main(['sdk','index-android-sdk','/tmp/android.jar','--catalog','/tmp/unused.db','--javap','exact-javap'])
        self.assertEqual(export.call_args.kwargs,{'javap':'exact-javap','sdk':None})
    def test_actual_jar_public_classes_outside_core_are_imported(self):
        from dcflight.catalog import Catalog
        javac=str(Path(os.environ['JAVA_HOME'])/'bin/javac') if os.environ.get('JAVA_HOME') else shutil.which('javac')
        javap=str(Path(os.environ['JAVA_HOME'])/'bin/javap') if os.environ.get('JAVA_HOME') else shutil.which('javap')
        if not javac or not javap:self.skipTest('Set JAVA_HOME or provide javac and javap on PATH')
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root);src=root/'android/testing/Widget.java';src.parent.mkdir(parents=True)
            src.write_text('package android.testing; public class Widget { public static int value() { return 42; } public static class Nested { public int count() { return 3; } } }')
            subprocess.run([javac,'--release','8',str(src)],check=True,capture_output=True)
            with zipfile.ZipFile(root/'android.jar','w') as z:
                for f in root.rglob('*.class'):z.write(f,str(f.relative_to(root)))
            result=index_android_sdk(root/'android.jar',root/'catalog.db',javap=javap)
            self.assertEqual(result['classesInspected'],2);self.assertFalse(result['compiled']);self.assertFalse(result['executed'])
            with Catalog(root/'catalog.db') as catalog:
                record=catalog.get('android','android.testing.Widget#value()','sdk-bytecode:36')
                self.assertTrue(record['api']['emittable']);self.assertIsNone(record['api']['availability']['minimumApi'])
            self.assertFalse(any(p.suffix=='.jar' for p in (root/'catalog.db.sources').rglob('*')))

class SDKProcessBoundsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        tool=Path(__file__).resolve().parents[1]/'tools/verify_android_sdk_bytecode.py'
        spec=importlib.util.spec_from_file_location('sdk_bytecode_verifier',tool)
        cls.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.module)
    def test_expired_deadline_prevents_index_worker_launch(self):
        import sys,time
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);marker=root/'launched'
            with self.assertRaisesRegex(ValueError,'deadline'):
                self.module.bounded_run([sys.executable,'-c',f'open({str(marker)!r},"w").close()'],root/'log',deadline=time.monotonic()-1,disk_path=root,disk_floor=0)
            self.assertFalse(marker.exists())
    def test_timeout_kills_descendant_writer(self):
        import sys,time
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);marker=root/'writes'
            child='import time\nf=open('+repr(str(marker))+',"ab",buffering=0)\nwhile True:\n f.write(b"x");time.sleep(.01)'
            parent='import subprocess,sys,time\nsubprocess.Popen([sys.executable,"-c",'+repr(child)+'])\ntime.sleep(60)'
            with self.assertRaisesRegex(ValueError,'deadline'):
                self.module.bounded_run([sys.executable,'-c',parent],root/'log',deadline=time.monotonic()+1,disk_path=root,disk_floor=0)
            self.assertTrue(marker.exists());size=marker.stat().st_size;time.sleep(.2)
            self.assertEqual(marker.stat().st_size,size)
    def test_active_output_bound(self):
        import sys,time
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with self.assertRaisesRegex(ValueError,'output bound'):
                self.module.bounded_run([sys.executable,'-c','import os\nwhile True: os.write(1,b"x"*8192)'],root/'log',deadline=time.monotonic()+5,disk_path=root,max_bytes=1024,disk_floor=0)
            self.assertLessEqual((root/'log').stat().st_size,1024)
    def test_live_disk_floor(self):
        import sys,time
        from collections import namedtuple
        Usage=namedtuple('Usage','total used free')
        with tempfile.TemporaryDirectory() as temp,patch.object(self.module.shutil,'disk_usage',side_effect=[Usage(10,0,10),Usage(10,10,0)]):
            root=Path(temp)
            with self.assertRaisesRegex(ValueError,'disk floor'):
                self.module.bounded_run([sys.executable,'-c','import time;time.sleep(60)'],root/'log',deadline=time.monotonic()+5,disk_path=root,disk_floor=1)
    def test_snapshot_copy_bounds_actual_bytes_not_only_stat(self):
        import time
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/'source';source.write_bytes(b'12345678')
            with self.assertRaisesRegex(ValueError,'size bound'):
                self.module.bounded_copy(source,root/'oversize',limit=4,deadline=time.monotonic()+5,disk_path=root,disk_floor=0)
            self.assertFalse((root/'oversize').exists())
            # A stale stat must not allow post-stat growth to bypass the bound.
            with patch.object(Path,'stat',return_value=SimpleNamespace(st_size=0,st_mode=source.stat().st_mode)),patch.object(self.module.os,'fstat',return_value=SimpleNamespace(st_size=0,st_mode=0o100644)),self.assertRaisesRegex(ValueError,'size bound'):
                self.module.bounded_copy(source,root/'growth',limit=4,deadline=time.monotonic()+5,disk_path=root,disk_floor=0)
            self.assertLessEqual((root/'growth').stat().st_size,4)
    def test_snapshot_copy_deadline_and_exact_bytes(self):
        import time
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/'source';source.write_bytes(b'abc\x00xyz')
            with self.assertRaisesRegex(ValueError,'deadline'):
                self.module.bounded_copy(source,root/'expired',limit=7,deadline=time.monotonic()-1,disk_path=root,disk_floor=0)
            self.module.bounded_copy(source,root/'valid',limit=7,deadline=time.monotonic()+5,disk_path=root,disk_floor=0)
            self.assertEqual(source.read_bytes(),(root/'valid').read_bytes())
    def test_original_rehash_enforces_deadline_and_post_stat_size(self):
        import hashlib,time
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/'source';source.write_bytes(b'12345678')
            with self.assertRaisesRegex(ValueError,'deadline'):
                self.module.digest(source,limit=8,deadline=time.monotonic()-1)
            with patch.object(Path,'stat',return_value=SimpleNamespace(st_size=0,st_mode=source.stat().st_mode)),patch.object(self.module.os,'fstat',return_value=SimpleNamespace(st_size=0,st_mode=0o100644)),self.assertRaisesRegex(ValueError,'size bound'):
                self.module.digest(source,limit=4,deadline=time.monotonic()+5)
            self.assertEqual(self.module.digest(source,limit=8,deadline=time.monotonic()+5),hashlib.sha256(source.read_bytes()).hexdigest())
    def test_opened_input_must_be_regular_and_not_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);fifo=root/'pipe';os.mkfifo(fifo)
            with self.assertRaisesRegex(ValueError,'regular-file'):
                self.module.open_bounded_input(fifo,64)
            source=root/'source';source.write_bytes(b'abc');link=root/'alias';link.symlink_to(source)
            with self.assertRaises(OSError):self.module.open_bounded_input(link,64)
