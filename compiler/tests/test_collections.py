import copy
import shutil
import tempfile
import unittest
from pathlib import Path
from dcflight.registry import Registry
from dcflight.validate import lower, Diagnostic
from dcflight.collection_ir import FieldReference
from dcflight.flow_ir import PathTemplate
from dcflight.ir import Reference
from dcflight.navigation_ir import schema


def fixture():
    return {'version':2,'id':'com.example.collections','name':'Collections','state':{'selected':'','token':''},
        'collections':[{'name':'people','key':'id','fields':{'id':{'type':'string'},'name':{'type':'string','default':''},'online':{'type':'bool','default':False}}}],
        'root':{'id':'nav','type':'navigationStack','props':{'initialRoute':'people'}},
        'routes':[{'id':'people','title':'People','body':{'id':'list','type':'repeat','props':{'collection':'people','selection':{'ref':'selected'}},'action':'load',
            'children':[{'id':'label','type':'text','props':{'text':{'field':{'collection':'people','name':'name'}}},'visibleWhen':{'field':{'collection':'people','name':'online'}}}]}}],
        'transport':{'baseUrl':'https://example.com'},
        'flowActions':[{'id':'load','cases':[{'code':0,'effects':[{'op':'request','id':'loadPeople','method':'GET','path':['/v1/people/',{'ref':'selected'},'?q=',{'ref':'selected'}],'outputs':{'people':['users']},'success':'done','failure':'done'}]}]},
                       {'id':'done','cases':[{'code':0,'effects':[]}]}]}

class CollectionTests(unittest.TestCase):
    def test_typed_scope_outputs_and_path(self):
        app=lower(fixture(),Registry());row=app.routes[0].body.children[0]
        self.assertIsInstance(row.props()['text'],FieldReference)
        self.assertEqual(row.props()['text'].field,'name')
        self.assertIsInstance(row.visible_when,FieldReference)
        self.assertEqual([s.name for s in app.states],['selected','token'])
        request=app.flow_actions[0].cases[0].effects[0]
        self.assertIsInstance(request.path,PathTemplate)
        self.assertIsInstance(request.path.parts[1],Reference)
        self.assertEqual(request.outputs[0].target,'people')
        self.assertEqual(app.collections[0].fields[1].default.value,'')

    def test_invalid_contracts_fail_closed(self):
        mutations=[
            lambda d:d['collections'][0].update(key='missing'),
            lambda d:d['collections'][0].update(key='online'),
            lambda d:d['collections'][0]['fields']['id'].update(default=''),
            lambda d:d['collections'][0]['fields']['name'].update(default=3),
            lambda d:d['collections'][0]['fields']['name'].update(type='float'),
            lambda d:d['collections'][0].update(name='selected'),
            lambda d:d['routes'][0]['body']['children'][0]['props']['text']['field'].update(name='missing'),
            lambda d:d['routes'][0]['body']['children'][0]['props']['text']['field'].update(collection='unknown'),
            lambda d:d['routes'][0]['body']['children'][0]['props']['text']['field'].update(name='online'),
            lambda d:d['routes'][0]['body'].pop('action'),
            lambda d:d['routes'][0]['body'].update(action='missing'),
            lambda d:d['state'].update(selected=0),
            lambda d:d['routes'][0]['body'].update(children=[copy.deepcopy(d['routes'][0]['body'])]),
            lambda d:d['routes'][0].update(body=d['routes'][0]['body']['children'][0]),
            lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(path=[{'ref':'selected'}]),
            lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(path=['//evil']),
            lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(path=['/ok','#fragment']),
            lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(path=['/ok',{'ref':'absent'}]),
        ]
        for mutate in mutations:
            data=fixture();mutate(data)
            with self.subTest(mutate=mutate), self.assertRaises(Diagnostic):lower(data,Registry())

    def test_schema_accepts_valid_fixture(self):
        try:import jsonschema
        except ImportError:self.skipTest('jsonschema not installed')
        jsonschema.Draft202012Validator(schema(Registry())).validate(fixture())

    def test_real_dart_composition(self):
        dart=shutil.which('dart')
        if not dart:self.skipTest('Dart SDK required')
        from dcflight.evaluated_frontend import load_evaluated
        with tempfile.TemporaryDirectory() as temp:
            source=Path(temp)/'app.dart'
            source.write_text('''import 'package:dcflight_authoring/dcflight.dart';
App buildApp() => RoutedApp(id:'com.example.collections',name:'People',state:{'selected':''},
collections:[Collection(name:'people',key:'id',fields:{'id':CollectionField(type:'string'),'name':CollectionField(type:'string',defaultValue:'')})],
root:NavigationStack(id:'nav',initialRoute:'people'),
screens:[Screen(id:'people',title:'People',body:Column(id:'rows',children:[
for(final label in ['heading']) Text(label,id:label),
Repeat(id:'peopleRows',collection:'people',child:Text.bind(FieldRef<String>(collection:'people',name:'name'),id:'person'))]))]);''')
            app=lower(load_evaluated(source,dart=dart),Registry())
            self.assertEqual(app.collections[0].name,'people')
            self.assertIsInstance(app.routes[0].body.children[1].children[0].props()['text'],FieldReference)

    def test_append_and_clear_require_collection(self):
        from dcflight.flow_ir import ClearCollectionEffect
        data=fixture();request=data['flowActions'][0]['cases'][0]['effects'][0]
        request['outputs']['people']={'path':['users'],'mode':'append'}
        data['flowActions'][1]['cases'][0]['effects']=[{'op':'clearCollection','target':'people'}]
        app=lower(data,Registry())
        self.assertEqual(app.flow_actions[0].cases[0].effects[0].outputs[0].mode,'append')
        self.assertIsInstance(app.flow_actions[1].cases[0].effects[0],ClearCollectionEffect)
        request['outputs']={'selected':{'path':['name'],'mode':'replace'}}
        with self.assertRaises(Diagnostic):lower(data,Registry())
        request['outputs']={};data['flowActions'][1]['cases'][0]['effects'][0]['target']='selected'
        with self.assertRaises(Diagnostic):lower(data,Registry())
