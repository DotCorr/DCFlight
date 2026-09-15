import copy
import json
from pathlib import Path
import tempfile
import unittest
from dcflight.catalog import Catalog
from tools.import_android_core_evidence import record

class CoreEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.db=self.root/'sdk.db';self.report=self.root/'report.json'
        with Catalog(self.db,write=True) as c:
            c.import_records('android','core-bytecode','35',[{'id':'fixture#call()','name':'call','owner':'fixture','kind':'method','emittable':True}],{'sourceSha256':'source','sdkArchiveSha256':'archive'})
        self.data={'compilation_passed':True,'runtime_dependency_scan_passed':True,'android_core_boot_stubs':True,
            'native_tested_member_ids':['fixture#call()'],'probed_member_ids':['fixture#call()'],
            'members_native_tested':1,'probe_count':1,'forbidden_class_references':[],
            'source_sha256':'source','android_jar_sha256':'archive','api_level':35,
            'command':'/jdk/bin/javac -bootclasspath captured.jar Probe.java','javac':'/jdk/bin/javac','javac_version':'javac fixture'}

    def evidence(self):
        with Catalog(self.db) as c:
            return c.connection.execute('SELECT COUNT(*) FROM evidence').fetchone()[0]

    def test_preserves_actual_command_without_execution_claim(self):
        self.report.write_text(json.dumps(self.data))
        self.assertEqual({'scope':'core-bytecode','compiled':1,'executed':0},record(self.db,self.report))
        with Catalog(self.db) as c:
            row=c.get('android','fixture#call()','core-bytecode')
            text=json.dumps(row)
            self.assertIn('/jdk/bin/javac -bootclasspath captured.jar Probe.java',text)
            self.assertIn('javac fixture',text)
        self.assertEqual(1,self.evidence())

    def test_inconsistent_or_stale_reports_never_mark_verified(self):
        mutations=[{'probed_member_ids':['different']},{'probe_count':2},{'probe_count':True},
            {'members_native_tested':True},{'forbidden_class_references':['dart/Engine']},
            {'source_sha256':'changed'},{'android_jar_sha256':'changed'},{'api_level':34},
            {'android_core_boot_stubs':False},{'command':''},{'javac_version':None},
            {'native_tested_member_ids':['unknown'],'probed_member_ids':['unknown']}]
        for mutation in mutations:
            self.report.write_text(json.dumps({**self.data,**mutation}))
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):record(self.db,self.report)
            self.assertEqual(0,self.evidence())
        self.report.write_text('{"compilation_passed":false,"compilation_passed":true}')
        with self.assertRaises(ValueError):record(self.db,self.report)
        self.assertEqual(0,self.evidence())

    def test_unknown_later_identity_rolls_back_the_entire_evidence_batch(self):
        data=copy.deepcopy(self.data)
        data.update(native_tested_member_ids=['fixture#call()','missing'],probed_member_ids=['fixture#call()','missing'],members_native_tested=2,probe_count=2)
        self.report.write_text(json.dumps(data))
        with self.assertRaises(ValueError):record(self.db,self.report)
        self.assertEqual(0,self.evidence())
