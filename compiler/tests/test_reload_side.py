import copy
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import shutil
import subprocess
import unittest
from unittest.mock import patch
from dcflight.reload.planner import plan,abi_digest
from dcflight.reload.watch import snapshot,run
from dcflight.registry import Registry
from dcflight.validate import lower
from dcflight.compiler import compile_app
from dcflight.audit import audit


def document():
    return {'version':1,'id':'com.example.reload','name':'Reload','root':{'id':'label','type':'text','props':{'text':'Native'}}}


class ReloadTests(unittest.TestCase):
    def test_unknown_change_restarts_not_fake_reload(self):
        raw=document();app=lower(raw,Registry())
        self.assertEqual(plan(None,app).action,'restart')
        self.assertEqual(plan(app,app).action,'none')
        self.assertEqual(plan(app,app,native_changed=True).action,'restart')
        changed=copy.deepcopy(raw);changed['root']['props']['text']='Changed'
        self.assertEqual(plan(app,lower(changed,Registry())).action,'restart')
        changed['id']='com.example.other'
        self.assertEqual(plan(app,lower(changed,Registry())).action,'blocked')

    def test_abi_changes_not_eligible_and_mobile_default_restart(self):
        raw=document();raw['logic']={'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':'inc','parameters':['uint32'],'returns':'uint32'}]}
        app=lower(raw,Registry())
        self.assertEqual(plan(app,app,logic_changed=True).action,'restart')
        self.assertEqual(plan(app,app,logic_changed=True,live_logic=True).action,'native-swap')
        raw['logic']['functions'][0]['parameters'].append('uint32');changed=lower(raw,Registry())
        self.assertNotEqual(abi_digest(app.logic.functions),abi_digest(changed.logic.functions))
        self.assertEqual(plan(app,changed,logic_changed=True,live_logic=True).action,'restart')

    def test_snapshot_sees_deletion_same_size_edit_and_skips_builds(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);f=root/'logic.dart';f.write_text('abc');before=snapshot([root])
            f.write_text('def');self.assertNotEqual(before,snapshot([root]))
            (root/'build').mkdir();(root/'build/junk.dart').write_text('ignore')
            self.assertEqual(len(snapshot([root])),1)
            f.unlink();self.assertEqual(snapshot([root]),{})

    def test_native_outputs_have_no_loader_dependency(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/'app.json';source.write_text(json.dumps(document()))
            compile_app(source,root/'native')
            self.assertTrue(audit(root/'native')['passed'])
            for f in (root/'native').rglob('*'):
                if f.is_file() and '.dcflight' not in f.parts:
                    self.assertNotIn(b'dcflight_reload',f.read_bytes())

    def test_failed_build_does_not_deploy_and_releases_session_lock(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/'app.json';source.write_text(json.dumps(document()))
            args=SimpleNamespace(source=str(source),out=str(root/'native'),target='android',device='private-test',
                                 build_only=False,interval=0.1,watch=[],evaluate_dart=False,dart_sdk='dart',once=True)
            with patch('dcflight.reload.watch.build',side_effect=ValueError('Compiler error')),patch('dcflight.reload.watch.deploy') as deploy,patch('dcflight.reload.watch.time.sleep'):
                self.assertEqual(run(args),1);deploy.assert_not_called()
            self.assertFalse((root/'native/.dcflight/reload/session.lock').exists())

    def test_stale_build_never_installed(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/'app.json';source.write_text(json.dumps(document()))
            args=SimpleNamespace(source=str(source),out=str(root/'native'),target='android',device='private-test',
                                 build_only=False,interval=0.1,watch=[],evaluate_dart=False,dart_sdk='dart',once=True)
            def build(*unused):source.write_text(source.read_text()+'\n');return root/'fake.apk',{}
            with patch('dcflight.reload.watch.build',side_effect=build),patch('dcflight.reload.watch.deploy') as deploy,patch('dcflight.reload.watch.time.sleep'):
                self.assertEqual(run(args),2);deploy.assert_not_called()

    def test_release_gate_rejects_absent_and_zero_define(self):
        cc=shutil.which('clang') or shutil.which('cc')
        if not cc:self.skipTest('A C compiler is needed for the release gate check')
        native=Path(__file__).resolve().parents[1]/'dcflight/reload/native'
        with tempfile.TemporaryDirectory() as d:
            for flags in ([],['-DDCFLIGHT_DEVELOPMENT_RELOAD=0']):
                result=subprocess.run([cc,*flags,'-c',str(native/'loader.c'),'-o',str(Path(d)/'loader.o')],capture_output=True)
                self.assertNotEqual(result.returncode,0)
