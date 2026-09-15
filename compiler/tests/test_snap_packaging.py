import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

class SnapPackagingTests(unittest.TestCase):
    def test_open_installed_shared_app_does_not_compile_or_reinstall(self):
        tool=Path(__file__).resolve().parents[1]/'tools/snap_launcher.py'
        spec=importlib.util.spec_from_file_location('snap_launcher_test',tool)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            config={key:'/tool/'+key for key in ['compiler','dcc','dart','androidClang','javaHome','androidSDK','python']}
            config.update(iosDevice='test-device',applicationId='com.dotcorr.snapshared',
                          authoringSource='/canonical/app.dart',projectDirectory='/generated')
            (root/'toolchain.json').write_text(json.dumps(config))
            devices=json.dumps({'devices':{'test':[{'udid':'test-device','state':'Booted'}]}}).encode()
            with patch.object(module,'ROOT',root),patch.object(module.sys,'argv',['launch.py','ios','--open']),patch.object(module,'backend') as backend,patch.object(module,'run') as run,patch.object(module.subprocess,'check_output',return_value=devices):
                module.main()
            backend.assert_called_once_with(config)
            commands=[list(map(str,call.args[0])) for call in run.call_args_list]
            self.assertIn(['xcrun','simctl','launch','test-device','com.dotcorr.snapshared'],commands)
            self.assertFalse(any('compile' in c or 'install' in c or 'xcodebuild' in c for c in commands))

    def test_mac_launcher_reaches_success_without_shell_status_collision(self):
        zsh=shutil.which('zsh')
        if not zsh:self.skipTest('zsh required for Mac command launcher')
        tool=Path(__file__).resolve().parents[1]/'tools/package_snap.py'
        spec=importlib.util.spec_from_file_location('snap_packager',tool)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);app=root/'app';app.mkdir()
            (app/'app.dart').write_text('// test fixture')
            (app/'ios').mkdir();(app/'android').mkdir()
            python=root/'fake python';python.write_text('#!/bin/sh\nexit 0\n');python.chmod(0o755)
            config=root/'config.json';config.write_text('{}')
            starter=root/'starter.py';starter.write_text('# fixture')
            module.package(app,config,python,'test-simulator',starter)
            result=subprocess.run([zsh,str(app/'Run Snap iOS.command')],capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('CODE_SIGNING_ALLOWED=YES',(app/'launch.py').read_text())
