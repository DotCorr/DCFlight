import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dataclasses import replace
from dcflight.platforms.ios_api import API, Parameter, SDKCatalog, Literal, Reference, _descriptor


def api():
    return API('test:choose','Fixture',('choose(_:_:)',),'function',
               (Parameter('_','enabled','Bool'),Parameter('_','value','() -> Int32',autoclosure=True)),
               'Int32',(),())


class AutoclosureTests(unittest.TestCase):
    def test_metadata_roundtrip_and_invalid_contracts(self):
        original=api()
        restored=SDKCatalog.from_records([original.to_dict()]).get(original.id)
        self.assertTrue(restored.parameters[1].autoclosure)
        for typ in ('Int32','(Int32) -> Int32','() throws -> Int32','(() -> Int32)?'):
            broken=replace(original,parameters=(original.parameters[0],replace(original.parameters[1],type=typ)))
            with self.subTest(typ=typ),self.assertRaises(ValueError):
                SDKCatalog([broken]).emit_call(broken.id,[Literal(True),Reference('next',typ)])
        broken=replace(original,parameters=(original.parameters[0],replace(original.parameters[1],autoclosure='yes')))
        with self.assertRaises(ValueError):SDKCatalog.from_records([broken.to_dict()])

    def test_symbolgraph_declared_autoclosure_is_preserved(self):
        graph={'identifier':{'precise':'choose'},'kind':{'identifier':'swift.func'},'pathComponents':['choose(_:)'],
               'declarationFragments':[{'spelling':'func choose('},{'kind':'externalParam','spelling':'_'},{'spelling':' value: @autoclosure () -> Int32) -> Int32'}],
               'functionSignature':{'parameters':[{'name':'value','declarationFragments':[{'spelling':'value: () -> Int32'}]}],'returns':[{'spelling':'Int32'}]}}
        result=_descriptor(graph,'Fixture')
        self.assertTrue(result.parameters[0].autoclosure)
        self.assertEqual('() -> Int32',result.parameters[0].type)
        graph['functionSignature']['parameters'][0]['declarationFragments'][0]['spelling']='value: @autoclosure @escaping () -> Int32'
        result=_descriptor(graph,'Fixture')
        self.assertTrue(result.parameters[0].escaping)
        self.assertTrue(result.parameters[0].autoclosure)

    @unittest.skipUnless(shutil.which('swiftc'),'Swift compiler required')
    def test_native_lazy_evaluation(self):
        member=api();catalog=SDKCatalog([member])
        def call(enabled):return catalog.emit_call(member.id,[Literal(enabled),Reference('next','() -> Int32')]).expression
        source='''var evaluations: Int32 = 0
func next() -> Int32 { evaluations += 1; return evaluations }
func choose(_ enabled: Bool, _ value: @autoclosure () -> Int32) -> Int32 { enabled ? value() : 0 }
'''
        source+='let skipped = '+call(False)+'\nprecondition(skipped == 0 && evaluations == 0)\n'
        source+='let used = '+call(True)+'\nprecondition(used == 1 && evaluations == 1)\nprint("lazy forwarding passed")\n'
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'Check.swift';exe=Path(folder)/'Check';path.write_text(source)
            build=subprocess.run(['swiftc',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
            self.assertIn('lazy forwarding passed',run.stdout)
