from ios_sdk_fixture import fake_toolchain, write_sdk
import gzip
import importlib.util
import json
import runpy
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('ios_batch', Path(__file__).parents[1] / 'tools/verify_ios_api_batch.py')
batch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(batch)


class IOSBatchHarnessTests(unittest.TestCase):
    def run_batch(self, root, symbols, ios_version='18.0', swift_version='5'):
        graph = root / 'UIKit.symbols.json.gz'
        graph.write_bytes(gzip.compress(json.dumps({'symbols': symbols}).encode()))
        output = root / 'report.json'
        with patch('sys.argv', ['verify', '--module', 'UIKit=' + str(root), '--output', str(output),'--ios-version',ios_version,'--swift-version',swift_version]), \
             patch.object(batch.subprocess, 'check_output', side_effect=fake_toolchain(root,'fixture-toolchain')), \
             patch.object(batch.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='')) as compiler:
            batch.main()
        for call in compiler.call_args_list:
            command=call.args[0]
            self.assertEqual('arm64-apple-ios'+ios_version+'-simulator',command[command.index('-target')+1])
            self.assertEqual(swift_version,command[command.index('-swift-version')+1])
        return json.loads(output.read_text()), compiler.call_count

    def test_deployment_target_controls_availability_and_native_command(self):
        symbol={'identifier':{'precise':'fixture:new'},'kind':{'identifier':'swift.type.property'},
                'pathComponents':['UIApplication','shared'],
                'declarationFragments':[{'spelling':'@MainActor class var shared: UIApplication { get }'}],
                'availability':[{'domain':'iOS','introduced':{'major':26,'minor':0}}]}
        for version,expected in [('18.0',0),('26.2',1)]:
            with self.subTest(version=version),tempfile.TemporaryDirectory() as directory:
                report,calls=self.run_batch(Path(directory),[symbol],version,'6')
                self.assertEqual('6',report['swiftLanguageVersion'])
                self.assertEqual(expected,calls)
                self.assertEqual(expected,report['nativeTested'])
                self.assertEqual([int(x) for x in version.split('.')],report['iosVersion'])

    def test_invalid_deployment_version(self):
        from dcflight.ios_verification import deployment_version
        for value in ('26','0.1','26.2; print(1)','-1.0','26.2.1',None):
            with self.subTest(value=value),self.assertRaises(ValueError):
                deployment_version(value)

    def test_empty_catalog_writes_fresh_zero_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            report, calls = self.run_batch(Path(directory), [])
            self.assertEqual(0, report['candidateCount'])
            self.assertEqual(0, report['nativeTested'])
            self.assertEqual(0, calls)
            self.assertEqual('UIKit.symbols.json.gz', report['inputs']['UIKit'][0]['name'])

    def test_main_actor_descriptor_is_checked_in_declared_context(self):
        # Compiler process is mocked here; this checks harness selection/context,
        # not native conformance. Real SDK batches have separate evidence.
        symbol = {'identifier': {'precise': 'fixture:UIApplication.shared'},
                  'kind': {'identifier': 'swift.type.property'},
                  'pathComponents': ['UIApplication', 'shared'],
                  'declarationFragments': [{'spelling': '@MainActor class var shared: UIApplication { get }'}]}
        with tempfile.TemporaryDirectory() as directory:
            report, calls = self.run_batch(Path(directory), [symbol])
            self.assertEqual([], report['skipped'])
            self.assertEqual(1, calls)
            self.assertEqual(1, report['candidateCount'])
            self.assertIn('@MainActor func', report['passed'][0]['source'])

    def test_existing_report_is_never_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'report.json'
            output.write_text('existing evidence')
            with patch('sys.argv', ['verify', '--module', 'UIKit=' + directory, '--output', str(output)]):
                with self.assertRaises(SystemExit):
                    batch.main()
            self.assertEqual('existing evidence', output.read_text())

    def test_export_rejects_changed_inputs_and_incomplete_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            report,_=self.run_batch(root, [])
            report_path=root/'report.json'
            original=json.dumps(report)
            output=root/'descriptors'
            report['candidateCount']=1
            report_path.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError,'incomplete'):
                batch.export_records({'UIKit':root},report_path,output)
            self.assertFalse(output.exists())
            report_path.write_text(original)
            graph=root/'UIKit.symbols.json.gz'
            graph.write_bytes(gzip.compress(b'{"symbols":[],"metadata":{}}'))
            with self.assertRaisesRegex(ValueError,'changed'):
                batch.export_records({'UIKit':root},report_path,output)
            self.assertFalse(output.exists())

    def test_export_checks_identities_before_writing(self):
        for duplicate in (False,True):
            with self.subTest(duplicate=duplicate),tempfile.TemporaryDirectory() as directory:
                root=Path(directory)
                report,_=self.run_batch(root,[])
                entry={'module':'UIKit','id':'unknown','source':'fixture'}
                report['passed']=[entry,entry] if duplicate else [entry]
                report['nativeTested']=report['candidateCount']=len(report['passed'])
                (root/'report.json').write_text(json.dumps(report))
                with self.assertRaisesRegex(ValueError,'Duplicate|unknown'):
                    batch.export_records({'UIKit':root},root/'report.json',root/'descriptors')
                self.assertFalse((root/'descriptors').exists())

    def test_valid_empty_export_and_existing_output_protection(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            self.run_batch(root,[])
            output=root/'descriptors'
            summary=batch.export_records({'UIKit':root},root/'report.json',output)
            self.assertEqual(0,summary['UIKit']['native_tested'])
            self.assertEqual('',(output/'UIKit.jsonl').read_text())
            with self.assertRaisesRegex(ValueError,'already exists'):
                batch.export_records({'UIKit':root},root/'report.json',output)

    def test_export_rejects_compiler_identity_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            report,_=self.run_batch(root,[])
            report['compilerSources']['ios_verification.py']='changed'
            (root/'report.json').write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError,'Compiler changed'):
                batch.export_records({'UIKit':root},root/'report.json',root/'descriptors')
            self.assertFalse((root/'descriptors').exists())

    def test_cli_propagates_failed_verification_status(self):
        with patch('dcflight.ios_verification.main', return_value=1):
            with self.assertRaises(SystemExit) as result:
                runpy.run_path(str(Path(__file__).parents[1] / 'tools/verify_ios_api_batch.py'), run_name='__main__')
        self.assertEqual(1, result.exception.code)

    def test_native_failure_and_empty_sweep_fail_process_status(self):
        symbol = {'identifier': {'precise': 'fixture:broken'},
                  'kind': {'identifier': 'swift.type.property'},
                  'pathComponents': ['UIApplication', 'shared'],
                  'declarationFragments': [{'spelling': 'class var shared: UIApplication { get }'}]}
        for symbols, native_result, expected in (
                ([symbol], SimpleNamespace(returncode=0, stdout=''), 0),
                ([symbol], SimpleNamespace(returncode=1, stdout='Verify.swift:2:1: error: native rejection'), 1),
                ([], SimpleNamespace(returncode=0, stdout=''), 1)):
            with self.subTest(count=len(symbols), result=native_result.returncode), tempfile.TemporaryDirectory() as directory:
                root=Path(directory)
                (root/'UIKit.symbols.json').write_text(json.dumps({'symbols': symbols}))
                with patch.object(batch.subprocess, 'check_output', side_effect=fake_toolchain(root,'fixture-toolchain')), \
                     patch.object(batch.subprocess, 'run', return_value=native_result):
                    result=batch.main(['--module','UIKit='+directory,'--output',str(root/'report.json')], progress=False)
                self.assertEqual(expected, result)
                report=json.loads((root/'report.json').read_text())
                if native_result.returncode:
                    self.assertEqual(1,report['failedCount'])
                    self.assertEqual(0,report['nativeTested'])
