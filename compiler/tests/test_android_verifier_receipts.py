import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from tools import verify_android_api as verifier


class AndroidVerifierReceiptTests(unittest.TestCase):
    def test_input_fingerprints_and_compiler_change_invalidate_evidence(self):
        for changed in (False, True):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                root=Path(directory)
                source=root/'api.txt'
                source.write_text('package java.lang {\npublic final class Integer {\nfield public static final int MAX_VALUE;\n}\n}\n')
                jar=root/'android.jar';jar.write_bytes(b'fixture only; native subprocess mocked')
                report=root/'report.json'
                def native(command, **kwargs):
                    if '-version' in command: return SimpleNamespace(returncode=0,stdout='fixture-javac',stderr='')
                    if '-d' in command:
                        output=Path(command[command.index('-d')+1])
                        for java in output.glob('AndroidApiConformance*.java'): java.with_suffix('.class').write_bytes(b'fixture')
                    return SimpleNamespace(returncode=0,stdout='',stderr='')
                with patch('sys.argv',['verify','--api',str(source),'--android-jar',str(jar),'--report',str(report)]), \
                     patch.object(verifier.subprocess,'run',side_effect=native), \
                     patch.object(verifier,'compiler_sources',side_effect=[{'source.py':'original'},{'source.py':'changed' if changed else 'original'}]), \
                     patch('builtins.print'):
                    status=verifier.main()
                data=json.loads(report.read_text())
                self.assertEqual(int(changed),status)
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),data['api_source_sha256'])
                self.assertEqual(hashlib.sha256(jar.read_bytes()).hexdigest(),data['android_jar_sha256'])
                self.assertEqual({'source.py':'original'},data['compiler_sources'])
                self.assertEqual(not changed,data['compiler_unchanged'])
                self.assertEqual(0 if changed else 1,data['members_native_tested'])
                self.assertEqual(0 if changed else 1,len(data['native_tested_member_ids']))
                self.assertEqual(64,len(data['verifier_sha256']))
