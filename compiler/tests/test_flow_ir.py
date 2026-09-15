import copy
import unittest
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.flow_ir import RequestEffect,Projection


def fixture():
    return {'version':2,'id':'com.example.flow','name':'Flow','state':{'username':'','token':'','status':0,'ready':True},
        'root':{'id':'host','type':'navigationStack','props':{'initialRoute':'home'}},
        'routes':[{'id':'home','title':'Home','body':{'id':'send','type':'button','props':{'text':'Send'},'action':'submit','enabledWhen':{'ref':'ready'}}}],
        'transport':{'baseUrl':'http://localhost:8765','development':True},'initialAction':'submit',
        'flowActions':[{'id':'submit','cases':[{'code':0,'effects':[{'op':'request','id':'request','method':'POST','path':'/v1/auth/login','body':{'username':{'ref':'username'}},'outputs':{'token':['token']},'success':'finished','failure':'finished','statusTarget':'status'}]}]},
                       {'id':'finished','cases':[{'code':0,'effects':[{'op':'set','target':'ready','value':True}]}]}]}

class FlowIRTests(unittest.TestCase):
    def test_typed_effects_and_namespace(self):
        app=lower(fixture(),Registry())
        self.assertEqual(app.actions,())
        self.assertEqual(app.initial_action,'submit')
        self.assertIsInstance(app.flow_actions[0].cases[0].effects[0],RequestEffect)
        self.assertEqual(app.routes[0].body.enabled_when.name,'ready')
    def test_invalid_and_insecure_inputs_fail_before_native_generation(self):
        cases=[]
        d=fixture();d['transport']['baseUrl']='http://example.com';cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'][0]['outputs']={'missing':['token']};cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'][0]['failure']='unknown';cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'].append({'op':'set','target':'ready','value':False});cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'][0]['bearer']={'ref':'ready'};cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'][0]['path']='//attacker/path';cases.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'][0]['outputs']={'status':['status']};cases.append(d)
        for d in cases:
            with self.subTest(data=d),self.assertRaises(ValueError):lower(d,Registry())
    def test_synchronous_cycles_rejected(self):
        d=fixture();d['flowActions'][1]['cases'][0]['effects']=[{'op':'invoke','action':'finished'}]
        with self.assertRaisesRegex(ValueError,'cycle'):lower(d,Registry())
    def test_secure_failure_must_be_authored_and_string_typed(self):
        d=fixture();d['flowActions'][0]['cases'][0]['effects']=[{'op':'secure','operation':'write','key':'session','target':'token','failure':'finished'}]
        app=lower(d,Registry());self.assertEqual(app.flow_actions[0].cases[0].effects[0].failure,'finished')
        d['flowActions'][0]['cases'][0]['effects'][0]['target']='ready'
        with self.assertRaises(ValueError):lower(d,Registry())
    def test_shared_dart_decision_abi_checked(self):
        d=fixture();d['logic']={'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':'decide','parameters':['uint32'],'returns':'uint32'}]}
        d['flowActions'][0].update(function='decide',arguments=[{'length':{'ref':'username'}}])
        app=lower(d,Registry());self.assertIsInstance(app.flow_actions[0].arguments[0],Projection)
        d['flowActions'][0]['arguments']=[{'ref':'username'}]
        with self.assertRaisesRegex(ValueError,'type mismatch'):lower(d,Registry())
