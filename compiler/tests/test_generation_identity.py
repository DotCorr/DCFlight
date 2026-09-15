import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from dcflight.registry import Registry
from dcflight.compiler import compile_app
from dcflight.audit import source_consistency
from dcflight.generation_identity import generation_identity
from test_navigation_ir import fixture


class GenerationIdentityTests(unittest.TestCase):
    def test_compiler_only_upgrade_marks_other_target_stale(self):
        with tempfile.TemporaryDirectory() as tmp:
            old={'version':'one','compilerSha256':'a'*64,'registrySha256':'b'*64}
            new={**old,'compilerSha256':'c'*64}
            with patch('dcflight.generation_identity.generation_identity',return_value=old):
                compile_app('unused.json',tmp,document=fixture())
            with patch('dcflight.generation_identity.generation_identity',return_value=new):
                compile_app('unused.json',tmp,targets=('ios',),document=fixture())
                self.assertEqual('mismatched',source_consistency(tmp)['status'])
                receipt=json.loads((Path(tmp)/'.dcflight/source.json').read_text())
                self.assertEqual(old,receipt['targets']['android']['generator'])
                compile_app('unused.json',tmp,targets=('android',),document=fixture())
                self.assertEqual('matched',source_consistency(tmp)['status'])

    def test_identity_is_relocatable_and_ignores_bytecode(self):
        with tempfile.TemporaryDirectory() as tmp:
            roots=[Path(tmp)/name for name in ('first','second')]
            registry=Registry()
            for root in roots:
                root.mkdir();(root/'backend.py').write_text('version = 1')
            self.assertEqual(generation_identity(registry,roots[0]),generation_identity(registry,roots[1]))
            (roots[0]/'__pycache__').mkdir();(roots[0]/'__pycache__/junk.py').write_text('ignored')
            self.assertEqual(generation_identity(registry,roots[0]),generation_identity(registry,roots[1]))
            (roots[1]/'backend.py').write_text('version = 2')
            self.assertNotEqual(generation_identity(registry,roots[0]),generation_identity(registry,roots[1]))

    def test_effective_mapping_changes_identity_without_version_bump(self):
        registry=Registry();before=generation_identity(registry)
        registry.entries['text']['targets']['ios']['expression']='Text("changed mapping")'
        after=generation_identity(registry)
        self.assertEqual(before['compilerSha256'],after['compilerSha256'])
        self.assertNotEqual(before['registrySha256'],after['registrySha256'])
