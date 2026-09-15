import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.backends.ios import IOS
from dcflight.backends.android import Android

class UTF8ActionDispatchTests(unittest.TestCase):
    def test_generated_legacy_models_dispatch_failure_before_assignment(self):
        if not shutil.which('swiftc') or not shutil.which('javac') or not shutil.which('java'):
            self.skipTest('Swift and Java toolchains required')
        doc={'version':1,'id':'com.example.utf8','name':'UTF8','state':{'text':'ok','result':0},
             'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':'readText','parameters':['utf8'],'returns':'int32'}]},
             'actions':[{'id':'read','op':'call','function':'readText','args':[{'ref':'text'}],'target':'result','failure':'failed'},
                        {'id':'failed','op':'set','target':'result','value':-1}],
             'root':{'id':'root','type':'text','props':{'text':'Text'}}}
        registry=Registry();app=lower(doc,registry)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            swift=IOS().generate(app,registry)['ios/App/Generated/AppModel.swift'].content
            (root/'AppModel.swift').write_text(swift)
            # The real borrowed-buffer facade is tested on mobile separately.
            # This deliberate throwing callee isolates generated action dispatch.
            (root/'main.swift').write_text('''enum InputError: Error { case invalid }
enum AppLogicUTF8 { static func f_readText(_ text: String) throws -> Int32 { if text == "bad" { throw InputError.invalid }; return 73 } }
let model=AppModel(); model.a_read(); precondition(model.s_result==73)
model.s_text="bad"; model.a_read(); precondition(model.s_result == -1)
model.s_text="ok"; model.a_read(); precondition(model.s_result == 73)
print("PASS")
''')
            build=subprocess.run(['swiftc','-module-cache-path',str(root/'cache'),str(root/'AppModel.swift'),str(root/'main.swift'),'-o',str(root/'swift-check')],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run([str(root/'swift-check')],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr);self.assertEqual('PASS',run.stdout.strip())
            java=Android().generate(app,registry)['android/app/src/main/java/com/example/utf8/AppModel.java'].content
            package=root/'com/example/utf8';package.mkdir(parents=True)
            (package/'AppModel.java').write_text(java)
            (package/'SharedLogic.java').write_text('''package com.example.utf8;
public final class SharedLogic {
 public static class InputFailure extends RuntimeException {}
 public static int f_readText(String text) { if(text.equals("bad")) throw new InputFailure(); return 73; }
}
''')
            (package/'Main.java').write_text('''package com.example.utf8;
public class Main { public static void main(String[] args) {
 AppModel model=new AppModel(); model.a_read(); if(model.s_result!=73)throw new AssertionError();
 model.s_text="bad";model.a_read();if(model.s_result!=-1)throw new AssertionError();
 model.s_text="ok";model.a_read();if(model.s_result!=73)throw new AssertionError();System.out.print("PASS");
}}
''')
            build=subprocess.run(['javac','--release','8','-d',str(root),*[str(p) for p in package.glob('*.java')]],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run(['java','-cp',str(root),'com.example.utf8.Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr);self.assertEqual('PASS',run.stdout.strip())
