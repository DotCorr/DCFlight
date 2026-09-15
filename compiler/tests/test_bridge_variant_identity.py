import copy
from dataclasses import replace
from pathlib import Path
import tempfile
import unittest
from dcflight.ios_native_variants import identity, merge_bridges
from dcflight.platforms.ios_api import SDKCatalog
from test_ios_bridged_spelling import bridge_fixture, update_graph
import test_ios_bridged_spelling as bridge_tests

class BridgeVariantIdentityTests(unittest.TestCase):
 def fixture(self, root):
  graph=bridge_fixture(root)
  return graph,bridge_tests.BridgeTests().catalog(root).get('call')
 def test_metadata_only_change_merges_all_proof_rows(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);graph,a=self.fixture(root)
   update_graph(graph,metadata={'generator':'another capture'})
   b=bridge_tests.BridgeTests().catalog(root).get('call')
   self.assertEqual(identity(a),identity(b))
   merged=SDKCatalog([a,b]);self.assertEqual(1,len(merged.variants['call']))
   c=merged.get('call').bridge_resolutions[0]
   for role in ('reference','value','alias','conformances','memberships'):
    self.assertEqual(2,len(c[role]),role)
    self.assertEqual({r['sourceSHA256'] for x in (a,b) for r in x.bridge_resolutions[0][role]}, {r['sourceSHA256'] for r in c[role]})
   self.assertEqual(list(merged.records()),list(SDKCatalog([b,a]).records()))
   self.assertEqual(list(merged.records()),list(SDKCatalog.from_records(merged.records()).records()))
 def test_semantic_bridge_change_is_not_collapsed(self):
  with tempfile.TemporaryDirectory() as d:
   _,a=self.fixture(Path(d));contracts=copy.deepcopy(a.bridge_resolutions)
   contracts[0]['reference'][0]['spelling']='OtherReference'
   b=replace(a,bridge_resolutions=contracts)
   self.assertNotEqual(identity(a),identity(b));self.assertEqual(2,len(SDKCatalog([a,b]).variants['call']))
   contracts=copy.deepcopy(a.bridge_resolutions);contracts[0]['memberships'][0]['relationship']['target']='wrong'
   with self.assertRaisesRegex(ValueError,'membership'):SDKCatalog([replace(a,bridge_resolutions=contracts)])
 def test_digest_only_change_and_availability_order(self):
  with tempfile.TemporaryDirectory() as d:
   _,a=self.fixture(Path(d));contracts=copy.deepcopy(a.bridge_resolutions)
   for role in ('reference','value','alias'):
    for row in contracts[0][role]:row['symbolSHA256']='f'*64
   self.assertEqual(identity(a),identity(replace(a,bridge_resolutions=contracts)))
   contracts[0]['value'][0]['availability'].append({'domain':'iOS','introduced':{'major':25}})
   self.assertNotEqual(identity(a),identity(replace(a,bridge_resolutions=contracts)))
 def test_merged_provenance_bounded(self):
  with tempfile.TemporaryDirectory() as d:
   _,a=self.fixture(Path(d));contracts=[]
   for i in range(257):
    c=copy.deepcopy(a.bridge_resolutions[0]);c['reference'][0]['sourceSHA256']=format(i,'064x');contracts.append(c)
   with self.assertRaisesRegex(ValueError,'row bound'):merge_bridges(contracts)
