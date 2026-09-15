import json
from pathlib import Path
import shutil
import tempfile
import unittest
from dcflight.ios_verification import main


class IOSVerificationResultTypesTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('xcrun'),'Apple SDK toolchain required')
    def test_native_property_type_mismatch_cannot_be_certified_by_discarding_result(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);graphs=root/'graphs';graphs.mkdir()
            # A stale/wrong imported signature: the real Foundation property is Double.
            symbol={'identifier':{'precise':'fixture:wrong-date-result'},'kind':{'identifier':'swift.property'},
                    'pathComponents':['Date','timeIntervalSince1970'],
                    'declarationFragments':[{'spelling':'var timeIntervalSince1970: String { get }'}]}
            (graphs/'Fixture.symbols.json').write_text(json.dumps({'symbols':[symbol]}))
            report=root/'report.json'
            main(['--module','Foundation='+str(graphs),'--limit','0','--swift-version','6','--output',str(report)],progress=False)
            result=json.loads(report.read_text())
            self.assertEqual(0,result['nativeTested'])
            self.assertEqual(1,result['failedCount'])
            self.assertIn('let _: String =',result['failed'][0]['source'])
            self.assertTrue(any('String' in message for message in result['failed'][0]['errors']))

    def test_protocol_initializer_is_not_concrete_construction(self):
        from dcflight.platforms.ios_api import SDKCatalog, API
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);graph=root/'Fixture.symbols.json'
            graph.write_text(json.dumps({'symbols':[
                {'identifier':{'precise':'owner'},'kind':{'identifier':'swift.protocol'},'pathComponents':['Named']},
                {'identifier':{'precise':'init'},'kind':{'identifier':'swift.init'},'pathComponents':['Named','init()'],
                 'declarationFragments':[{'spelling':'init()'}],'functionSignature':{'parameters':[]}}]}))
            catalog=SDKCatalog.from_symbolgraphs([graph],'Fixture')
            self.assertIn('protocol construction', '; '.join(catalog.get('init').unsupported))
            with self.assertRaisesRegex(ValueError,'concrete conforming type'):catalog.emit_call('init')
        forged=API('init','Fixture',('Named','init()'),'constructor',(),'Named',(),(),owner_kind='protocol')
        with self.assertRaisesRegex(ValueError,'concrete conforming type'):SDKCatalog.from_records([forged.to_dict()])
