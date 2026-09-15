import os
import dataclasses
import shutil
import tempfile
import unittest
from pathlib import Path

from dcflight.ir import ABIType, ScalarType
from dcflight.validate import lower, Diagnostic
from dcflight.registry import Registry
from dcflight.navigation_ir import schema
from dcflight.frontends import DartParser
from dcflight.evaluated_frontend import load_evaluated


def fixture(routed=False):
    doc={'version':1,'id':'com.example.utf8','name':'UTF8','state':{'text':'Hello 🌍\0','result':0},
         'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[
             {'name':'readText','parameters':['utf8'],'returns':'int32'}]},
         'actions':[{'id':'read','op':'call','function':'readText','args':[{'ref':'text'}],
                     'target':'result','failure':'failed'},
                    {'id':'failed','op':'set','target':'result','value':-1}],
         'root':{'id':'textNode','type':'text','props':{'text':'UTF8'}}}
    if routed:
        doc.update(version=2,root={'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
                   routes=[{'id':'home','title':'Home','body':doc['root']}],
                   flowActions=[{'id':'flowRead','function':'readText','arguments':[{'ref':'text'}],
                                 'failure':'flowFailed','cases':[{'code':0,'effects':[]}]},
                                {'id':'flowFailed','cases':[{'code':0,'effects':[]}]}])
    return doc


class UTF8ContractTests(unittest.TestCase):
    def test_utf8_input_retains_typed_string_and_failure(self):
        for routed in (False,True):
            doc=fixture(routed);app=lower(doc,Registry())
            self.assertEqual(app.logic.functions[0].parameters,(ABIType.UTF8,))
            self.assertEqual(next(a for a in app.actions if a.id=='read').arguments[0].type,ScalarType.STRING)
            self.assertEqual(next(a for a in app.actions if a.id=='read').failure,'failed')
            self.assertEqual(dataclasses.asdict(next(a for a in app.actions if a.id=='read'))['failure'],'failed')
            if routed:
                self.assertEqual(app.flow_actions[0].failure,'flowFailed')
                self.assertEqual(app.flow_actions[0].arguments[0].type,ScalarType.STRING)
            doc['actions'][0]['args']=['é🌍\0']
            self.assertEqual(next(a for a in lower(doc,Registry()).actions if a.id=='read').arguments[0].value,'é🌍\0')

    def test_unsupported_results_types_and_missing_or_malformed_failures(self):
        cases=[]
        d=fixture();d['logic']['functions'][0]['returns']='utf8';cases.append(d)
        for value in (1,True,None,[],{'ref':'result'},{'other':'text'}):
            d=fixture();d['actions'][0]['args']=[value];cases.append(d)
        for failure in (None,1,True,{},'unknown'):
            d=fixture();d['actions'][0]['failure']=failure;cases.append(d)
        d=fixture();del d['actions'][0]['failure'];cases.append(d)
        d=fixture();d['actions'][0]['args']=[];cases.append(d)
        d=fixture();d['actions'][1]['failure']='read';cases.append(d)
        d=fixture();d['logic']['functions'][0]['parameters']=['int32'];d['actions'][0]['args']=[1];cases.append(d)
        d=fixture();d['logic']['functions'][0]['parameters']=['uint64'];d['actions'][0]['args']=[1];del d['actions'][0]['failure'];cases.append(d)
        for doc in cases:
            with self.subTest(doc=doc),self.assertRaises(Diagnostic):lower(doc,Registry())

    def test_action_failure_cycles_are_rejected(self):
        d=fixture();d['actions'][0]['failure']='read'
        with self.assertRaisesRegex(Diagnostic,'cycle'):lower(d,Registry())
        d=fixture();d['actions'][1]={**d['actions'][0],'id':'failed','failure':'read'}
        with self.assertRaisesRegex(Diagnostic,'cycle'):lower(d,Registry())

    def test_flow_failure_membership_cycles_and_input_type(self):
        cases=[]
        for failure in (None,1,False,'failed','missing'):
            d=fixture(True);d['flowActions'][0]['failure']=failure;cases.append(d)
        d=fixture(True);del d['flowActions'][0]['failure'];cases.append(d)
        d=fixture(True);d['flowActions'][1]['failure']='flowRead';cases.append(d)
        d=fixture(True);d['flowActions'][0]['arguments']=[{'length':{'ref':'text'}}];cases.append(d)
        d=fixture(True);d['actions'][0]['failure']='flowFailed';cases.append(d)
        d=fixture(True);d['navigationActions']=[{'id':'go','op':'back'}];d['actions'][0]['failure']='go';cases.append(d)
        for doc in cases:
            with self.subTest(doc=doc),self.assertRaises(Diagnostic):lower(doc,Registry())
        d=fixture(True);d['flowActions'][1]['cases'][0]['effects']=[{'op':'invoke','action':'flowRead'}]
        with self.assertRaisesRegex(Diagnostic,'cycle'):lower(d,Registry())
        d=fixture(True);d['flowActions'][0]['failure']='flowRead'
        with self.assertRaisesRegex(Diagnostic,'cycle'):lower(d,Registry())

    def test_schema_exposes_utf8_only_as_input(self):
        import jsonschema
        for routed in (False,True):
            doc=fixture(routed);shape=schema(Registry()) if routed else Registry().schema()
            jsonschema.validate(doc,shape)
            doc['logic']['functions'][0]['returns']='utf8'
            with self.assertRaises(jsonschema.ValidationError):jsonschema.validate(doc,shape)

    def test_non_utf8_flow_cannot_author_failure_and_timer_checks_failure_path(self):
        doc=fixture(True);doc['actions']=[]
        doc['logic']['functions'][0]['parameters']=['int32']
        doc['flowActions'][0]['arguments']=[1]
        with self.assertRaisesRegex(Diagnostic,'failure requires utf8'):lower(doc,Registry())
        del doc['flowActions'][0]['failure']
        self.assertIsNone(lower(doc,Registry()).flow_actions[0].failure)
        doc=fixture(True)
        doc['timers']=[{'id':'ticker','intervalMs':1000,'action':'flowRead'}]
        doc['flowActions'][1]['cases'][0]['effects']=[{'op':'cancelRequests'}]
        with self.assertRaisesRegex(Diagnostic,'Timer flow contains unsupported'):lower(doc,Registry())

    def test_legacy_dart_serializes_same_utf8_call_contract(self):
        text="""const app = App(version:1,id:'com.example.utf8',name:'UTF8',state:{'text':'hello','result':0},
 logic:Logic(source:'logic.dart',prelude:'prelude.dart',functions:[LogicFunction(name:'readText',parameters:['utf8'],returns:'int32')]),
 actions:[Action(id:'read',op:'call',function:'readText',args:[Ref(name:'text')],target:'result',failure:'failed'),
 Action(id:'failed',op:'set',target:'result',value:-1)],root:Node(id:'label',type:'text',props:{'text':'Hello'}));"""
        doc=DartParser(text).parse()
        self.assertEqual(next(a for a in lower(doc,Registry()).actions if a.id=='read').failure,'failed')

    @unittest.skipUnless(shutil.which('dart'),'Dart SDK required')
    def test_evaluated_dart_const_call_and_flow_failure_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'app.dart'
            source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp()=>App(version:2,id:'com.example.utf8',name:'UTF8',state:{'text':'é🌍','result':0},
 logic:const Logic(source:'logic.dart',prelude:'prelude.dart',functions:[LogicFunction(name:'readText',parameters:['utf8'],returns:'int32')]),
 actions:const [Action.call(id:'read',function:'readText',args:[Ref<String>(name:'text')],target:'result',failure:'failed'),
 Action.set(id:'failed',target:'result',value:-1)],root:NavigationStack(id:'root',initialRoute:'home'),
 routes:[Screen(id:'home',title:'Home',body:Text('Hello',id:'label'))],
 flowActions:const [FlowAction(id:'flowRead',function:'readText',arguments:[Ref<String>(name:'text')],failure:'flowFailed',cases:[FlowCase(code:0,effects:[])]),
 FlowAction(id:'flowFailed',cases:[FlowCase(code:0,effects:[])])]);""")
            doc=load_evaluated(source,shutil.which('dart'),authoring=os.environ.get('DCFLIGHT_TEST_AUTHORING_ROOT'))
            app=lower(doc,Registry())
            self.assertEqual(next(a for a in app.actions if a.id=='read').failure,'failed')
            self.assertEqual(app.flow_actions[0].failure,'flowFailed')
            self.assertEqual(doc['logic']['functions'][0]['parameters'],['utf8'])
