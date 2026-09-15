import copy
import dataclasses
import unittest
from dcflight.ir import (BooleanAll, BooleanAny, BooleanNot, StringIsEmpty,
                         Literal, Reference, FieldReference, ScalarType, walk_expression)
from dcflight.registry import Registry
from dcflight.validate import lower, Diagnostic
from test_collections import fixture as collection_fixture


def fixture(condition):
    return {'version':1,'id':'com.example.conditions','name':'Conditions',
            'state':{'message':'','ready':True,'count':0},
            'root':{'id':'label','type':'text','props':{'text':{'ref':'message'}},'visibleWhen':condition}}


class PredicateValidationTests(unittest.TestCase):
    def test_typed_condition_and_distinct_canonical_operator_identity(self):
        condition={'all':[{'ref':'ready'},{'not':{'isEmpty':{'ref':'message'}}}]}
        app=lower(fixture(condition),Registry())
        expr=app.root.visible_when
        self.assertIsInstance(expr,BooleanAll)
        self.assertIsInstance(expr.values[1].value,StringIsEmpty)
        self.assertEqual(expr.type,ScalarType.BOOL)
        self.assertEqual([v.name for v in walk_expression(expr) if isinstance(v,Reference)],['ready','message'])
        self.assertNotEqual(dataclasses.asdict(expr),dataclasses.asdict(BooleanAny(expr.values)))
        self.assertEqual([s.name for s in app.states],['count','message','ready'])

    def test_invalid_operands_shapes_and_writable_values_fail(self):
        invalid=[{'isEmpty':False},{'isEmpty':{'ref':'count'}},{'isEmpty':{'ref':'missing'}},
                 {'not':'text'},{'all':[]},{'any':[]},{'all':[True]*33},
                 {'any':[True,4]},{'all':True},{'not':True,'extra':False},
                 {'isEmpty':{'not':True}},{'unknown':True}, {'ref':'message'}]
        for condition in invalid:
            with self.subTest(condition=condition),self.assertRaises(Diagnostic):
                lower(fixture(condition),Registry())
        app=fixture(True)
        app['actions']=[{'id':'assign','op':'set','target':'ready','value':{'not':False}}]
        with self.assertRaises(Diagnostic):lower(app,Registry())
        app=fixture(True);app['root']['props']['text']={'isEmpty':{'ref':'message'}}
        with self.assertRaises(Diagnostic):lower(app,Registry())

    def test_depth_and_total_nodes_are_bounded(self):
        value=True
        for _ in range(16):value={'not':value}
        lower(fixture(value),Registry())
        with self.assertRaisesRegex(Diagnostic,'nesting'):lower(fixture({'not':value}),Registry())
        wide={'all':[{'all':[True]*32} for _ in range(8)]}
        with self.assertRaisesRegex(Diagnostic,'256'):lower(fixture(wide),Registry())

    def test_nested_fields_retain_row_scope_without_synthetic_state(self):
        data=collection_fixture();row=data['routes'][0]['body']['children'][0]
        field={'field':{'collection':'people','name':'name'}}
        row['visibleWhen']={'all':[{'not':{'isEmpty':field}},{'field':{'collection':'people','name':'online'}}]}
        row['enabledWhen']={'any':[False,{'not':{'isEmpty':field}}]}
        app=lower(data,Registry());result=app.routes[0].body.children[0]
        leaves=[v for v in walk_expression(result.visible_when) if isinstance(v,FieldReference)]
        self.assertEqual([v.field for v in leaves],['name','online'])
        self.assertEqual([s.name for s in app.states],['selected','token'])
        wrong=copy.deepcopy(data);wrong['routes'][0]['body']=row
        with self.assertRaisesRegex(Diagnostic,'outside'):lower(wrong,Registry())
        wrong=copy.deepcopy(data);wrong['routes'][0]['body']['children'][0]['visibleWhen']={'isEmpty':{'field':{'collection':'people','name':'online'}}}
        with self.assertRaisesRegex(Diagnostic,'string'):lower(wrong,Registry())

    def test_direct_canonical_construction_rejects_wrong_types(self):
        with self.assertRaises(ValueError):StringIsEmpty(Literal(True,ScalarType.BOOL))
        with self.assertRaises(ValueError):BooleanNot(Literal('',ScalarType.STRING))
        with self.assertRaises(ValueError):BooleanAll(())
        with self.assertRaises(ValueError):BooleanAny([Literal(True,ScalarType.BOOL)])
