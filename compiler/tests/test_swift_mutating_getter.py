from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import _descriptor,SDKCatalog,Reference


class MutatingGetterTests(unittest.TestCase):
    def member(self):
        symbol={'identifier':{'precise':'next'},'kind':{'identifier':'swift.property'},'pathComponents':['Counter','next'],
                'declarationFragments':[{'spelling':'var next: Int32 { mutating get }'}]}
        return _descriptor(symbol,'Fixture',{('Counter',):'struct'})

    def test_import_and_mutable_receiver_requirement(self):
        member=self.member();self.assertTrue(member.mutating)
        sdk=SDKCatalog.from_records([member.to_dict()])
        with self.assertRaisesRegex(ValueError,'mutable receiver'):
            sdk.emit_call(member.id,receiver=Reference('counter','Counter'))
        self.assertEqual('`counter`.`next`',sdk.emit_call(member.id,receiver=Reference('counter','Counter',mutable=True)).expression)

    @unittest.skipUnless(shutil.which('swiftc'),'Swift compiler required')
    def test_native_getter_mutates_the_original_binding(self):
        member=self.member();sdk=SDKCatalog([member])
        expression=sdk.emit_call(member.id,receiver=Reference('counter','Counter',mutable=True)).expression
        source='''struct Counter {
 var count: Int32 = 0
 var next: Int32 { mutating get { count += 1; return count } }
}
var counter = Counter()
'''+ 'let first = '+expression+'\nlet second = '+expression+'''
precondition(first == 1 && second == 2 && counter.count == 2)
print("mutating getter passed")
'''
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'Check.swift';exe=Path(folder)/'Check';path.write_text(source)
            build=subprocess.run(['swiftc','-swift-version','6',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
            self.assertIn('mutating getter passed',run.stdout)
