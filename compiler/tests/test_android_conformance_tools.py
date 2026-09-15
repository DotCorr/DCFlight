import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from tools.verify_android_api import dependency_references

class AndroidDependencyProbeTests(unittest.TestCase):
    def test_real_dependencies_not_identifier_substrings(self):
        jdk=Path(os.environ.get('JAVA_HOME','/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/toolchains/jdk-17.0.20.1+1/Contents/Home'))/'bin'
        if not (jdk/'javac').is_file():self.skipTest('JDK required')
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'dart').mkdir()
            (root/'dart/Engine.java').write_text('package dart; public class Engine { public static void run() {} }')
            (root/'Safe.java').write_text('class Safe { String call(java.util.Calendar value) { return value.getCalendarType(); } }')
            (root/'Unsafe.java').write_text('class Unsafe { void call() { dart.Engine.run(); } }')
            subprocess.run([str(jdk/'javac'),'-d',str(root),str(root/'dart/Engine.java'),str(root/'Safe.java'),str(root/'Unsafe.java')],check=True,capture_output=True)
            self.assertIn(b'dart',(root/'Safe.class').read_bytes().lower())
            def scan(name):
                result=subprocess.run([str(jdk/'javap'),'-verbose',str(root/(name+'.class'))],check=True,capture_output=True,text=True)
                return dependency_references(result.stdout)
            self.assertEqual([],scan('Safe'))
            self.assertEqual(['dart/Engine'],scan('Unsafe'))
