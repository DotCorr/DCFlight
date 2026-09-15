import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog


class SweepNormalizationTests(unittest.TestCase):
    def test_sweep_preserves_owner_actor_context_like_verification(self):
        tool=Path(__file__).parents[1]/'tools/sweep_ios_sdk.py'
        spec=importlib.util.spec_from_file_location('sweep',tool)
        sweep=importlib.util.module_from_spec(spec);spec.loader.exec_module(sweep)
        symbols=[{'identifier':{'precise':'owner'},'kind':{'identifier':'swift.class'},
                  'pathComponents':['Widget'],'declarationFragments':[{'spelling':'@MainActor public class Widget'}]},
                 {'identifier':{'precise':'member'},'kind':{'identifier':'swift.method'},
                  'pathComponents':['Widget','read()'],'declarationFragments':[{'spelling':'func read() -> Int'}],
                  'functionSignature':{'parameters':[],'returns':[{'spelling':'Int'}]}}]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);graph=root/'Fixture.symbols.json';output=root/'records.jsonl'
            graph.write_text(json.dumps({'symbols':symbols}))
            counts,_=sweep.normalize_graphs([graph],'Fixture',output)
            records=[json.loads(s) for s in output.read_text().splitlines()]
            self.assertEqual(list(SDKCatalog.from_symbolgraphs([graph],'Fixture').records()),records)
            member=next(r for r in records if r['id']=='member')
            self.assertEqual('main',member['actorIsolation'])
            self.assertEqual('class',member['ownerKind'])
            self.assertEqual(2,counts['indexed'])
            self.assertEqual(0,counts['native_tested'])
            original=output.read_bytes();graph.write_text('{"symbols":[')
            with self.assertRaises(ValueError):sweep.normalize_graphs([graph],'Fixture',output)
            self.assertEqual(original,output.read_bytes())
