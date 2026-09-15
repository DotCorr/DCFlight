import json
from pathlib import Path
import tempfile
import unittest

from dcflight.platforms.ios_api import SDKCatalog, Reference


def nominal(name, major, precise=None):
    return {'identifier': {'precise': precise or 'type:' + name},
            'kind': {'identifier': 'swift.struct'}, 'pathComponents': name.split('.'),
            'declarationFragments': [{'spelling': 'struct ' + name.split('.')[-1]}],
            'availability': [{'domain': 'iOS', 'introduced': {'major': major}}]}


def property_symbol(owner='Owner', reference='type:Later'):
    return {'identifier': {'precise': 'member:value'}, 'kind': {'identifier': 'swift.property'},
            'pathComponents': [*owner.split('.'), 'value'],
            'declarationFragments': [{'spelling': 'var value: '},
                {'kind': 'typeIdentifier', 'spelling': 'Later', 'preciseIdentifier': reference},
                {'spelling': '? { get }'}],
            'availability': [{'domain': 'iOS', 'introduced': {'major': 16}}]}


class SignatureAvailabilityTests(unittest.TestCase):
    def catalog(self, *symbols):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'SDK.symbols.json'
            path.write_text(json.dumps({'symbols': list(symbols)}))
            return SDKCatalog.from_symbolgraphs([path], 'SDK')

    def test_result_type_availability_survives_serialization(self):
        catalog = self.catalog(nominal('Owner', 16), nominal('Later', 26), property_symbol())
        for value in (catalog, SDKCatalog.from_records(list(catalog.records()))):
            with self.assertRaisesRegex(ValueError, 'availability'):
                value.emit_call('member:value', receiver=Reference('owner', 'Owner'), ios_version=(18, 0))
            self.assertEqual('Later?', value.emit_call('member:value', receiver=Reference('owner', 'Owner'), ios_version=(26, 0)).result_type)

    def test_owner_ancestor_availability_and_precise_type_identity(self):
        catalog = self.catalog(nominal('Outer', 25), nominal('Outer.Inner', 16),
                               nominal('Later', 16), nominal('Other.Later', 26),
                               property_symbol('Outer.Inner'))
        with self.assertRaisesRegex(ValueError, 'availability'):
            catalog.emit_call('member:value', receiver=Reference('owner', 'Outer.Inner'), ios_version=(24, 0))
        catalog.emit_call('member:value', receiver=Reference('owner', 'Outer.Inner'), ios_version=(25, 0))

    def test_parameter_type_constraints_from_function_signature(self):
        method = {'identifier': {'precise': 'member:consume'}, 'kind': {'identifier': 'swift.method'},
                  'pathComponents': ['Owner', 'consume(_:)'],
                  'declarationFragments': [{'spelling': 'func consume(_ value: Later)'}],
                  'functionSignature': {'parameters': [{'name': 'value', 'declarationFragments': [
                      {'spelling': 'value: '}, {'kind': 'typeIdentifier', 'spelling': 'Later', 'preciseIdentifier': 'type:Later'}]}],
                                        'returns': [{'spelling': 'Void'}]}}
        catalog = self.catalog(nominal('Owner', 16), nominal('Later', 26), method)
        with self.assertRaisesRegex(ValueError, 'availability'):
            catalog.emit_call('member:consume', [Reference('value', 'Later')], receiver=Reference('owner', 'Owner'), ios_version=(18, 0))
        catalog.emit_call('member:consume', [Reference('value', 'Later')], receiver=Reference('owner', 'Owner'), ios_version=(26, 0))
