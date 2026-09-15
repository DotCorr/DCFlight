import copy
import unittest
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.navigation_ir import RoutedApplication,schema


def fixture():
    return {'version':2,'id':'com.example.routes','name':'Shared','root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
        'navigationActions':[{'id':'openSheet','op':'present','route':'settings'}],
        'routes':[{'id':'home','title':'Home','body':{'id':'open','type':'button','props':{'text':'Settings'},'action':'openSheet'}},
                  {'id':'settings','title':'Settings','presentation':'sheet','body':{'id':'text','type':'text','props':{'text':'One source'}}}]}

class NavigationIRTests(unittest.TestCase):
    def test_typed_route_and_action_not_native_escape_hatches(self):
        app=lower(fixture(),Registry())
        self.assertIsInstance(app,RoutedApplication)
        self.assertEqual(app.actions,())
        self.assertEqual(app.navigation_actions[0].operation,'present')
        self.assertEqual(len(app.nodes()),3)

    def test_wrong_presentation_and_unknown_routes_rejected(self):
        for operation,route in [('push','settings'),('present','home'),('present','missing')]:
            data=fixture();data['navigationActions'][0].update(op=operation,route=route)
            with self.assertRaises(ValueError):lower(data,Registry())

    def test_stable_identity_unique_across_routes(self):
        data=fixture();data['routes'][1]['body']['id']='open'
        with self.assertRaisesRegex(ValueError,'unique across'):lower(data,Registry())

    def test_recursive_initial_hosts_rejected_but_push_cycles_allowed(self):
        data=fixture();data['routes'][0]['body']={'id':'inner','type':'navigationStack','props':{'initialRoute':'home'}}
        with self.assertRaisesRegex(ValueError,'Recursive'):lower(data,Registry())
        data=fixture();data['navigationActions'][0].update(op='push',route='home')
        self.assertIsInstance(lower(data,Registry()),RoutedApplication)

    def test_template_and_undeclared_parameter_shortcuts_rejected(self):
        data=fixture();data['routes'][0]['parameters']={'id':'string'}
        with self.assertRaises(ValueError):lower(data,Registry())
        data=fixture();data['routes'][0]['body']={'id':'hiddenScreen','type':'inbox','props':{}}
        with self.assertRaises(ValueError):lower(data,Registry())

    def test_authored_changes_reach_both_emitters(self):
        from dcflight.backends.ios_routed import generate
        from dcflight.backends.android_routed import AndroidRouted
        data=fixture();data['routes'][0]['body']['props']['text']='Authored wording only'
        app=lower(data,Registry())
        for emitter in (generate,AndroidRouted().generate):
            source='\n'.join(a.content for a in emitter(app,Registry()).values() if isinstance(a.content,str))
            self.assertIn('Authored wording only',source)
            self.assertNotIn('Make yourself at home',source)
            self.assertNotIn('New here?',source)

    def test_schema_restricts_supported_routing_shape(self):
        result=schema(Registry())
        self.assertEqual(result['properties']['version'],{'const':2})
        self.assertNotIn('service',result['properties'])
        self.assertIn('routes',result['required'])

    def test_compiled_node_map_points_to_actual_native_sources(self):
        import json
        import tempfile
        from pathlib import Path
        from dcflight.compiler import compile_app
        with tempfile.TemporaryDirectory() as directory:
            compile_app('unused.json',directory,document=fixture())
            root=Path(directory)
            mapping=json.loads((root/'.dcflight/nodes.json').read_text())
            for node in mapping.values():
                for platform in ('ios','android'):
                    self.assertTrue((root/node[platform].split('#')[0]).is_file(),node)

    def test_mcp_exposes_selected_authoring_schema(self):
        import json
        from dcflight.mcp import Server
        server=Server()
        server.handle({'jsonrpc':'2.0','id':1,'method':'initialize'})
        def request(version):
            return server.handle({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'app_schema','arguments':{'version':version}}})['result']
        result=request(2)
        self.assertFalse(result['isError'])
        self.assertEqual(json.loads(result['content'][0]['text'])['properties']['version'],{'const':2})
        self.assertTrue(request(3)['isError'])

    def test_source_receipt_changes_with_authored_input(self):
        import json
        import tempfile
        from pathlib import Path
        from dcflight.compiler import compile_app
        with tempfile.TemporaryDirectory() as directory:
            data=fixture()
            compile_app('unused.json',directory,document=data)
            receipt=Path(directory)/'.dcflight/source.json'
            before=json.loads(receipt.read_text())
            self.assertEqual(before['targetsGeneratedThisRun'],['ios','android'])
            data['routes'][0]['body']['props']['text']='Changed centrally'
            compile_app('unused.json',directory,document=data)
            after=json.loads(receipt.read_text())
            self.assertNotEqual(before['documentSha256'],after['documentSha256'])
            self.assertNotEqual(before['irSha256'],after['irSha256'])
            self.assertNotIn('Changed centrally',receipt.read_text())

    def test_single_target_receipt_preserves_stale_other_platform(self):
        import json
        import tempfile
        from pathlib import Path
        from dcflight.compiler import compile_app
        from dcflight.audit import source_consistency
        with tempfile.TemporaryDirectory() as directory:
            data=fixture()
            compile_app('unused.json',directory,document=data)
            receipt=Path(directory)/'.dcflight/source.json'
            before=json.loads(receipt.read_text())['targets']
            self.assertEqual(before['ios'],before['android'])
            self.assertEqual(source_consistency(directory)['status'],'matched')
            data['routes'][0]['body']['props']['text']='New iOS revision'
            compile_app('unused.json',directory,targets=('ios',),document=data)
            after=json.loads(receipt.read_text())['targets']
            self.assertEqual(before['android'],after['android'])
            self.assertNotEqual(after['ios'],after['android'])
            self.assertEqual(source_consistency(directory)['status'],'mismatched')
            compile_app('unused.json',directory,targets=('android',),document=data)
            aligned=json.loads(receipt.read_text())['targets']
            self.assertEqual(aligned['ios'],aligned['android'])
            self.assertEqual(source_consistency(directory)['status'],'matched')

    def test_node_identity_collisions_rejected_on_case_insensitive_filesystems(self):
        data=fixture();data['routes'][1]['body']['id']='Open'
        with self.assertRaisesRegex(ValueError,'unique across'):lower(data,Registry())

    def test_logic_only_change_is_detected_without_document_change(self):
        import json
        import tempfile
        from unittest.mock import patch
        from dcflight.compiler import compile_app
        from dcflight.audit import source_consistency
        from dcflight.backends import Artifact
        revision = ['a' * 64]
        def logic(app, source, targets):
            return {'.dcflight/logic.json': Artifact(json.dumps({'libraries': {}, 'builds': [
                {'target': target+'-arm64', 'authorSourceSha256': revision[0], 'preludeSha256': 'b' * 64}
                for target in targets]}))}
        with tempfile.TemporaryDirectory() as directory, patch('dcflight.compiler.generate_logic', side_effect=logic):
            compile_app('unused.json',directory,document=fixture())
            self.assertEqual(source_consistency(directory)['status'],'matched')
            revision[0] = 'c' * 64
            compile_app('unused.json',directory,targets=('android',),document=fixture())
            self.assertEqual(source_consistency(directory)['status'],'mismatched')
