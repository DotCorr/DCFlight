from ios_sdk_fixture import fake_toolchain, write_sdk
import copy
import gzip
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import contextlib
import io
import sys
from unittest.mock import patch

TOOL=Path(__file__).resolve().parents[1]/'tools/sweep_ios_sdk.py'
spec=importlib.util.spec_from_file_location('ios_sweep_retention',TOOL)
sweep=importlib.util.module_from_spec(spec);spec.loader.exec_module(sweep)

class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve();self.source=self.root/'input.symbols.json'
        self.raw=b'{"symbols":[],"module":{"name":"Test"}}\n';self.source.write_bytes(self.raw)
        self.dir=self.root/'module';self.dir.mkdir();self.provenance={'compilerSources':{'a.py':'123'},'target':'ios18'}
    def receipt(self,keep=False):
        graphs=sweep.retain_graphs([self.source],self.dir/'symbolgraphs',keep)
        records=self.dir/'records.jsonl';records.write_text('{}\n')
        return {'status':'success','provenance':self.provenance,'proofReusable':True,'artifacts':{'graphs':graphs,'records':{'path':records.name,'sha256':sweep.digest(records)}}}
    def test_deterministic_roundtrip_and_resume(self):
        status=self.receipt();g=status['artifacts']['graphs'][0];p=self.dir/'symbolgraphs'/g['path']
        self.assertEqual(gzip.decompress(p.read_bytes()),self.raw)
        other=sweep.retain_graphs([self.source],self.root/'other')[0]
        self.assertEqual(g,other);self.assertIsNone(sweep.resume_problem(status,self.dir,self.provenance))
    def test_compressed_source_and_raw_compatibility(self):
        compressed=self.root/'another.symbols.json.gz'
        with gzip.open(compressed,'wb') as f:f.write(self.raw)
        g=sweep.retain_graphs([compressed],self.dir/'symbolgraphs',True)[0]
        self.assertEqual((self.dir/'symbolgraphs'/g['path']).read_bytes(),self.raw)
        self.assertEqual(g['compression'],'none')
        self.assertTrue(compressed.exists())
    def test_record_corruption_rejects_resume(self):
        s=self.receipt();(self.dir/'records.jsonl').write_text('tampered')
        self.assertIn('records hash',sweep.resume_problem(s,self.dir,self.provenance))
    def test_graph_corruption_and_forged_compressed_hash(self):
        s=self.receipt();g=s['artifacts']['graphs'][0];p=self.dir/'symbolgraphs'/g['path'];p.write_bytes(b'invalid gzip')
        self.assertIn('graph hash',sweep.resume_problem(s,self.dir,self.provenance))
        g['sha256']=sweep.digest(p)
        self.assertIn('corrupt',sweep.resume_problem(s,self.dir,self.provenance))
    def test_raw_hash_mismatch_and_extra_graph_reject(self):
        s=self.receipt();s['artifacts']['graphs'][0]['rawSHA256']='wrong'
        self.assertIn('raw graph hash',sweep.resume_problem(s,self.dir,self.provenance))
        (self.dir/'symbolgraphs/extra.symbols.json').write_bytes(self.raw)
        self.assertIn('file set',sweep.resume_problem(s,self.dir,self.provenance))
    def test_missing_artifacts_legacy_and_fingerprint_reject(self):
        s=self.receipt();other=copy.deepcopy(self.provenance);other['compilerSources']['a.py']='changed'
        self.assertIn('fingerprint',sweep.resume_problem(s,self.dir,other))
        self.assertIn('fingerprint',sweep.resume_problem({'status':'success'},self.dir,self.provenance))
        s['proofReusable']=False
        self.assertIn('discarded',sweep.resume_problem(s,self.dir,self.provenance))
        s['proofReusable']=True;(self.dir/'records.jsonl').unlink()
        self.assertIn('missing',sweep.resume_problem(s,self.dir,self.provenance))
    def test_empty_input_rejected(self):
        with self.assertRaisesRegex(ValueError,'No symbol graphs'):sweep.retain_graphs([],self.dir/'symbolgraphs')
    def test_duplicate_basename_preserved(self):
        other=self.root/'other';other.mkdir();p=other/self.source.name;p.write_bytes(b'{}')
        graphs=sweep.retain_graphs([self.source,p],self.dir/'symbolgraphs')
        self.assertEqual(len({g['path'] for g in graphs}),2)

class MainResumeTests(unittest.TestCase):
    def test_main_recovers_corrupt_and_nonobject_receipts(self):
        for raw in ('{','[]','{"status":"success"}', '{"module":"Test","status":"success","counts":[]}'):
            with self.subTest(raw=raw):self.run_case(raw)
    def test_main_rejects_symlink_module_without_touching_target(self):
        self.run_case(None,symlink='module')
    def test_main_rejects_artifact_and_predictable_temp_symlinks(self):
        for name in ('records.jsonl','records.jsonl.tmp','status.json.tmp','symbolgraphs'):
            with self.subTest(name=name):self.run_case(None,symlink=name)
    def run_case(self,raw,symlink=None):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve();sdk=root/'sdk';sdk.mkdir();write_sdk(sdk)
            out=root/'out';out.mkdir();foreign=root/'foreign';foreign.mkdir();marker=foreign/'preserve';marker.write_text('unchanged')
            inputs=root/'inputs';inputs.mkdir();(inputs/'Test.symbols.json').write_text('{"module":{"name":"Test"},"symbols":[],"relationships":[]}')
            target=out/'Test'
            if symlink=='module':target.symlink_to(foreign,target_is_directory=True)
            else:
                target.mkdir()
                if symlink:(target/symlink).symlink_to(foreign if symlink=='symbolgraphs' else marker,target_is_directory=symlink=='symbolgraphs')
                if raw is not None:(target/'status.json').write_text(raw)
            def command(*args):
                if '--show-sdk-path' in args:return str(sdk)
                if '--show-sdk-version' in args:return '26.2'
                if '--find' in args:return str(TOOL)
                return 'fixture'
            argv=['sweep','--output',str(out),'--modules','Test','--min-free-mb','0','--reuse','Test='+str(inputs)]
            with patch.object(sweep,'command',command),patch.object(sweep,'compiler_sources',lambda:{}),patch.object(sweep,'discover',lambda sdk:[{'module':'Test','excluded':False}]),patch.object(sys,'argv',argv),contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()):
                if symlink:
                    with self.assertRaisesRegex(ValueError,'symlink'):sweep.main()
                else:
                    sweep.main();status=json.loads((target/'status.json').read_text())
                    self.assertEqual(status['status'],'success');self.assertIn('unreadable',status['resumeReason'])
                    before=(target/'status.json').read_bytes();sweep.main();self.assertEqual(before,(target/'status.json').read_bytes())
            self.assertEqual(marker.read_text(),'unchanged');self.assertEqual(list(foreign.iterdir()),[marker])

if __name__=='__main__':unittest.main()
