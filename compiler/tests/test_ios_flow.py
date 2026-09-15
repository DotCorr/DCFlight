import dataclasses
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from dcflight.ir import State,Literal,Reference,ScalarType
from dcflight.flow_ir import FlowAction,FlowCase,SetEffect,NavigateEffect,RequestEffect,ResponseOutput,SecureEffect,InvokeEffect,CancelEffect,Transport
from dcflight.backends.ios_routed import generate
from dcflight.backends.ios_flow import HELPERS,value
from dcflight.registry import Registry
from test_ios_routed import fixture,text


def flow_fixture():
    app=fixture()
    states=(State('token',text('')),State('name',text('')),State('status',Literal(0,ScalarType.INT)),State('count',Literal(0,ScalarType.INT)),State('ready',Literal(False,ScalarType.BOOL)))
    request=RequestEffect('load','GET','/v1/me',(),Reference('token',ScalarType.STRING),(ResponseOutput('name',('user','name')),ResponseOutput('count',('count',)),ResponseOutput('ready',('ready',))),'ok','failed','status')
    flows=(FlowAction('restore',None,(),(FlowCase(0,(SecureEffect('read','session','token','failed'),InvokeEffect('load'))),)),FlowAction('load',None,(),(FlowCase(0,(request,)),)),FlowAction('ok',None,(),(FlowCase(0,(NavigateEffect('forward'),)),)),FlowAction('failed',None,(),(FlowCase(0,(SetEffect('ready',Literal(False,ScalarType.BOOL)),)),)),FlowAction('stop',None,(),(FlowCase(0,(CancelEffect(),SecureEffect('delete','session','token','failed'))),)))
    route=app.routes[0];first=route.body.children[1]
    body=dataclasses.replace(route.body,children=(*route.body.children[:1],dataclasses.replace(first,action='load'),*route.body.children[2:]))
    return dataclasses.replace(app,states=states,routes=(dataclasses.replace(route,body=body),*app.routes[1:]),flow_actions=flows,transport=Transport('http://127.0.0.1:8765',True),initial_action='restore')


class IOSFlowTests(unittest.TestCase):
    def test_direct_effects_atomic_outputs_cancellation_and_initial_action(self):
        files=generate(flow_fixture(),Registry());model=files['ios/App/Generated/AppModel.swift'].content
        self.assertIn('model.f_load(router.flowNavigation)',files['ios/App/Generated/Nodes/n_go.swift'].content)
        self.assertIn('model.startInitialFlow(router.flowNavigation)',files['ios/App/Generated/NavigationRouter.swift'].content)
        self.assertIn('func navigate(_ action: String)',files['ios/App/Generated/NavigationRouter.swift'].content)
        self.assertIn('initialFlowStarted = true',model)
        self.assertIn('self.f_failed(navigate); return',model)
        self.assertIn('generation==self.requestGeneration',model)
        self.assertIn('requestTask?.cancel()',model)
        self.assertLess(model.index('let output2 ='),model.index('self.s_name = output0'))
        self.assertIn('self.s_status = 0',model)
        for term in ('SocialSession','CameraScreen','Request failed','Sign in'):
            self.assertNotIn(term,model)
        self.assertIn('bytes.task.cancel()',HELPERS)
        self.assertIn('8_388_608',HELPERS)
        self.assertIn('completionHandler(nil)',HELPERS)

    def test_request_mapping_mutation_changes_native_request_and_success(self):
        app=flow_fixture();flow=app.flow_actions[1];request=flow.cases[0].effects[0]
        changed=dataclasses.replace(request,path='/v1/other',method='POST',body=(('authored',text('value')),),success='stop')
        app=dataclasses.replace(app,flow_actions=(app.flow_actions[0],dataclasses.replace(flow,cases=(FlowCase(0,(changed,)),)),*app.flow_actions[2:]))
        model=generate(app,Registry())['ios/App/Generated/AppModel.swift'].content
        self.assertIn('http://127.0.0.1:8765/v1/other',model)
        self.assertIn('["authored": "value"]',model)
        self.assertIn('method: "POST"',model)
        self.assertIn('self.f_stop(navigate)',model)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('swift'),'Native Foundation required')
    def test_native_json_projection_rejects_wrong_types_before_assignment(self):
        helper=HELPERS.split('final class NativeHTTPTransport')[0]
        code=helper+'''
func rejected(_ operation: () throws -> Void) { do { try operation(); fatalError("Unexpected acceptance") } catch {} }
let root=try JSONSerialization.jsonObject(with:Data("{\\"s\\":\\"hello\\",\\"i\\":42,\\"b\\":true,\\"f\\":1.5,\\"large\\":2147483648}".utf8))
precondition(try NativeJSONScalar.string(root,path:["s"]) == "hello")
precondition(try NativeJSONScalar.int(root,path:["i"]) == 42)
precondition(try NativeJSONScalar.bool(root,path:["b"]))
rejected { _ = try NativeJSONScalar.int(root,path:["b"]) }
rejected { _ = try NativeJSONScalar.bool(root,path:["i"]) }
rejected { _ = try NativeJSONScalar.int(root,path:["f"]) }
rejected { _ = try NativeJSONScalar.int(root,path:["large"]) }
rejected { _ = try NativeJSONScalar.string(root,path:["missing"]) }
'''
        # precondition's autoclosure cannot throw; evaluate each check first.
        code=code.replace('precondition(try NativeJSONScalar.string(root,path:["s"]) == "hello")','let s = try NativeJSONScalar.string(root,path:["s"]);precondition(s == "hello")').replace('precondition(try NativeJSONScalar.int(root,path:["i"]) == 42)','let i = try NativeJSONScalar.int(root,path:["i"]);precondition(i == 42)').replace('precondition(try NativeJSONScalar.bool(root,path:["b"]))','let b = try NativeJSONScalar.bool(root,path:["b"]);precondition(b)')
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'test.swift';path.write_text(code)
            result=subprocess.run(['swift',str(path)],capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)

    def test_literal_source_like_text_is_never_rewritten(self):
        self.assertEqual(value(text('model.s_token')), '"model.s_token"')
        self.assertEqual(value(Reference('token',ScalarType.STRING)), 'self.s_token')
        source=generate(flow_fixture(),Registry())['ios/App/Generated/NativeEffects.swift'].content
        self.assertIn('secureNamespace = "http://127.0.0.1:8765"',source)
        self.assertIn('bundle+"."+NativeEffectConfiguration.secureNamespace',source)
