import copy,json,tempfile,unittest
from pathlib import Path
from dcflight.swift_qualifier_recovery import concurrent_parameters,insert_attribute,mangled,demangle,tree

ROOT='''kind=Global
  kind=Function
    kind=Identifier, text="sample"
    kind=Type
      kind=FunctionType
        kind=ArgumentTuple
          kind=Type
            kind=Tuple
              kind=TupleElement
                kind=Type
                  kind=Structure
              kind=TupleElement
                kind=Type
                  kind=FunctionType
                    kind=ConcurrentFunctionType
                    kind=ArgumentTuple
                      kind=Type
                        kind=Tuple
                    kind=ReturnType
                      kind=Type
                        kind=Tuple
        kind=ReturnType
          kind=Type
            kind=Tuple
'''
class QualifierRecoveryTests(unittest.TestCase):
 def test_exact_outer_callback_index_and_name_arity(self):
  self.assertEqual(concurrent_parameters(ROOT,'sample',2),[1])
  for name,count in [('different',2),('sample',1),('sample',3)]:
   with self.assertRaises(ValueError):concurrent_parameters(ROOT,name,count)
 def test_nested_sendable_not_promoted_to_outer(self):
  nested=ROOT.replace('                    kind=ConcurrentFunctionType\n','').replace('                        kind=Tuple\n                    kind=ReturnType','                        kind=FunctionType\n                          kind=ConcurrentFunctionType\n                    kind=ReturnType',1)
  self.assertEqual(concurrent_parameters(nested,'sample',2),[])
 def test_optional_or_generic_callback_wrapper_not_lifted(self):
  optional=ROOT.replace('                  kind=FunctionType\n','                  kind=BoundGenericEnum\n',1)
  self.assertEqual(concurrent_parameters(optional,'sample',2),[])
 def test_ambiguous_tree_rejects(self):
  for text in [ROOT+'kind=Global\n',ROOT.replace('  kind=Function','   kind=Function'),ROOT.replace('    kind=Identifier, text="sample"','    kind=Identifier, text="sample"\n    kind=Identifier, text="sample"'),ROOT.replace('                    kind=ConcurrentFunctionType','                    kind=ConcurrentFunctionType\n                    kind=ConcurrentFunctionType')]:
   with self.assertRaises(ValueError):concurrent_parameters(text,'sample',2)
 def test_fragment_edit_preserves_type_identity_tokens(self):
  fragments=[{'kind':'internalParam','spelling':'callback'},{'kind':'text','spelling':': @escaping ('},{'kind':'typeIdentifier','spelling':'Int','preciseIdentifier':'s:Si'},{'kind':'text','spelling':') -> Void'}]
  changed=insert_attribute(fragments,'(Int) -> Void')
  self.assertEqual(''.join(v['spelling'] for v in changed),'callback: @escaping @Sendable (Int) -> Void')
  self.assertEqual(changed[2],fragments[2]);self.assertNotIn('@Sendable',fragments[1]['spelling'])
  with self.assertRaises(ValueError):insert_attribute(fragments,'(String) -> Void')
 def test_identity_and_batch_bounds(self):
  for identity in ['c:objc','--help','s:hello\nother','s:'+'A'*4097]:
   with self.assertRaises(ValueError):mangled(identity)
  for ids in [[],['s:test']*65]:
   with self.assertRaises(ValueError):demangle(ids,'/not-executed')
 def test_original_and_derived_bundle_hashes_tamper_and_retention(self):
  import gzip,shutil
  from dcflight.swift_qualifier_recovery import recover,verify_bundle
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);graphs=root/'graphs';graphs.mkdir();raw=gzip.compress(b'{"symbols": []}',mtime=0);(graphs/'Empty.symbols.json.gz').write_bytes(raw)
   out=root/'derived';report=recover(graphs,'Empty',out,demangler=shutil.which('true'))
   self.assertEqual((out/'original/Empty.symbols.json.gz').read_bytes(),raw)
   self.assertTrue(verify_bundle(out)['verified']);self.assertEqual(report['changes'],[])
   for path in [out/'original/Empty.symbols.json.gz',out/'Empty.symbols.json']:
    before=path.read_bytes();path.write_bytes(before+b' ')
    with self.assertRaises(ValueError):verify_bundle(out)
    path.write_bytes(before)
   manifest=out/'qualifier-recovery.json';saved=manifest.read_bytes();external=root/'external.json';external.write_bytes(saved);manifest.unlink();manifest.symlink_to(external)
   with self.assertRaises(ValueError):verify_bundle(out)
   manifest.unlink();manifest.write_bytes(saved)
   original=out/'original';original.rename(out/'saved-original');original.symlink_to(out/'saved-original',target_is_directory=True)
   with self.assertRaises(ValueError):verify_bundle(out)
   original.unlink();(out/'saved-original').rename(original)
   with self.assertRaises(ValueError):recover(graphs,'Empty',out,demangler=shutil.which('true'))
if __name__=='__main__':unittest.main()
