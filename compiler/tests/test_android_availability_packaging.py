import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

import dcflight
from dcflight.android_class_dependencies import dependency_references
from dcflight.native_api import index_android


class ClassDependencyTests(unittest.TestCase):
    def test_class_entries_include_array_dependencies_but_not_string_literals(self):
        listing='''#1 = Class #2 // [[Ldart/runtime/VM;
#3 = Class #4 // io/flutter/Engine
#5 = String #6 // dcflight/notAClass
#7 = Class #8 // java/lang/String'''
        self.assertEqual(['[[Ldart/runtime/VM;','io/flutter/Engine'],dependency_references(listing))


JDK=Path(os.environ.get('JAVA_HOME','/missing/jdk'))
SDK=Path(os.environ.get('DCFLIGHT_ANDROID_SDK_JAR','/missing/android.jar'))


@unittest.skipUnless((JDK/'bin/javac').is_file() and SDK.is_file(),'JDK and Android SDK required')
class PackagedAvailabilityTests(unittest.TestCase):
    def test_package_only_cli_verifies_imports_and_keeps_progress_on_stderr(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);site=root/'site';site.mkdir()
            shutil.copytree(Path(dcflight.__file__).parent,site/'dcflight',ignore=shutil.ignore_patterns('__pycache__'))
            self.assertFalse((site/'tools').exists())
            fixture=root/'sample/Candidate.java';fixture.parent.mkdir()
            fixture.write_text('package sample; public class Candidate { public static int enabled() { return 7; } }')
            subprocess.run([str(JDK/'bin/javac'),'--release','8',str(fixture)],capture_output=True,check=True)
            sdk=root/'android.jar';shutil.copyfile(SDK,sdk)
            with zipfile.ZipFile(sdk,'a') as jar:jar.write(fixture.with_suffix('.class'),'sample/Candidate.class')
            source=root/'api.txt';source.write_text('''package sample {
 public class Candidate {
  method @FlaggedApi("fixture.present") public static int enabled();
  method @FlaggedApi("fixture.absent") public static int missing();
 }
}''')
            catalog=root/'sdk.sqlite';index_android(catalog,source)
            report=root/'report.json'
            launch='import sys; sys.path.insert(0,sys.argv[1]); from dcflight.cli import main; sys.exit(main(sys.argv[2:]))'
            command=[sys.executable,'-I','-c',launch,str(site),'sdk','verify-android-availability','--source',str(source),'--sdk',str(sdk),'--javac',str(JDK/'bin/javac'),'--api-level','35','--report',str(report),'--catalog',str(catalog)]
            result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=120)
            self.assertEqual(0,result.returncode,result.stderr)
            json.loads(result.stdout)
            progress=[json.loads(line) for line in result.stderr.splitlines() if line.startswith('{')]
            self.assertEqual({'processed':2,'candidates':2,'compiled':1},progress[-1])
            evidence=json.loads(report.read_text());self.assertEqual(2,evidence['candidateCount']);self.assertEqual(1,evidence['compiledCount']);self.assertTrue(evidence['dependencyScanPassed'])
            self.assertEqual(['sample.Candidate#enabled()'],[row['id'] for row in evidence['members'] if row['compiled']])
            repeated=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(0,repeated.returncode);self.assertIn('fresh report',repeated.stderr)
            self.assertEqual(evidence,json.loads(report.read_text()))
            standalone=command[:-2]
            standalone[standalone.index('--report')+1]=str(root/'standalone.json')
            result=subprocess.run(standalone,cwd=root,capture_output=True,text=True,timeout=120)
            self.assertEqual(0,result.returncode,result.stderr)
            self.assertEqual({'candidates':2,'compiled':1},json.loads(result.stdout))


if __name__=='__main__':unittest.main()
