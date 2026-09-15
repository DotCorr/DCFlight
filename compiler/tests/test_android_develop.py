import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from dcflight.android_develop import choose_android_device, android_doctor, run_android


class AndroidDevelopTests(unittest.TestCase):
    def test_device_selection(self):
        self.assertEqual('emulator-5554', choose_android_device('List of devices attached\nemulator-5554 device product:sdk model:phone\nphone unauthorized'))
        with self.assertRaisesRegex(ValueError, 'Multiple'): choose_android_device('one device\ntwo device')
        with self.assertRaisesRegex(ValueError, 'unauthorized'): choose_android_device('phone unauthorized', 'phone')
        with self.assertRaisesRegex(ValueError, 'No authorized'): choose_android_device('phone offline')
        self.assertEqual('two', choose_android_device('one device\ntwo device', 'two'))

    def test_missing_sdk_reports_action(self):
        with self.assertRaisesRegex(ValueError, 'SDK not found'):
            android_doctor(sdk='/does-not-exist/dcflight-test')

    def test_build_only_does_not_require_device(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            (root / 'app.json').write_text(json.dumps({'id': 'com.example.test'}))
            apk = root / 'native/android/app/build/outputs/apk/debug/app-debug.apk'
            apk.parent.mkdir(parents=True); apk.write_bytes(b'APK')
            tools = {'sdk': folder, 'java_home': None, 'gradle': '/gradle', 'adb': '/adb'}
            with patch('dcflight.android_develop.android_doctor', return_value=tools) as doctor, patch('dcflight.android_develop.compile_app') as compile_app, patch('dcflight.android_develop.subprocess.run', return_value=SimpleNamespace(returncode=0)) as run, patch('dcflight.android_develop.subprocess.check_output') as check:
                result = run_android(root, build_only=True)
                self.assertTrue(result['built']); self.assertNotIn('running', result)
                check.assert_not_called()
                self.assertEqual(1, run.call_count)
                self.assertFalse(doctor.call_args.kwargs['require_device'])
                compile_app.assert_called_once_with(root / 'app.json', root / 'native', targets=('android',))

    def test_native_launch_failure_is_not_reported_as_running(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve(); (root / 'app.json').write_text('{"id":"com.example.test"}')
            apk = root / 'native/android/app/build/outputs/apk/debug/app-debug.apk'
            apk.parent.mkdir(parents=True); apk.write_bytes(b'APK')
            tools = {'sdk': folder, 'java_home': None, 'gradle': '/gradle', 'adb': '/adb'}
            with patch('dcflight.android_develop.android_doctor', return_value=tools), patch('dcflight.android_develop.compile_app'), patch('dcflight.android_develop.subprocess.check_output', return_value='phone device'), patch('dcflight.android_develop.subprocess.run', side_effect=[SimpleNamespace(returncode=0), SimpleNamespace(returncode=0), SimpleNamespace(returncode=0, stdout='Error: Activity class does not exist', stderr='')]):
                with self.assertRaisesRegex(ValueError, 'launch failed'): run_android(root)


if __name__ == '__main__': unittest.main()
