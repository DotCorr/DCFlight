import json
from pathlib import Path
import tempfile
import unittest

from dcflight.audit import audit, generated_integrity, source_consistency
from dcflight.compiler import compile_app
from test_navigation_ir import fixture


class GeneratedIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        compile_app('unused.json', self.root, document=fixture())
        self.state_path = self.root / '.dcflight/state.json'
        self.state = json.loads(self.state_path.read_text())
        self.screen = next(self.root / name for name, entry in self.state['files'].items()
                           if name.endswith('AuthoredApplication.kt'))

    def test_platform_screen_edit_invalidates_audit_despite_matching_inputs(self):
        self.assertTrue(audit(self.root)['passed'])
        original = self.screen.read_text()
        self.assertIn('Settings', original)
        self.screen.write_text(original.replace('Settings', 'Different Android copy'))
        self.assertEqual('matched', source_consistency(self.root)['status'])
        result = audit(self.root)
        self.assertFalse(result['passed'])
        self.assertEqual('changed', result['generatedIntegrity']['status'])
        self.assertIn('AuthoredApplication.kt', '\n'.join(result['findings']))
        self.assertIn('Different Android copy', self.screen.read_text())
        self.screen.write_text(original)
        self.assertTrue(audit(self.root)['passed'])

    def test_missing_generated_screen_is_reported(self):
        self.screen.unlink()
        result = audit(self.root)
        self.assertFalse(result['passed'])
        self.assertIn('generated file is missing', '\n'.join(result['findings']))

    def test_user_owned_edits_and_build_outputs_are_not_generation_drift(self):
        user_path = next(self.root / name for name, entry in self.state['files'].items()
                         if entry['ownership'] == 'user' and name.endswith('.swift'))
        user_path.write_text(user_path.read_text() + '\n// User customization\n')
        build = self.root / 'android/app/build/intermediates/test.kt'
        build.parent.mkdir(parents=True)
        build.write_text('Build output')
        self.assertEqual('matched', generated_integrity(self.root)['status'])
        self.assertTrue(audit(self.root)['passed'])

    def test_receipt_edit_is_detected_and_malformed_receipt_fails_closed(self):
        receipt = self.root / '.dcflight/source.json'
        receipt.write_text(receipt.read_text() + '\n')
        self.assertFalse(audit(self.root)['passed'])
        receipt.write_text('{invalid')
        self.assertFalse(audit(self.root)['passed'])

    def test_manifest_traversal_and_duplicate_keys_are_rejected(self):
        self.state['files']['../outside.swift'] = {'ownership': 'generated', 'sha256': 'a' * 64}
        self.state_path.write_text(json.dumps(self.state))
        self.assertEqual('changed', generated_integrity(self.root)['status'])
        self.state_path.write_text('{"version":1,"files":{},"files":{}}')
        self.assertFalse(audit(self.root)['passed'])

    def test_symlink_does_not_certify_external_source(self):
        self.screen.unlink()
        self.screen.symlink_to(self.root / '.dcflight/source.json')
        self.assertFalse(audit(self.root)['passed'])

    def test_missing_baseline_is_explicitly_unknown(self):
        self.state_path.unlink()
        self.assertEqual('unknown', generated_integrity(self.root)['status'])
