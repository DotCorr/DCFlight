import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
import contextlib
import io


class AndroidArrayHarnessTests(unittest.TestCase):
    def test_cli_requires_explicit_device_selection(self):
        from dcflight.cli import main
        with contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):
            main(['sdk','test-android-values','--catalog','sdk.sqlite','--sdk','sdk',
                  '--java-home','jdk','--report','report.json'])

    def test_invalid_sdk_fails_before_toolchain_or_device_access(self):
        from dcflight.android_verification import run
        with tempfile.TemporaryDirectory() as tmp:
            for version in (0,-1,True):
                with self.subTest(version=version),self.assertRaisesRegex(ValueError,'Invalid SDK'):
                    run(SimpleNamespace(report=Path(tmp)/'report.json',api_level=version,build_tools='35.0.0'))
            self.assertFalse((Path(tmp)/'report.json').exists())

    def test_old_success_cannot_be_reused_as_current_execution_evidence(self):
        path = Path(__file__).resolve().parents[1] / 'tools/verify_android_array_calls.py'
        spec = importlib.util.spec_from_file_location('array_harness', path)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / 'report.json'
            report.write_text('{"passed": true}')
            with self.assertRaisesRegex(ValueError, 'new report path'):
                module.run(SimpleNamespace(report=report))
            self.assertEqual('{"passed": true}', report.read_text())
