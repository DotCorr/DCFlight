import unittest
from dataclasses import replace
from dcflight.ir import Node,State,Literal,ScalarType,Reference,Style
from dcflight.flow_ir import FlowAction,FlowCase,SetEffect,RequestEffect,ResponseOutput,SecureEffect,CancelEffect,Transport
from dcflight.backends.android_routed import AndroidRouted
from test_android_routed import fixture,lit


def flow_fixture():
    app=fixture()
    request=RequestEffect('request','POST','/v1/action',(('input',Reference('value',ScalarType.STRING)),),None,(ResponseOutput('token',('data','token')),ResponseOutput('count',('count',))),'success','failure','status')
    flows=(FlowAction('submit',None,(),(FlowCase(0,(request,)),)),FlowAction('success',None,(),(FlowCase(0,(SecureEffect('write','session','token','failure'),)),)),FlowAction('failure',None,(),(FlowCase(0,(SetEffect('message',lit('Authored failure')),CancelEffect())),)))
    field=Node('password','secureField',(('value',Reference('value',ScalarType.STRING)),('placeholder',lit('Authored password'))),(),style=Style(padding=8),enabled_when=Reference('enabled',ScalarType.BOOL))
    body=replace(app.routes[0].body,children=(field,replace(app.routes[0].body.children[1],action='submit',enabled_when=Reference('enabled',ScalarType.BOOL))))
    states=tuple(State(name,lit('')) for name in ('value','token','message'))+(State('count',Literal(0,ScalarType.INT)),State('status',Literal(0,ScalarType.INT)),State('enabled',Literal(True,ScalarType.BOOL)))
    return replace(app,states=states,routes=(replace(app.routes[0],body=body),app.routes[1]),flow_actions=flows,transport=Transport('http://localhost:8765',True),initial_action='submit')


