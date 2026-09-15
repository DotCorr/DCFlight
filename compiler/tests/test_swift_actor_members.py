from dataclasses import replace
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference, Literal


def catalog(folder):
    symbols=[
        {'identifier':{'precise':'owner'},'kind':{'identifier':'swift.class'},'pathComponents':['Counter'],'declarationFragments':[{'spelling':'public actor Counter'}]},
        {'identifier':{'precise':'increment'},'kind':{'identifier':'swift.method'},'pathComponents':['Counter','increment()'],'declarationFragments':[{'spelling':'func increment() -> Int32'}],'functionSignature':{'parameters':[],'returns':[{'spelling':'Int32'}]}},
        {'identifier':{'precise':'value'},'kind':{'identifier':'swift.property'},'pathComponents':['Counter','value'],'declarationFragments':[{'spelling':'var value: Int32 { get set }'}]},
        {'identifier':{'precise':'constant'},'kind':{'identifier':'swift.method'},'pathComponents':['Counter','constant()'],'declarationFragments':[{'spelling':'nonisolated func constant() -> Int32'}],'functionSignature':{'parameters':[],'returns':[{'spelling':'Int32'}]}}
    ]
    path=Path(folder)/'Fixture.symbols.json';path.write_text(json.dumps({'symbols':symbols}))
    return SDKCatalog.from_symbolgraphs([path],'Fixture')


class SwiftActorMemberTests(unittest.TestCase):
    def test_owner_isolation_async_opt_in_and_setter_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            sdk=catalog(folder);actor=Reference('counter','Counter')
            member=sdk.get('increment')
            self.assertEqual('actor',member.owner_kind)
            self.assertEqual('instance',member.actor_isolation)
            restored=SDKCatalog.from_records([member.to_dict()]).get('increment')
            self.assertEqual(member,restored)
            with self.assertRaisesRegex(ValueError,'async/throws'):sdk.emit_call('increment',receiver=actor)
            self.assertIn('await',sdk.emit_call('increment',receiver=actor,allow_async=True).expression)
            self.assertNotIn('await',sdk.emit_call('constant',receiver=actor).expression)
            with self.assertRaisesRegex(ValueError,'mutated through actor methods'):
                sdk.emit_set('value',Literal(2),receiver=actor)
            broken=replace(member,owner_kind='class')
            with self.assertRaises(ValueError):SDKCatalog.from_records([broken.to_dict()])

    @unittest.skipUnless(shutil.which('swiftc'),'Swift compiler required')
    def test_native_actor_method_and_property_execution(self):
        with tempfile.TemporaryDirectory() as folder:
            sdk=catalog(folder);actor=Reference('counter','Counter')
            method=sdk.emit_call('increment',receiver=actor,allow_async=True).expression
            getter=sdk.emit_call('value',receiver=actor,allow_async=True).expression
            plain=sdk.emit_call('constant',receiver=actor).expression
            source='''actor Counter {
 var value: Int32 = 0
 func increment() -> Int32 { value += 1; return value }
 nonisolated func constant() -> Int32 { 42 }
}
@main struct Run {
 static func main() async {
 let counter = Counter()
'''+ 'let first = '+method+'\nlet value = '+getter+'\nlet constant = '+plain+'''
 precondition(first == 1 && value == 1 && constant == 42)
 print("native actor access passed")
 }
}
'''
            path=Path(folder)/'Run.swift';exe=Path(folder)/'Run';path.write_text(source)
            build=subprocess.run(['swiftc','-swift-version','6','-parse-as-library',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
            self.assertIn('native actor access passed',run.stdout)
