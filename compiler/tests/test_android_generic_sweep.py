import unittest
from dcflight.platforms.android_api import AndroidAPI
from tools.verify_android_generics import probes, owner_probes, constructor_probes


class GenericSweepTests(unittest.TestCase):
    def test_probes_keep_candidate_identity_and_rejections(self):
        api=AndroidAPI('''package sample {
 public class Calls {
  method public static <T> T value(T);
  method public <T extends java.lang.Number> T number(T);
  method private static <T> T hidden(T);
  method public static int plain(int);
 }
}''')
        accepted,rejected=probes(api,['java.lang.String','java.lang.Object'])
        self.assertEqual(2,len(accepted))
        self.assertEqual(4,len(rejected))
        self.assertEqual({'sample.Calls#value(T)'},{r['id'] for r in accepted})
        self.assertEqual(['java.lang.String'],accepted[0]['typeArguments'])
        self.assertIn('return sample.Calls.<java.lang.String>value',accepted[0]['method'])
        self.assertTrue(any('non-public' in r['reason'] for r in rejected))
        self.assertTrue(any('bound' in r['reason'] for r in rejected))

    def test_owner_probes_preserve_receiver_identity_and_rejections(self):
        api=AndroidAPI("""package sample {
 public class Box<T> {
  method public T get();
  method public void put(T);
  method private T hidden();
  method public static int unrelated();
 }
}""")
        accepted,rejected=owner_probes(api,['sample.Box<java.lang.String>'])
        self.assertEqual(2,len(accepted))
        self.assertEqual(1,len(rejected))
        self.assertTrue(all(r['receiverType']=='sample.Box<java.lang.String>' for r in accepted))
        self.assertIn('java.lang.String argument0',next(r['method'] for r in accepted if r['id'].endswith('#put(T)')))
        self.assertIn('non-public',rejected[0]['reason'])

    def test_constructor_probes_preserve_owner_and_rejections(self):
        api=AndroidAPI("""package sample {
 public class Box<T> {
  ctor public Box(T);
  ctor private Box();
 }
}""")
        accepted,rejected=constructor_probes(api,['sample.Box<java.lang.String>'])
        self.assertEqual(1,len(accepted));self.assertEqual(1,len(rejected))
        self.assertEqual('sample.Box<java.lang.String>',accepted[0]['resultType'])
        self.assertIn('new sample.Box<java.lang.String>',accepted[0]['expression'])
        self.assertIn('non-public',rejected[0]['reason'])