class AndroidFlowTests(unittest.TestCase):
    def setUp(self):
        self.files=AndroidRouted().generate(flow_fixture(),None)
        self.source=self.files['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.adapter=self.files['android/app/src/main/java/com/example/routes/NativeEffects.kt'].content

    def test_shared_dispatch_and_atomic_outputs(self):
        self.assertIn('fun f_submit(navigate: (String) -> Unit)',self.source)
        self.assertIn('effects.request("POST","/v1/action"',self.source)
        self.assertLess(self.source.index('val output1 = effects.integer'),self.source.index('s_token = output0'))
        self.assertIn('catch(error: Exception) { s_status = 0',self.source)
        self.assertIn('f_failure(navigate); return@request',self.source)
        self.assertIn('effects.write("session",s_token)',self.source)
        self.assertIn('catch(error: Exception) { f_failure(navigate); return }',self.source)
        self.assertIn('if(!model.initialDispatched)',self.source)
        self.assertIn('Authored failure',self.source)
        self.assertNotIn('Authored failure',self.adapter)

    def test_secrets_are_not_parceled_and_password_is_native(self):
        self.assertIn('class AuthoredState(private val context: android.content.Context) : androidx.lifecycle.ViewModel()',self.source)
        self.assertNotIn('saver=listSaver<AuthoredState',self.source)
        self.assertIn('override fun onCleared() { effects.close();',self.source)
        self.assertIn('PasswordVisualTransformation()',self.source)
        self.assertIn('KeyboardType.Password',self.source)
        self.assertIn('enabled=model.s_enabled',self.source)
        self.assertIn('android:allowBackup="false"',self.files['android/app/src/main/AndroidManifest.xml'].content)

    def test_bounded_native_io_and_strict_decoding(self):
        for token in ('newSingleThreadExecutor','postDelayed(timeout,25000)','8388608','instanceFollowRedirects=false','token==generation.get()','delivered.compareAndSet(false,true)','AndroidKeyStore','AES/GCM/NoPadding','http://10.0.2.2:8765','as? String','Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()'):
            self.assertIn(token,self.adapter)
        self.assertIn('main.removeCallbacksAndMessages(null)',self.adapter)
        self.assertNotIn('WebView',self.adapter)

    def test_secure_origin_isolation_strict_utf8_and_shutdown(self):
        changed=replace(flow_fixture(),transport=Transport('https://second.example',False))
        other=AndroidRouted().generate(changed,None)['android/app/src/main/java/com/example/routes/NativeEffects.kt'].content
        import re
        first_scope=re.search(r'secure_effects_([a-f0-9]{64})',self.adapter).group(1)
        other_scope=re.search(r'secure_effects_([a-f0-9]{64})',other).group(1)
        self.assertNotEqual(first_scope,other_scope)
        self.assertIn('.secure.effects.'+first_scope,self.adapter)
        self.assertIn('CodingErrorAction.REPORT',self.adapter)
        self.assertIn('if(closed)return',self.adapter)
        self.assertIn('RejectedExecutionException',self.adapter)
        self.assertIn('if(method!="GET"&&method!="HEAD")',self.adapter)

    def test_native_light_chrome_and_placeholder_style(self):
        activity=self.files['android/app/src/main/java/com/example/routes/MainActivity.kt'].content
        self.assertIn('isAppearanceLightStatusBars = true',activity)
        self.assertIn('isAppearanceLightNavigationBars = true',activity)
        self.assertIn('modifier=Modifier.alpha(0.5f),style=',self.source)

    def test_path_template_uses_strict_native_percent_encoding(self):
        from dcflight.flow_ir import PathTemplate
        app=flow_fixture();flow=app.flow_actions[0];case=flow.cases[0]
        request=replace(case.effects[0],path=PathTemplate((lit('/v1/people/'),Reference('value',ScalarType.STRING),lit('?page=1'))))
        app=replace(app,flow_actions=(replace(flow,cases=(replace(case,effects=(request,)),)),)+app.flow_actions[1:])
        files=AndroidRouted().generate(app,None)
        source=files['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        adapter=files['android/app/src/main/java/com/example/routes/NativeEffects.kt'].content
        self.assertIn('"/v1/people/"+effects.pathSegment(s_value.toString())+"?page=1"',source)
        self.assertIn('try { effects.request(',source)
        self.assertIn('fun pathSegment(value:String)',adapter)
        self.assertIn('Charsets.UTF_8.newEncoder()',adapter)
        self.assertIn("out.append('%')",adapter)

    def test_typed_collections_atomic_decode_and_authored_repeat(self):
        from dcflight.collection_ir import Collection,CollectionField,FieldReference
        app=flow_fixture()
        collection=Collection('people','id',(CollectionField('id',ScalarType.STRING),CollectionField('name',ScalarType.STRING,lit('Unnamed')),CollectionField('age',ScalarType.INT)))
        row=Node('personName','text',(('text',FieldReference('people','name',ScalarType.STRING)),),())
        repeat=Node('peopleRows','repeat',(('collection',lit('people')),('selection',Reference('value',ScalarType.STRING))),(row,),action='submit')
        flow=app.flow_actions[0];case=flow.cases[0]
        request=replace(case.effects[0],outputs=(ResponseOutput('people',('people',)),ResponseOutput('token',('token',))))
        app=replace(app,collections=(collection,),routes=(replace(app.routes[0],body=repeat),app.routes[1]),flow_actions=(replace(flow,cases=(replace(case,effects=(request,)),)),)+app.flow_actions[1:])
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('data class Record_people(val v_id:String,val v_name:String,val v_age:Int)',source)
        self.assertIn('var c_people by mutableStateOf<List<Record_people>>(emptyList())',source)
        self.assertIn('model.c_people.forEach { row_people -> key("peopleRows",row_people.v_id)',source)
        self.assertIn('model.s_value=row_people.v_id; model.f_submit(',source)
        self.assertIn('Text(row_people.v_name',source)
        self.assertIn('if(row.isNull("name")) "Unnamed" else effects.string(row,listOf("name"))',source)
        self.assertIn('if(!keys.add(it.v_id)) throw IllegalArgumentException("response_duplicate_key")',source)
        self.assertLess(source.index('val output1 = effects.string'),source.index('c_people = output0'))

    def test_clear_collection_is_native_assignment(self):
        from dcflight.flow_ir import ClearCollectionEffect
        from dcflight.backends.android_flow import AndroidFlow
        from dcflight.backends.android_routed import quoted
        self.assertEqual('c_people = emptyList()',AndroidFlow(flow_fixture(),quoted).effect(ClearCollectionEffect('people')))

    def test_append_validates_existing_keys_before_assignment(self):
        from dcflight.collection_ir import Collection,CollectionField
        from dcflight.backends.android_flow import AndroidFlow
        from dcflight.backends.android_routed import quoted
        app=replace(flow_fixture(),collections=(Collection('people','id',(CollectionField('id',ScalarType.STRING),)),))
        request=replace(app.flow_actions[0].cases[0].effects[0],outputs=(ResponseOutput('people',('people',),'append'),ResponseOutput('token',('token',))))
        source=AndroidFlow(app,quoted).effect(request)
        self.assertIn('val priorKeys=c_people.map { it.v_id }.toHashSet()',source)
        self.assertIn('response_duplicate_existing_key',source)
        self.assertIn('c_people + incoming',source)
        self.assertLess(source.index('response_duplicate_existing_key'),source.index('c_people = output0'))
        self.assertLess(source.index('val output1'),source.index('c_people = output0'))
