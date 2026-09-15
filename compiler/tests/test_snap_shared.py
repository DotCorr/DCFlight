"""Evaluate the real shared app, then assert its author-owned protocol decisions."""
import shutil
import unittest
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated
from dcflight.navigation_ir import lower_routed
from dcflight.registry import Registry
from dcflight.ir import Reference, ScalarType
from dcflight.flow_ir import RequestEffect,SecureEffect,CancelEffect,NavigateEffect,Projection,LogicCallEffect,InvokeEffect

class SnapSharedSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        dart=shutil.which('dart')
        if not dart:raise unittest.SkipTest('Dart SDK required')
        cls.app=lower_routed(load_evaluated(Path(__file__).resolve().parents[1]/'examples/snap-shared/app.dart',dart=dart),Registry())
        cls.flows={f.id:f for f in cls.app.flow_actions}

    def test_real_account_routes_and_initial_restore(self):
        self.assertEqual(self.app.initial_action,'restore')
        self.assertEqual({r.id for r in self.app.routes},{'login','register','profile','home','chats','people','conversation','composer','stories','story','cameraCapture','map'})
        self.assertNotIn('inbox',{n.capability for n in self.app.nodes()})
        self.assertEqual(self.app.transport.base_url,'http://localhost:8765')

    def test_requests_and_decisions_authored_once(self):
        self.assertEqual(self.flows['login'].function,'decideLogin')
        self.assertEqual(self.flows['login'].arguments[0],Reference('username',ScalarType.STRING))
        self.assertIsInstance(self.flows['login'].arguments[1],Projection)
        self.assertEqual(self.flows['login'].failure,'authInputFailed')
        request=next(e for c in self.flows['sendRegister'].cases for e in c.effects if isinstance(e,RequestEffect))
        self.assertEqual(request.path,'/v1/auth/register')
        self.assertEqual(request.success,'authenticated')
        self.assertEqual({o.target for o in request.outputs},{'token','userId','displayName','username'})
        self.assertEqual(request.bearer,None)
        profile=next(e for c in self.flows['saveProfile'].cases for e in c.effects if isinstance(e,RequestEffect))
        self.assertEqual(profile.method,'PATCH');self.assertEqual(profile.path,'/v1/me')
        self.assertEqual(profile.bearer.name,'token')

    def test_both_auth_flows_validate_then_canonicalize_before_request(self):
        contract=next(f for f in self.app.logic.functions if f.name=='canonicalHandle')
        self.assertEqual([p.value for p in contract.parameters],['utf8'])
        self.assertEqual(contract.returns.value,'utf8')
        self.assertEqual(contract.max_output_bytes,24)
        def assert_no_request_from(flow_id):
            pending=[flow_id];seen=set()
            while pending:
                current=pending.pop()
                if current in seen:continue
                seen.add(current)
                flow=self.flows[current]
                if flow.failure:pending.append(flow.failure)
                for case in flow.cases:
                    for effect in case.effects:
                        self.assertNotIsInstance(effect,RequestEffect)
                        if isinstance(effect,InvokeEffect):pending.append(effect.action)
                        if isinstance(effect,LogicCallEffect):pending.extend((effect.success,effect.failure))
        for name,request_flow in [('login','sendLogin'),('register','sendRegister')]:
            with self.subTest(flow=name):
                validation=self.flows[name]
                self.assertEqual(validation.function,'decideLogin' if name=='login' else 'decideRegister')
                self.assertEqual(validation.arguments[0],Reference('username',ScalarType.STRING))
                self.assertEqual(validation.failure,'authInputFailed')
                success=next(c for c in validation.cases if c.code==3)
                self.assertEqual(len(success.effects),1)
                call=success.effects[0];self.assertIsInstance(call,LogicCallEffect)
                self.assertEqual(call.function,'canonicalHandle')
                self.assertEqual(call.arguments,(Reference('username',ScalarType.STRING),))
                self.assertEqual(call.target,'canonicalUsername')
                self.assertEqual(call.success,request_flow)
                self.assertEqual(call.failure,'authInputFailed')
                for case in validation.cases:
                    if case.code!=3:
                        self.assertFalse(any(isinstance(e,(RequestEffect,LogicCallEffect,InvokeEffect)) for e in case.effects))
                assert_no_request_from(validation.failure)
                assert_no_request_from(call.failure)
                effects=self.flows[request_flow].cases[0].effects
                requests=[e for e in effects if isinstance(e,RequestEffect)]
                self.assertEqual(len(requests),1);self.assertIs(effects[-1],requests[0])
                request=requests[0]
                self.assertEqual(request.path,'/v1/auth/'+name)
                self.assertEqual(dict(request.body)['username'],Reference('canonicalUsername',ScalarType.STRING))
                self.assertEqual(dict(request.body)['password'],Reference('password',ScalarType.STRING))
                if name=='register':self.assertEqual(dict(request.body)['display_name'],Reference('displayName',ScalarType.STRING))
                self.assertEqual(request.success,'authenticated');self.assertEqual(request.failure,'authFailed')

    def test_logout_secure_storage_and_revocation_order(self):
        effects=self.flows['logout'].cases[0].effects
        self.assertIsInstance(effects[0],CancelEffect)
        self.assertIsInstance(effects[-1],RequestEffect)
        self.assertEqual(effects[-1].bearer.name,'revocationToken')
        self.assertEqual(effects[-1].failure,'logoutFailed')
        secure=next(i for i,e in enumerate(effects) if isinstance(e,SecureEffect))
        navigation=next(i for i,e in enumerate(effects) if isinstance(e,NavigateEffect))
        self.assertLess(secure,navigation)
        self.assertEqual(effects[secure].failure,'logoutStorageFailed')

    def test_collections_chat_protocol_and_private_cleanup(self):
        from dcflight.flow_ir import ClearCollectionEffect,PathTemplate
        self.assertEqual({c.name for c in self.app.collections},{'searchResults','friends','requests','conversations','messages','stories','locations'})
        request=self.flows['loadMessages'].cases[0].effects[-1]
        self.assertIsInstance(request.path,PathTemplate)
        self.assertEqual(request.outputs[0].mode,'append')
        self.assertEqual(request.outputs[1].target,'messageCursor')
        self.assertEqual(self.flows['sendMessage'].function,'decideMessage')
        self.assertEqual(self.flows['refreshRequests'].cases[0].effects[-1].path, '/v1/friend-requests?direction=incoming')
        for flow,case in [('logout',0),('restored',0),('sessionFailed',1)]:
            effects=next(c.effects for c in self.flows[flow].cases if c.code==case)
            self.assertEqual({e.target for e in effects if isinstance(e,ClearCollectionEffect)}, {c.name for c in self.app.collections})
        self.assertEqual(next(a.operation for a in self.app.navigation_actions if a.id=='showLogin'),'resetRoot')
        self.assertEqual(next(a.operation for a in self.app.navigation_actions if a.id=='showHome'),'resetRoot')

    def test_five_shared_tabs_and_explicit_device_policy(self):
        from dcflight.device_ir import PermissionEffect,LocationEffect
        home=next(r for r in self.app.routes if r.id=='home')
        self.assertEqual([c.props()['title'].value for c in home.body.children],['Camera','Chat','Stories','Map','You'])
        self.assertEqual(self.app.map_config.android_module,'maplibre')
        self.assertEqual(self.flows['locationMeasured'].function,'decideLocation')
        self.assertEqual(self.flows['captureStory'].function,'decideCapture')
        self.assertIsInstance(self.flows['shareLocation'].cases[0].effects[-1],PermissionEffect)
        self.assertIsInstance(self.flows['locationPermissionGranted'].cases[0].effects[-1],LocationEffect)
        stop=self.flows['stopSharing'].cases[0].effects
        self.assertIsInstance(stop[0],CancelEffect)
        self.assertEqual(stop[-1].failure,'stopSharingFailed')
