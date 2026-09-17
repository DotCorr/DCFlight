import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from dcflight.audit import audit
from dcflight.backends import Artifact
from dcflight.compiler import compile_app, BACKENDS
from dcflight.frontends import load, read_json, DartParser
from dcflight.ir import Reference, ScalarType
from dcflight.mcp import Server, serve
from dcflight.registry import Registry
from dcflight.sync import Conflict, synchronize
from dcflight.validate import lower

ROOT = Path(__file__).resolve().parents[1]


class CompilerTests(unittest.TestCase):
    def setUp(self):
        self.data = load(ROOT / 'examples/counter.json')
        self.registry = Registry()
        self.temp = tempfile.TemporaryDirectory()
        self.output = Path(self.temp.name) / 'app'
        self.source = Path(self.temp.name) / 'app.json'
        self.source.write_text(json.dumps(self.data))

    def tearDown(self):
        self.temp.cleanup()

    def compile(self, data=None, **kwargs):
        if data is not None:
            self.source.write_text(json.dumps(data))
        return compile_app(self.source, self.output, **kwargs)

    def test_json_dart_equivalence(self):
        self.assertEqual(lower(self.data, self.registry), lower(load(ROOT / 'examples/counter.dart'), self.registry))
        self.assertEqual(ScalarType.INT, lower(self.data, self.registry).states[0].initial.type)

    def test_invalid_inputs_fail_before_output(self):
        mutations = [
            lambda d: d.update(version=True),
            lambda d: d.update(version=2),
            lambda d: d.update(id='../escape'),
            lambda d: d.update(name='bad\x00name'),
            lambda d: d.update(name='@string/name'),
            lambda d: d.update(id='com.class.test'),
            lambda d: d.update(unknown=1),
            lambda d: d['state'].update(count=2**40),
            lambda d: d['actions'][0].update(target='missing'),
            lambda d: d['actions'][0].update(op='execute'),
            lambda d: d['actions'][1].update(value='wrong'),
            lambda d: d['root']['children'][1]['props'].update(value={'ref': 'missing'}),
            lambda d: d['root']['children'][0].update(type='unsupported'),
            lambda d: d['root']['children'][0].update(children=[]),
            lambda d: d['root']['children'][0].update(id='home'),
            lambda d: d['root']['children'][0].update(id='Home'),
            lambda d: d['root']['children'][4]['props'].update(value=True),
            lambda d: d['root']['children'][2].update(action='missing'),
            lambda d: d['root']['children'][0]['props'].update(text={'ref': 'count'}),
            lambda d: d['root']['children'][0]['props'].update(style='red'),
        ]
        for mutation in mutations:
            data = copy.deepcopy(self.data)
            mutation(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                self.compile(data)
            self.assertFalse(self.output.exists())

    def test_noop_preserves_all_files(self):
        self.compile()
        before = {str(p): (p.read_bytes(), p.stat().st_mtime_ns) for p in self.output.rglob('*') if p.is_file()}
        self.assertEqual({'write': [], 'delete': []}, self.compile())
        after = {str(p): (p.read_bytes(), p.stat().st_mtime_ns) for p in self.output.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_structural_change_keeps_node_identity(self):
        self.compile()
        node = self.output / 'ios/App/Generated/Nodes/n_heading.swift'
        before = node.stat().st_mtime_ns
        self.data['root']['children'].reverse()
        result = self.compile(self.data)
        self.assertEqual(before, node.stat().st_mtime_ns)
        self.assertIn('ios/App/Generated/Nodes/n_home.swift', result['write'])
        self.assertNotIn('ios/App/Generated/Nodes/n_heading.swift', result['write'])

    def test_generated_edit_conflict_is_transactional(self):
        self.compile()
        node = self.output / 'ios/App/Generated/Nodes/n_heading.swift'
        node.write_text(node.read_text() + '// hand edited\n')
        model = self.output / 'ios/App/Generated/AppModel.swift'
        before = model.read_bytes()
        self.data['root']['children'][0]['props']['text'] = 'Changed'
        self.data['state']['count'] = 42
        with self.assertRaises(Conflict):
            self.compile(self.data)
        self.assertEqual(before, model.read_bytes())
        self.assertIn('// hand edited', node.read_text())

    def test_user_files_survive_and_stale_generated_files_removed(self):
        self.compile()
        path = self.output / 'ios/App/User/AppMain.swift'
        path.write_text(path.read_text() + '// user customization\n')
        self.data['root']['children'].pop(0)
        result = self.compile(self.data)
        self.assertIn('ios/App/Generated/Nodes/n_heading.swift', result['delete'])
        self.assertIn('// user customization', path.read_text())

    def test_modified_stale_file_is_not_deleted(self):
        self.compile()
        path = self.output / 'ios/App/Generated/Nodes/n_heading.swift'
        path.write_text('manual implementation')
        self.data['root']['children'].pop(0)
        with self.assertRaises(Conflict):
            self.compile(self.data)
        self.assertTrue(path.exists())

    def test_one_target_sync_preserves_other_target(self):
        self.compile()
        android = self.output / 'android/app/src/main/java/com/dotcorr/counter/AppScreen.java'
        before = android.read_bytes()
        self.data['state']['count'] = 5
        self.compile(self.data, targets=('ios',))
        self.assertEqual(before, android.read_bytes())

    def test_untracked_source_is_never_overwritten(self):
        path = self.output / 'ios/App/Generated/RootView.swift'
        path.parent.mkdir(parents=True)
        path.write_text('existing source')
        with self.assertRaises(Conflict):
            self.compile()
        self.assertEqual('existing source', path.read_text())

    def test_symlink_and_traversal_rejected(self):
        with self.assertRaises(Conflict):
            synchronize(self.output, {'../bad': Artifact('x')}, 'a')
        link = self.output / 'ios'
        link.symlink_to(self.temp.name)
        with self.assertRaises(Conflict):
            self.compile()

    def test_failed_write_rolls_back(self):
        synchronize(self.output, {'a.txt': Artifact('old')}, 'a')
        from dcflight.sync import atomic_write
        calls = []
        def fail_once(path, data):
            calls.append(path.name)
            if path.name == 'b.txt' and calls.count('b.txt') == 1:
                raise OSError('disk failure')
            return atomic_write(path, data)
        manifest = (self.output / '.dcflight/state.json').read_bytes()
        with patch('dcflight.sync.atomic_write', fail_once), self.assertRaises(OSError):
            synchronize(self.output, {'a.txt': Artifact('new'), 'b.txt': Artifact('new')}, 'a')
        self.assertEqual('old', (self.output / 'a.txt').read_text())
        self.assertFalse((self.output / 'b.txt').exists())
        self.assertEqual(manifest, (self.output / '.dcflight/state.json').read_bytes())

    def test_runtime_independence_project_graph(self):
        self.compile()
        result = audit(self.output)
        self.assertTrue(result['passed'], result)
        all_source = '\n'.join(p.read_text() for p in self.output.rglob('*') if p.is_file() and '.dcflight' not in p.parts)
        self.assertNotIn('System.loadLibrary', all_source)
        self.assertNotIn('implementation(', all_source)
        self.assertNotIn('packageProductDependencies', all_source)
        self.assertFalse(list(self.output.rglob('*.dart')))
        self.assertFalse(list(self.output.rglob('*.js')))
        self.assertIn('Button("Add one", action: model.a_add)', all_source)
        self.assertIn('new android.widget.Button(activity)', all_source)

    def test_audit_detects_introduced_runtime(self):
        self.compile()
        (self.output / 'ios/App/User/Bad.swift').write_text('import JavaScriptCore')
        self.assertFalse(audit(self.output)['passed'])

    def test_escape_hatches_require_native_implementations(self):
        self.data['actions'].append({'id': 'share', 'op': 'native'})
        with self.assertRaisesRegex(ValueError, 'UserActions'):
            self.compile(self.data)

    def test_schema_is_reproducible(self):
        self.assertEqual(json.loads((ROOT / 'registry/app.schema.json').read_text()), self.registry.schema())

    def test_dart_rejects_execution_interpolation_and_duplicate_keys(self):
        for text in ["const app = execute();", "const app = {'x': 1, 'x': 2};", "const app = '$secret';", "const app = {}; main();", "const app = Ref(wrong: 'x');"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                DartParser(text).parse()
        with self.assertRaises(ValueError):
            read_json('{"version": 1, "version": 2}')

    def test_dry_run_does_not_change_existing_project(self):
        self.compile()
        self.data['state']['count'] = 12
        before = {str(p): p.read_bytes() for p in self.output.rglob('*') if p.is_file()}
        result = self.compile(self.data, dry_run=True)
        self.assertTrue(result['write'])
        after = {str(p): p.read_bytes() for p in self.output.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_backend_unknown_target_is_explicit_error(self):
        with self.assertRaisesRegex(ValueError, 'Unsupported target'):
            self.compile(targets=('web',))

    def test_mcp_protocol_and_validation(self):
        server = Server()
        self.assertIn('error', server.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}))
        self.assertIn('result', server.handle({'jsonrpc': '2.0', 'id': 2, 'method': 'initialize', 'params': {'protocolVersion': '2025-03-26'}}))
        tools = server.handle({'jsonrpc': '2.0', 'id': 3, 'method': 'tools/list'})['result']['tools']
        self.assertEqual(8, len(tools))  # registry_search, app_schema, validate_app, doctor, doctor_install, mcp_config, compile_app, design_guidance
        response = server.handle({'jsonrpc': '2.0', 'id': 4, 'method': 'tools/call', 'params': {'name': 'validate_app', 'arguments': {'app': self.data}}})
        self.assertFalse(response['result']['isError'])
        response = server.handle({'jsonrpc': '2.0', 'id': 5, 'method': 'tools/call', 'params': {'name': 'validate_app', 'arguments': {'app': {}}}})
        self.assertTrue(response['result']['isError'])
        self.assertIsNone(server.handle({'jsonrpc': '2.0', 'method': 'notifications/initialized'}))
        output = io.StringIO()
        serve(io.StringIO('not json\n[]\n'), output)
        self.assertEqual([-32700, -32600], [json.loads(line)['error']['code'] for line in output.getvalue().splitlines()])


if __name__ == '__main__':
    unittest.main()
