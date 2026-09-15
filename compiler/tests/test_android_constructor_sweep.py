import contextlib
import io
import unittest
from unittest.mock import patch

from dcflight.platforms.android_api import AndroidAPI
from tools.verify_android_generics import constructor_probes, main


SDK = '''package java.lang {
 public abstract class Number {
 }
 public class Integer extends java.lang.Number {
 }
}
package sample {
 public class Box<E> {
  ctor public Box();
  ctor public <T, U> Box(T, U);
  ctor public <T extends java.lang.Number> Box(T);
  ctor private <T> Box(T, int);
 }
}'''


class ConstructorSweepTests(unittest.TestCase):
    def test_samples_constructor_formals_and_preserves_candidate_identity(self):
        owner = 'sample.Box<java.lang.String>'
        accepted, rejected = constructor_probes(AndroidAPI(SDK), [owner],
                                                 ['java.lang.String', 'java.lang.Integer'])
        plain = [r for r in accepted if r['id'] == 'sample.Box#<init>()']
        self.assertEqual(1, len(plain))
        self.assertIsNone(plain[0]['typeArguments'])
        pairs = [r for r in accepted if r['id'] == 'sample.Box#<init>(T,U)']
        self.assertEqual([['java.lang.String'] * 2, ['java.lang.Integer'] * 2],
                         [r['typeArguments'] for r in pairs])
        self.assertIn('java.lang.String argument0, java.lang.String argument1', pairs[0]['method'])
        self.assertIn('new <java.lang.String, java.lang.String>', pairs[0]['expression'])
        self.assertEqual(4, len(accepted))
        self.assertEqual(3, len(rejected))
        self.assertTrue(all(r['constructedType'] == owner for r in accepted + rejected))
        self.assertTrue(all(r['resultType'] == owner for r in accepted))
        bound = next(r for r in rejected if r['id'] == 'sample.Box#<init>(T)')
        self.assertEqual(['java.lang.String'], bound['typeArguments'])
        self.assertIn('bound', bound['reason'])
        hidden = [r for r in rejected if r['id'] == 'sample.Box#<init>(T,int)']
        self.assertEqual(2, len(hidden))
        self.assertTrue(all('non-public' in r['reason'] for r in hidden))

    def test_missing_candidates_do_not_infer_generic_specialization(self):
        accepted, rejected = constructor_probes(AndroidAPI(SDK), ['sample.Box<java.lang.String>'])
        self.assertEqual(1, len(accepted))
        self.assertEqual(3, len(rejected))
        self.assertTrue(all(r['typeArguments'] is None for r in accepted + rejected))

    def test_constructor_candidate_cli_rejects_wrong_mode_and_excess(self):
        common = ['sweep', '--source', '/missing-source', '--android-jar', '/missing-jar',
                  '--javac', '/missing-javac', '--report', '/missing-report']
        cases = [(['--type', 'java.lang.String', '--constructor-type', 'java.lang.String'],
                  '--constructor-type requires --construct'),
                 (['--construct', 'sample.Box<java.lang.String>'] +
                  ['--constructor-type', 'java.lang.String'] * 17,
                  'maximum 16')]
        for options, message in cases:
            with self.subTest(options=options):
                error = io.StringIO()
                with patch('sys.argv', common + options), contextlib.redirect_stderr(error):
                    with self.assertRaises(SystemExit) as result:
                        main()
                self.assertEqual(2, result.exception.code)
                self.assertIn(message, error.getvalue())
