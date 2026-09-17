import json
from pathlib import Path
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.mcp import Server


class MCPCatalogTests(unittest.TestCase):
    def test_optional_catalog_tools_and_bounded_search(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'sdk.sqlite'
            with Catalog(path,write=True) as catalog:
                catalog.import_records('ios','Test','26',[{'id':'x','name':'nativeCall','emittable':False,
                    'unsupportedReasons':['fixture']}], {'fixture':True})
            server = Server(path)
            def call(method, **params):
                return server.handle({'jsonrpc':'2.0','id':1,'method':method,'params':params})['result']
            call('initialize')
            tools=call('tools/list')['tools']
            names=[tool['name'] for tool in tools]
            self.assertEqual(len(names),len(set(names)))
            self.assertEqual(set(names),{'registry_search','app_schema','validate_app',
                'sdk_android_invocation_schema','sdk_emit_operation','sdk_emit_sequence',
                'sdk_search','sdk_get','sdk_coverage','sdk_emit',
                'doctor','doctor_install','mcp_config','compile_app','design_guidance'})
            schema_result=call('tools/call',name='sdk_android_invocation_schema',arguments={})
            self.assertFalse(schema_result.get('isError',False))
            schema=json.loads(schema_result['content'][0]['text'])
            self.assertIn('typeArguments',schema['properties'])
            self.assertIn('constructedType',schema['properties'])
            result = call('tools/call',name='sdk_search',arguments={'query':'nativeCall'})
            self.assertEqual(json.loads(result['content'][0]['text'])['total'],1)
            self.assertTrue(call('tools/call',name='sdk_search',arguments={'limit':10000})['isError'])
            self.assertTrue(call('tools/call',name='sdk_emit',arguments={'invocation':{'platform':'ios','id':'x'}})['isError'])
            detail=call('tools/call',name='sdk_get',arguments={'platform':'ios','id':'x'})
            self.assertEqual(json.loads(detail['content'][0]['text'])['api']['unsupportedReasons'],['fixture'])

    def test_without_catalog_retains_semantic_tools(self):
        server=Server()
        server.handle({'jsonrpc':'2.0','id':1,'method':'initialize'})
        names=[tool['name'] for tool in server.handle({'jsonrpc':'2.0','id':2,'method':'tools/list'})['result']['tools']]
        self.assertTrue({'registry_search','app_schema','validate_app'} <= set(names))
        self.assertTrue({'doctor','doctor_install','mcp_config','compile_app'} <= set(names))
        self.assertEqual(len(names),len(set(names)))
