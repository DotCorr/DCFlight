import json
import sys
import unittest
from unittest import mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dcflight.design_companion import APPLLLAMA, guidance, TOPICS
from dcflight import doctor


class GuidanceTests(unittest.TestCase):
    def test_all_topics_resolvable(self):
        for topic in TOPICS:
            result = guidance(topic)
            self.assertNotIn('error', result)
            self.assertIn('rules', result)
            self.assertIn('companion', result)

    def test_aliases_hit_real_topics(self):
        for alias in ('lists', 'nav', 'tabs', 'forms', ''):
            self.assertNotIn('error', guidance(alias))

    def test_unknown_topic_lists_available(self):
        result = guidance('spaceships')
        self.assertIn('error', result)
        self.assertEqual(set(result['available']), set(TOPICS))

    def test_companion_is_registration_only(self):
        self.assertEqual(APPLLLAMA['endpoint'], 'https://mcp.appllama.io/mcp')
        self.assertIn('npx skills@latest', APPLLLAMA['install'])
        self.assertTrue(all('never auto-installed' in note or 'user-owned' in note or 'Default design companion' in note
                            for note in APPLLLAMA['notes']))


class DoctorCompanionTests(unittest.TestCase):
    def test_status_includes_design_companion(self):
        present = {name: '/usr/local/bin/' + name for name in
                   ('dart', 'dcc', 'java', 'adb', 'gradle', 'git', 'xcodebuild', 'xcrun')}
        with mock.patch.object(doctor, '_which', side_effect=lambda n: present.get(n)), \
             mock.patch.object(doctor, '_run', return_value='1.2.3'):
            report = doctor.status()
        self.assertEqual(report['designCompanion']['id'], 'appllama')
        self.assertIn('ready', report)

    def test_mcp_design_guidance_tool_roundtrip(self):
        from dcflight.mcp import Server
        server = Server(catalog=None)
        names = {tool['name'] for tool in server.tools}
        self.assertIn('design_guidance', names)
        server.initialized = True
        response = server.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call',
                                  'params': {'name': 'design_guidance', 'arguments': {'topic': 'list'}}})
        payload = json.loads(response['result']['content'][0]['text'])
        self.assertFalse(response['result']['isError'])
        self.assertIn('rules', payload)
        self.assertEqual(payload['companion']['id'], 'appllama')
        bad = server.handle({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/call',
                             'params': {'name': 'design_guidance', 'arguments': {'topic': 5}}})
        self.assertTrue(bad['result']['isError'])
        self.assertEqual(bad['result']['content'][0]['text'], 'topic must have type string')


if __name__ == '__main__':
    unittest.main()
