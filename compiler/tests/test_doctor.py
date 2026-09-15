import sys
import unittest
from unittest import mock
from dcflight import doctor


class DoctorStatusTests(unittest.TestCase):
    def test_status_reflects_path_presence(self):
        present = {name: '/usr/local/bin/' + name for name in
                   ('dart', 'dcc', 'java', 'adb', 'gradle', 'git', 'xcodebuild', 'xcrun')}
        with mock.patch.object(doctor, '_which', side_effect=lambda n: present.get(n)), \
             mock.patch.object(doctor, '_run', return_value='1.2.3'):
            report = doctor.status()
        by_name = {row['name']: row for row in report['items']}
        self.assertTrue(report['ready'])
        self.assertEqual(report['missing'], [])
        self.assertTrue(by_name['dart']['present'])
        self.assertEqual(by_name['dart']['version'], '1.2.3')
        self.assertTrue(all(row['present'] for row in report['items']))

    def test_missing_required_tool_fails_readiness_with_note(self):
        present = {'dart': '/usr/local/bin/dart', 'python': sys.executable}
        with mock.patch.object(doctor, '_which', side_effect=lambda n: present.get(n)), \
             mock.patch.object(doctor, '_run', return_value='1.2.3'):
            report = doctor.status()
        self.assertFalse(report['ready'])
        self.assertIn('dcc', report['missing'])
        rows = {row['name']: row for row in report['items']}
        self.assertIn('dcdart', rows['dcc']['note'])


class DoctorInstallTests(unittest.TestCase):
    def test_install_without_opt_in_touches_nothing(self):
        events = []
        with mock.patch.object(doctor, 'status', return_value={'ready': False, 'missing': [], 'items': []}):
            result = doctor.install(progress=events.append)
        self.assertEqual(result['requested'], [])
        self.assertEqual(events, [])

    def test_install_runs_stubbed_installers_and_rechecks(self):
        events = []
        calls = []
        with mock.patch.object(doctor, 'status', side_effect=[
                {'ready': False, 'missing': ['dart'], 'items': []},
                {'ready': True, 'missing': [], 'items': []}]), \
             mock.patch.object(doctor, '_install_dart', side_effect=lambda say: calls.append('dart')):
            result = doctor.install(progress=events.append)
        self.assertEqual(result['installed'], ['dart'])
        self.assertTrue(result['ready'])
        self.assertEqual(calls, ['dart'])
        self.assertEqual([event['state'] for event in events], ['installing', 'installed'])

    def test_dcc_requires_explicit_url(self):
        with mock.patch.dict('os.environ', {}, clear=True):
            with self.assertRaises(ValueError):
                doctor._url('dcc')


if __name__ == '__main__':
    unittest.main()
