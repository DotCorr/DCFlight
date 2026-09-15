import json
import tempfile
import unittest
from pathlib import Path
from dcflight.mcp import Server, mcp_config, discover_catalog
from dcflight import mcp as mcp_module


class MCPAuthoringTests(unittest.TestCase):
    def setUp(self):
        self.server = Server()
        self.server.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'})

    def call(self, name, arguments=None):
        response = self.server.handle({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/call',
                                       'params': {'name': name, 'arguments': arguments or {}}})
        return response['result']

    def test_authoring_tools_listed_without_catalog(self):
        names = {tool['name'] for tool in self.server.tools}
        self.assertTrue({'doctor', 'doctor_install', 'mcp_config', 'compile_app'} <= names)

    def test_doctor_tool_reports_ready_or_missing(self):
        result = self.call('doctor')
        self.assertFalse(result.get('isError', False))
        report = json.loads(result['content'][0]['text'])
        self.assertIn('ready', report)
        self.assertIn('items', report)

    def test_mcp_config_clients(self):
        for client, expected in (('claude', 'mcpServers'), ('vscode', 'mcp'), ('cursor', 'mcpServers')):
            block = mcp_config(client)
            self.assertIn(expected, block)
        config = mcp_config('generic')['mcpServers']['dcflight']
        self.assertTrue(config['command'])
        self.assertIsInstance(config['args'], list)

    def test_compile_app_builds_native_projects(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'app.dart'
            source.write_text(
                "import 'package:dcflight_authoring/dcflight.dart';\n"
                "App buildApp() => App(id: 'com.example.mcp', name: 'MCP', "
                "root: Text('Hello MCP', id: 'hello'));")
            result = self.call('compile_app', {'source': str(source), 'outDir': str(root / 'native')})
            self.assertFalse(result.get('isError', False), result)
            payload = json.loads(result['content'][0]['text'])
            self.assertEqual(payload['targets'], ['ios', 'android'])
            self.assertGreater(payload['files'], 0)
            self.assertTrue((root / 'native' / 'ios' / 'App.xcodeproj' / 'project.pbxproj').is_file())
            self.assertTrue((root / 'native' / 'android' / 'app' / 'build.gradle').is_file())

    def test_compile_app_rejects_missing_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.call('compile_app', {'source': str(Path(tmp) / 'nope.dart'),
                                               'outDir': str(Path(tmp) / 'out')})
            self.assertTrue(result.get('isError'))

    def test_discover_catalog_reads_env(self):
        with tempfile.TemporaryDirectory() as tmp:
            catalog = Path(tmp) / 'sdk.sqlite'
            catalog.write_bytes(b'')
            with mock_env(DCFLIGHT_SDK_CATALOG=str(catalog)):
                self.assertEqual(discover_catalog(), catalog)
        self.assertIsNone(discover_catalog())


class mock_env:
    def __init__(self, **values):
        self.values = values

    def __enter__(self):
        self._patch = unittest.mock.patch.dict('os.environ', self.values, clear=False)
        self._patch.start()

    def __exit__(self, *args):
        self._patch.stop()


if __name__ == '__main__':
    unittest.main()
