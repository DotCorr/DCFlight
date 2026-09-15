from ios_sdk_fixture import fake_toolchain, write_sdk
import copy
import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('ios_sweep_explicit',Path(__file__).resolve().parents[1]/'tools/sweep_ios_sdk.py')
sweep=importlib.util.module_from_spec(spec);spec.loader.exec_module(sweep)
class ExplicitModuleTests(unittest.TestCase):
    def setUp(self):
        self.entries=[{'module':'Foundation','excluded':False,'exclusionReason':None,'category':'framework','extractionAdapter':'swift-symbolgraph'}, {'module':'_Concurrency','excluded':True,'exclusionReason':'underscore-prefixed implementation module','category':'swift-overlay','extractionAdapter':'swift-symbolgraph'}, {'module':'std','excluded':True,'exclusionReason':'C++','category':'cxx-module','extractionAdapter':'cxx-required'}]
    def test_default_retains_exclusions(self):
        self.assertEqual(sweep.selected_inventory(self.entries,None),self.entries)
    def test_explicit_opt_in_preserves_input_and_reports_reason(self):
        before=copy.deepcopy(self.entries);out=sweep.selected_inventory(self.entries,['_Concurrency'])
        self.assertEqual(self.entries,before);self.assertFalse(out[1]['excluded'])
        self.assertEqual(out[1]['defaultExclusionReason'],before[1]['exclusionReason'])
        self.assertIn('applicability unverified',out[1]['selectionReason']);self.assertTrue(out[2]['excluded'])
    def test_unknown_and_cpp_reject(self):
        for names,reason in [(['Missing'],'Unknown SDK'),(['std'],'C\\+\\+'),(['_Concurrency','Missing'],'Unknown SDK')]:
            with self.subTest(names=names),self.assertRaisesRegex(ValueError,reason):sweep.selected_inventory(self.entries,names)
    def test_empty_selection_does_not_opt_in(self):
        self.assertEqual(sweep.selected_inventory(self.entries,[]),self.entries)
    def test_other_exclusion_cannot_bypass(self):
        self.entries[0]['excluded']=True
        with self.assertRaisesRegex(ValueError,'cannot use'):sweep.selected_inventory(self.entries,['Foundation'])

class ExplicitResumeTests(unittest.TestCase):
    def test_sequential_main_opt_ins_preserve_inventory_and_receipts(self):
        import tempfile,json,contextlib,io,sys
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve();sdk=root/'sdk';sdk.mkdir();write_sdk(sdk)
            entries=[]
            for name in ['_A','_B']:
                graph=root/name;graph.mkdir();(graph/(name+'.symbols.json')).write_text(json.dumps({'module':{'name':name},'symbols':[],'relationships':[]}))
                entries.append({'module':name,'excluded':True,'exclusionReason':'underscore','category':'swift-overlay','extractionAdapter':'swift-symbolgraph'})
            def command(*args):
                return '26.2' if '--show-sdk-version' in args else str(sdk) if '--show-sdk-path' in args else str(Path(sweep.__file__)) if '--find' in args else 'fixture'
            out=root/'out'
            def run(selection):
                argv=['sweep','--output',str(out),'--min-free-mb','0','--reuse','_A='+str(root/'_A'),'--reuse','_B='+str(root/'_B')]
                if selection is not None:argv+=['--modules',selection]
                with patch.object(sweep,'command',command),patch.object(sweep,'compiler_sources',lambda:{}),patch.object(sweep,'discover',lambda _:copy.deepcopy(entries)),patch.object(__import__('sys'),'argv',argv),contextlib.redirect_stdout(io.StringIO()):sweep.main()
            run('_A');before=(out/'_A/status.json').read_bytes();graph_before=list((out/'_A/symbolgraphs').glob('*'))[0].read_bytes()
            run('_B');run(None)
            inventory=json.loads((out/'inventory.json').read_text())
            self.assertEqual([entry['excluded'] for entry in inventory],[False,False])
            self.assertEqual((out/'_A/status.json').read_bytes(),before)
            self.assertEqual(list((out/'_A/symbolgraphs').glob('*'))[0].read_bytes(),graph_before)
            self.assertEqual(json.loads((out/'coverage.json').read_text())['moduleCounts']['success'],2)
    def test_malformed_or_changed_prior_opt_in_rejected(self):
        entries=ExplicitModuleTests();entries.setUp()
        prior=sweep.selected_inventory(entries.entries,['_Concurrency'])
        prior[1]['selectionReason']='arbitrary bypass'
        with self.assertRaisesRegex(ValueError,'applicability changed'):sweep.preserve_explicit_modules(entries.entries,prior)
        with self.assertRaisesRegex(ValueError,'Invalid previous'):sweep.preserve_explicit_modules(entries.entries,{})
