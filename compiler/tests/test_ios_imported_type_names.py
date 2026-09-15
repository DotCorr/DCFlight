import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference


class ImportedTypeNameTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dependency = self.root / 'Cloud.symbols.json'
        self.nominal = {'identifier': {'precise': 'nominal:metadata'}, 'kind': {'identifier': 'swift.class'},
                        'pathComponents': ['Share', 'Metadata'], 'declarationFragments': [{'spelling': 'class Metadata'}],
                        'availability': [{'domain': 'iOS', 'introduced': {'major': 20}}]}
        self.dependency.write_text(json.dumps({'symbols': [self.nominal]}))
        self.member = {'identifier': {'precise': 'member:metadata'}, 'kind': {'identifier': 'swift.property'},
                       'pathComponents': ['Scene', 'metadata'], 'declarationFragments': [
                           {'spelling': 'var metadata: '}, {'kind': 'typeIdentifier', 'spelling': 'OldMetadata', 'preciseIdentifier': 'nominal:metadata'},
                           {'spelling': '? { get }'}]}

    def catalog(self, member=None, dependencies=True):
        source = self.root / 'UI.symbols.json'
        source.write_text(json.dumps({'symbols': [member or self.member]}))
        return SDKCatalog.from_symbolgraphs([source], 'UI', type_graphs={'Cloud': [self.dependency]} if dependencies else None)

    def test_exact_identity_rewrites_and_preserves_import_provenance(self):
        self.assertEqual('OldMetadata?', self.catalog(dependencies=False).get('member:metadata').result)
        catalog = self.catalog(); api = catalog.get('member:metadata')
        self.assertEqual('Share.Metadata?', api.result)
        self.assertEqual(('Cloud',), api.required_imports)
        self.assertEqual(hashlib.sha256(self.dependency.read_bytes()).hexdigest(), api.type_resolutions[0]['sourceSHA256'])
        restored = SDKCatalog.from_records(list(catalog.records()))
        self.assertEqual(api, restored.get(api.id))
        with self.assertRaisesRegex(ValueError, 'availability'):
            restored.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=(18, 0))
        self.assertIn('Cloud', restored.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=(20, 0)).imports)

    def test_no_name_guess_or_duplicate_nested_owner(self):
        member = copy.deepcopy(self.member)
        member['declarationFragments'][1]['preciseIdentifier'] = 'unrelated:metadata'
        self.assertEqual('OldMetadata?', self.catalog(member).get('member:metadata').result)
        member['declarationFragments'][1].update(preciseIdentifier='nominal:metadata', spelling='Metadata')
        member['declarationFragments'].insert(1, {'spelling': 'Share.'})
        self.assertEqual('Share.Metadata?', self.catalog(member).get('member:metadata').result)

    def test_conflicting_dependency_identity_and_invalid_provenance_rejected(self):
        other = self.root / 'Other.symbols.json'
        other.write_text(json.dumps({'symbols': [{**self.nominal, 'pathComponents': ['Different']}]}))
        source = self.root / 'UI.symbols.json';source.write_text(json.dumps({'symbols': [self.member]}))
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            SDKCatalog.from_symbolgraphs([source], 'UI', type_graphs={'Cloud': [self.dependency, other]})
        record = self.catalog().get('member:metadata').to_dict()
        record['typeResolutions'][0]['sourceSHA256'] = 'bad'
        with self.assertRaisesRegex(ValueError, 'digest'):
            SDKCatalog.from_records([record])

    def test_canonical_fragments_still_inherit_dependency_availability(self):
        member = copy.deepcopy(self.member)
        member['declarationFragments'][1]['spelling'] = 'Metadata'
        member['declarationFragments'].insert(1, {'spelling': 'Share.'})
        catalog = self.catalog(member)
        api = catalog.get('member:metadata')
        self.assertEqual('Share.Metadata?', api.result)
        self.assertEqual(('Cloud',), api.required_imports)
        self.assertEqual(1, len(api.type_resolutions))
        with self.assertRaisesRegex(ValueError, 'availability'):
            catalog.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=(18, 0))
        catalog.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=(20, 0))

    def test_duplicate_nominal_sources_union_constraints_and_provenance(self):
        other = self.root / 'CloudOverlay.symbols.json'
        other.write_text(json.dumps({'symbols': [{**self.nominal, 'availability': [
            {'domain': 'iOS', 'introduced': {'major': 24}, 'obsoleted': {'major': 26}}]}]}))
        source = self.root / 'UI.symbols.json'
        source.write_text(json.dumps({'symbols': [self.member]}))
        expected_sources = {hashlib.sha256(path.read_bytes()).hexdigest() for path in (self.dependency, other)}
        for paths in ([self.dependency, other], [other, self.dependency]):
            catalog = SDKCatalog.from_symbolgraphs([source], 'UI', type_graphs={'Cloud': paths})
            api = catalog.get('member:metadata')
            self.assertEqual(expected_sources, {r['sourceSHA256'] for r in api.type_resolutions})
            self.assertEqual(api, SDKCatalog.from_records([api.to_dict()]).get(api.id))
            for version in ((23, 0), (26, 0)):
                with self.assertRaisesRegex(ValueError, 'availability'):
                    catalog.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=version)
            catalog.emit_call(api.id, receiver=Reference('scene', 'Scene'), ios_version=(24, 0))
