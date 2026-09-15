"""Both Dart frontends preserve runtime predicates as structured input."""
import shutil
import tempfile
import unittest
from pathlib import Path

from dcflight.evaluated_frontend import load_evaluated
from dcflight.frontends import DartParser
from dcflight.validate import Diagnostic


PREDICATE = """BooleanAll([
  BooleanNot(StringIsEmpty(Ref(name: 'message'))),
  BooleanAny([Ref(name: 'ready'), false]),
  BooleanNot(StringIsEmpty(FieldRef(collection: 'rows', name: 'label'))),
  StringIsEmpty(''),
])"""
EXPECTED = {'all': [
    {'not': {'isEmpty': {'ref': 'message'}}},
    {'any': [{'ref': 'ready'}, False]},
    {'not': {'isEmpty': {'field': {'collection': 'rows', 'name': 'label'}}}},
    {'isEmpty': ''},
]}


def document(predicate):
    return """App(version: 1, id: 'com.example.predicates', name: 'Predicates',
 state: {'message': '', 'ready': false},
 root: Node(id: 'label', type: 'text', props: {'text': 'Status'},
 visibleWhen: %s, enabledWhen: BooleanNot(false)))""" % predicate


class LegacyPredicateAuthoringTests(unittest.TestCase):
    def test_nested_predicates_preserve_literals_state_and_row_references(self):
        result = DartParser('const app = ' + document(PREDICATE) + ';').parse()
        self.assertEqual(EXPECTED, result['root']['visibleWhen'])
        self.assertEqual({'not': False}, result['root']['enabledWhen'])

    def test_predicate_constructors_reject_extra_missing_and_named_arguments(self):
        for predicate in ('StringIsEmpty()', "StringIsEmpty('', '')",
                          'BooleanNot(value: true)', 'BooleanAll([], [])'):
            with self.subTest(predicate=predicate), self.assertRaises(Diagnostic):
                DartParser('const app = ' + document(predicate) + ';').parse()

    def test_field_reference_requires_exact_named_arguments(self):
        for field in ("FieldRef(name: 'label')",
                      "FieldRef(collection: 'rows', name: 'label', extra: true)"):
            with self.subTest(field=field), self.assertRaises(Diagnostic):
                DartParser('const app = ' + document('StringIsEmpty(' + field + ')') + ';').parse()


@unittest.skipUnless(shutil.which('dart'), 'Dart SDK required for authoring evaluation')
class EvaluatedPredicateAuthoringTests(unittest.TestCase):
    def test_const_predicates_match_nonexecuting_frontend_without_folding(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'app.dart'
            source.write_text("import 'package:dcflight_authoring/dcflight.dart';\n"
                              'App buildApp() => const ' + document(PREDICATE) + ';')
            evaluated = load_evaluated(source, shutil.which('dart'))
            legacy = DartParser('const app = ' + document(PREDICATE) + ';').parse()
            self.assertEqual(EXPECTED, evaluated['root']['visibleWhen'])
            self.assertEqual(legacy['root'], evaluated['root'])
            # Even a literal emptiness expression remains compiler input.
            self.assertEqual({'isEmpty': ''}, evaluated['root']['visibleWhen']['all'][-1])

    def test_helpers_can_return_predicate_objects_with_typed_references(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'app.dart'
            source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
Predicate hasText(Reference<String> text) => BooleanNot(StringIsEmpty(text));
App buildApp() => App(id:'com.example.helpers', name:'Helpers',
 root:Text('Status',id:'status',
  visibleWhen:hasText(const Ref<String>(name:'message')),
  enabledWhen:hasText(const FieldRef<String>(collection:'rows',name:'label'))));
""")
            root = load_evaluated(source, shutil.which('dart'))['root']
            self.assertEqual({'not': {'isEmpty': {'ref': 'message'}}}, root['visibleWhen'])
            self.assertEqual({'not': {'isEmpty': {'field': {'collection': 'rows', 'name': 'label'}}}}, root['enabledWhen'])
