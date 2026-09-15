import copy,json,os,shutil,tempfile,unittest
from pathlib import Path
from dcflight.ir import ABIType,LogicFunction,ScalarType
from dcflight.registry import Registry
from dcflight.validate import lower,Diagnostic
from dcflight.navigation_ir import schema
from dcflight.frontends import DartParser
from dcflight.evaluated_frontend import load_evaluated
from dcflight.shared_logic import abi_declaration,swift_utf8_wrapper,android_utf8_wrapper


def fixture():
    return {'version':2,'id':'com.example.result','name':'Result','state':{'input':'é\0🌍','output':'unchanged','status':'ready'},
      'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':'transform','parameters':['utf8'],'returns':'utf8','maxOutputBytes':64}]},
      'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
      'routes':[{'id':'home','title':'Result','body':{'id':'label','type':'text','props':{'text':{'ref':'output'}}}}],
      'flowActions':[{'id':'invoke','cases':[{'code':0,'effects':[{'op':'logicCall','function':'transform','arguments':[{'ref':'input'}],'target':'output','success':'done','failure':'failed'}]}]},
                     {'id':'done','cases':[{'code':0,'effects':[{'op':'set','target':'status','value':'success'}]}]},
                     {'id':'failed','cases':[{'code':0,'effects':[{'op':'set','target':'status','value':'failure'}]}]}]}

