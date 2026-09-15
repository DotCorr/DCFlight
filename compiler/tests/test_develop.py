from pathlib import Path
import json
import tempfile
import unittest
from dcflight.develop import create_project, choose_simulator
from dcflight.frontends import load
from dcflight.registry import Registry
from dcflight.validate import lower


class DevelopmentTests(unittest.TestCase):
    def test_create_project_is_editable_and_native(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'new-app'
            result = create_project(root, 'My app', 'com.example.product')
            self.assertEqual(str(root.absolute()), result['project'])
            app = lower(load(root / 'app.json'), Registry())
            self.assertEqual('My app', app.name)
            self.assertTrue((root / 'native/ios/App.xcodeproj/project.pbxproj').is_file())
            self.assertTrue((root / 'native/android/app/build.gradle').is_file())
            self.assertFalse(list((root / 'native').rglob('*.dart')))

    def test_create_refuses_existing_folder(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / 'keep.txt'
            marker.write_text('keep')
            with self.assertRaisesRegex(ValueError, 'already exists'):
                create_project(folder)
            self.assertEqual('keep', marker.read_text())

    def test_invalid_identity_does_not_create_folder(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'bad'
            with self.assertRaises(ValueError):
                create_project(destination, bundle_id='../escape')
            self.assertFalse(destination.exists())

    def test_simulator_selection_is_explicit_and_prefers_booted(self):
        phone = dict(udid='phone', name='iPhone', state='Shutdown', isAvailable=True)
        tablet = dict(udid='tablet', name='iPad', state='Booted', isAvailable=True)
        devices = {'devices': {'runtime': [phone, tablet]}}
        self.assertEqual('tablet', choose_simulator(devices)['udid'])
        self.assertEqual('phone', choose_simulator(devices, 'phone')['udid'])
        with self.assertRaises(ValueError):
            choose_simulator(devices, 'missing')
        with self.assertRaises(ValueError):
            choose_simulator({'devices': {}})
