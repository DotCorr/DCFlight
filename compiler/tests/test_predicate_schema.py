import unittest
import json
from pathlib import Path

import jsonschema

from dcflight.registry import Registry
from dcflight.navigation_ir import schema as routed_schema


class PredicateSchemaTests(unittest.TestCase):
    def test_checked_in_routed_editor_schema_is_current(self):
        saved=Path(__file__).resolve().parents[1]/'registry/app-v2.schema.json'
        self.assertEqual(json.loads(saved.read_text()),routed_schema(Registry()))

    def validator(self, *, routed=False, fragment=None):
        schema = routed_schema(Registry()) if routed else Registry().schema()
        jsonschema.Draft202012Validator.check_schema(schema)
        return jsonschema.Draft202012Validator({
            '$defs': schema['$defs'], **(fragment or {'$ref': '#/$defs/condition'})})

    def test_recursive_conditions_and_exact_list_bounds(self):
        for routed in (False, True):
            validator = self.validator(routed=routed)
            for value in (True, False, {'ref': 'ready'}, {'isEmpty': ''},
                          {'isEmpty': {'ref': 'status'}},
                          {'not': {'all': [{'ref': 'ready'}, {'any': [False, {'isEmpty': 'x'}]}]}},
                          {'all': [True]}, {'any': [False] * 32}):
                with self.subTest(routed=routed, value=value):
                    validator.validate(value)

    def test_malformed_or_scalar_predicate_operands_rejected(self):
        invalid = [0, '', None, {}, {'not': 'yes'}, {'isEmpty': False},
                   {'isEmpty': 0}, {'isEmpty': {'not': True}},
                   {'not': True, 'extra': False}, {'isEmpty': '', 'not': True},
                   {'ref': 'ready', 'extra': True}, {'ref': ''},
                   {'all': []}, {'any': []}, {'all': [True] * 33},
                   {'any': [False] * 33}, {'all': True}, {'any': [1]},
                   {'not': {'all': [True, {'isEmpty': {'ref': 'a', 'extra': 1}}]}}]
        for routed in (False, True):
            validator = self.validator(routed=routed)
            for value in invalid:
                with self.subTest(routed=routed, value=value):
                    self.assertFalse(validator.is_valid(value))

    def test_field_references_only_in_routed_conditions(self):
        field = {'field': {'collection': 'people', 'name': 'name'}}
        primitive, routed = self.validator(), self.validator(routed=True)
        for value in (field, {'isEmpty': field}, {'not': {'any': [field, False]}}):
            self.assertFalse(primitive.is_valid(value))
            routed.validate(value)
        for value in ({'field': {'collection': 'people'}},
                      {'field': {'collection': 'people', 'name': 'name', 'extra': ''}}):
            self.assertFalse(routed.is_valid(value))

    def test_all_condition_nodes_share_definitions_without_widening_properties(self):
        schema = routed_schema(Registry())
        nodes = {node['properties']['type']['const']: node
                 for node in schema['$defs']['node']['oneOf']}
        for kind in ('text', 'button', 'localImage', 'remoteImage', 'cameraPreview', 'nativeMap'):
            for key in ('visibleWhen', 'enabledWhen'):
                self.assertEqual(nodes[kind]['properties'][key], {'$ref': '#/$defs/condition'})
        text = nodes['text']['properties']['props']['properties']['text']
        self.assertFalse(self.validator(routed=True, fragment=text).is_valid({'isEmpty': ''}))
        action_value = Registry().schema()['properties']['actions']['items']['oneOf'][0]['properties']['value']
        self.assertFalse(self.validator(fragment=action_value).is_valid({'not': False}))


if __name__ == '__main__':
    unittest.main()