class UTF8ResultTests(unittest.TestCase):
    def test_typed_contract_and_physical_abi(self):
        app=lower(fixture(),Registry());f=app.logic.functions[0]
        self.assertEqual(f.returns,ABIType.UTF8);self.assertEqual(f.max_output_bytes,64)
        effect=app.flow_actions[0].cases[0].effects[0]
        self.assertEqual(type(effect).__name__,'LogicCallEffect');self.assertEqual(effect.arguments[0].type,ScalarType.STRING)
        self.assertEqual(abi_declaration(f),'uint32_t transform(uint64_t a0, uint32_t a1, uint64_t a2, uint32_t a3);')
    def test_schema_and_semantic_capacity_limits(self):
        import jsonschema
        for capacity in (None,0,-1,True,1048577,'64'):
            d=fixture()
            if capacity is None:del d['logic']['functions'][0]['maxOutputBytes']
            else:d['logic']['functions'][0]['maxOutputBytes']=capacity
            with self.subTest(capacity=capacity):
                with self.assertRaises(Diagnostic):lower(d,Registry())
                with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(d,schema(Registry()))
        d=fixture();d['logic']['functions'][0]['returns']='int32'
        with self.assertRaisesRegex(Diagnostic,'maxOutputBytes'):lower(d,Registry())
        with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(d,schema(Registry()))
        jsonschema.validate(fixture(),schema(Registry()))
    def test_terminal_type_and_graph_validation(self):
        variants=[]
        for key,value in [('function','unknown'),('target','absent'),('arguments',[1]),('failure','missing'),('success','invoke')]:
            d=fixture();d['flowActions'][0]['cases'][0]['effects'][0][key]=value;variants.append(d)
        d=fixture();d['flowActions'][0]['cases'][0]['effects'].append({'op':'set','target':'status','value':'wrong'});variants.append(d)
        d=fixture();d['state']['output']=0;variants.append(d)
        d=fixture();d['flowActions'][2]['cases'][0]['effects']=[{'op':'invoke','action':'invoke'}];variants.append(d)
        d=fixture();d['logic']['functions'][0]['parameters']=['uint64'];variants.append(d)
        for d in variants:
            with self.subTest(document=d),self.assertRaises(Diagnostic):lower(d,Registry())
    def test_timers_reject_direct_and_indirect_logic_calls(self):
        for indirect in (False,True):
            d=fixture();action='invoke'
            if indirect:
                action='timerEntry';d['flowActions'].append({'id':action,'cases':[{'code':0,'effects':[{'op':'invoke','action':'invoke'}]}]})
            d['timers']=[{'id':'tick','intervalMs':1000,'action':action}]
            with self.subTest(indirect=indirect),self.assertRaisesRegex(Diagnostic,'Timer flow'):
                lower(d,Registry())

    def test_legacy_string_assignment_requires_failure(self):
        d=fixture();d.update(version=1,root={'id':'label','type':'text','props':{'text':'Result'}});d.pop('routes');d.pop('flowActions')
        d['actions']=[{'id':'run','op':'call','function':'transform','args':['hello'],'target':'output','failure':'failed'},{'id':'failed','op':'set','target':'status','value':'failure'}]
        self.assertEqual(next(a for a in lower(d,Registry()).actions if a.id=='run').target,'output')
        del d['actions'][0]['failure']
        with self.assertRaises(Diagnostic):lower(d,Registry())
    def test_generated_boundaries_publish_after_validation(self):
        f=LogicFunction('transform',(ABIType.UTF8,),ABIType.UTF8,64)
        swift=swift_utf8_wrapper(f,'native_transform');java,jni=android_utf8_wrapper(f,'com.example.result')
        self.assertIn('written <= UInt32(destination.count)',swift);self.assertIn('String(bytes:',swift)
        self.assertIn('result > 64',jni);self.assertIn('valid_utf8(result_bytes, result)',jni)
        self.assertLess(jni.index('valid_utf8(result_bytes'),jni.index('NewByteArray'))
        self.assertIn('free(result_bytes)',jni);self.assertNotIn('NewStringUTF',jni)
        self.assertIn('Arrays.fill(resultBytes',java)
        from dcflight.backends.ios_routed import IOS
        from dcflight.backends.android_routed import AndroidRouted
        app=lower(fixture(),Registry())
        ios='\n'.join(a.content for a in IOS().generate(app,Registry()).values() if isinstance(a.content,str))
        android='\n'.join(a.content for a in AndroidRouted().generate(app,Registry()).values() if isinstance(a.content,str))
        for source in (ios,android):
            self.assertIn('logicResult',source);self.assertIn('f_failed(navigate)',source)
            self.assertIn('f_done(navigate)',source)
        self.assertIn('self.s_output = logicResult',ios);self.assertIn('s_output = logicResult',android)
    def test_restricted_dart_capacity_roundtrip(self):
        source="const app = App(version:1,id:'com.example.result',name:'Result',logic:Logic(source:'logic.dart',prelude:'prelude.dart',functions:[LogicFunction(name:'empty',parameters:[],returns:'utf8',maxOutputBytes:16)]),root:Node(id:'label',type:'text',props:{'text':'Result'}));"
        d=DartParser(source).parse();self.assertEqual(d['logic']['functions'][0]['maxOutputBytes'],16)
        lower(d,Registry())
    @unittest.skipUnless(shutil.which('dart'),'Dart required')
    def test_evaluated_dart_logic_effect_serializes_and_lowers(self):
        authoring=Path(os.environ.get('DCFLIGHT_TEST_AUTHORING',Path(__file__).resolve().parents[1]/'authoring'))
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'app.dart'
            p.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp()=>App(version:2,id:'com.example.result',name:'Result',state:{'output':''},
logic:Logic(source:'logic.dart',prelude:'prelude.dart',functions:[LogicFunction(name:'empty',parameters:[],returns:'utf8',maxOutputBytes:16)]),
root:NavigationStack(id:'root',initialRoute:'home'),routes:[Screen(id:'home',title:'Result',body:Text('Result',id:'label'))],
flowActions:[FlowAction(id:'run',cases:[FlowCase(code:0,effects:[LogicCallEffect(function:'empty',target:'output',success:'done',failure:'failed')])]),FlowAction(id:'done',cases:[FlowCase(code:0,effects:[])]),FlowAction(id:'failed',cases:[FlowCase(code:0,effects:[])])]);""")
            d=load_evaluated(p,shutil.which('dart'),authoring=authoring)
            self.assertEqual(d['flowActions'][0]['cases'][0]['effects'][0]['op'],'logicCall')
            lower(d,Registry())
