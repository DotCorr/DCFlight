import unittest
from dcflight.platforms.android_api import AndroidAPI, JavaValue

SDK = '''// Signature format: 2.0
package android.test {
  public class Parent {
    method public void display(@NonNull CharSequence);
    method public void display(int);
    method public static String name();
    field public static final int FLAG = 1;
    field public int value;
    method public <T> T generic(Class<T>);
    method protected void hidden();
  }
  public class Child extends android.test.Parent {
    ctor public Child();
    method public void take(android.test.Parent);
    method public void nullable(@Nullable String);
    method @FlaggedApi("new.feature") public void future();
    method public void record(String[]);
    method public void values(String...);
  }
  public abstract class Abstract {
    ctor public Abstract();
  }
  @FlaggedApi("new.owner") public class Future {
    ctor public Future();
  }
  public static class Future.Builder {
    ctor public Future.Builder();
  }
  public class Inner.Child {
    ctor public Inner.Child();
  }
  public class Generic<T extends android.test.Parent> {
    method public void ordinary();
  }
  public class Bad implements java.lang.Comparable<java.lang.String> {
    method public void ordinary();
  }
}
'''


class AndroidAPITests(unittest.TestCase):
    def setUp(self): self.api = AndroidAPI(SDK)

    def test_overloads_have_stable_typed_ids(self):
        self.assertEqual(2, len(self.api.search('Parent#display(')))
        expression = self.api.emit('android.test.Parent#display(java.lang.CharSequence)', [JavaValue.literal('Hello')], JavaValue.reference('button', 'android.test.Child'))
        self.assertEqual('((android.test.Parent) button).display((java.lang.CharSequence) ("Hello"))', expression.source)
        self.assertEqual('void', expression.java_type)

    def test_constructor_static_and_fields(self):
        self.assertEqual('new android.test.Child()', self.api.emit('android.test.Child#<init>()').source)
        self.assertEqual('android.test.Parent.name()', self.api.emit('android.test.Parent#name()').source)
        self.assertEqual('android.test.Parent.FLAG', self.api.emit('android.test.Parent#FLAG').source)
        self.assertEqual('((android.test.Parent) item).value', self.api.emit('android.test.Parent#value', receiver=JavaValue.reference('item', 'android.test.Parent')).source)

    def test_nullability(self):
        with self.assertRaisesRegex(ValueError, 'nonnull'):
            self.api.emit('android.test.Parent#display(java.lang.CharSequence)', [JavaValue.null('CharSequence')], JavaValue.reference('item', 'android.test.Parent'))
        self.api.emit('android.test.Child#nullable(java.lang.String)', [JavaValue.null('String')], JavaValue.reference('item', 'android.test.Child'))

    def test_fail_closed(self):
        for member_id in ['android.test.Child#future()', 'android.test.Parent#hidden()', 'android.test.Abstract#<init>()', 'android.test.Future.Builder#<init>()', 'android.test.Inner.Child#<init>()']:
            with self.assertRaises(ValueError, msg=member_id): self.api.emit(member_id)
        self.assertFalse(self.api.search('#generic(')[0].emittable)
        with self.assertRaises(ValueError): self.api.emit('unknown')
        with self.assertRaises(ValueError): self.api.emit('android.test.Child#<init>()', [JavaValue.literal(1)])
        with self.assertRaises(ValueError): self.api.emit('android.test.Parent#display(int)', [JavaValue.literal('wrong')], JavaValue.reference('item', 'android.test.Parent'))
        with self.assertRaises(ValueError): self.api.emit('android.test.Parent#name()', receiver=JavaValue.reference('item', 'android.test.Parent'))

    def test_no_snippet_or_identifier_injection(self):
        for name in ['a.b', 'foo();evil()', 'class', 'x\\u000a']:
            with self.assertRaises(ValueError): JavaValue.reference(name, 'String')
        with self.assertRaises(ValueError): JavaValue('expression', 'evil()', 'String')
        with self.assertRaises(ValueError): JavaValue.reference('item', 'String;evil()')
        with self.assertRaises(ValueError): JavaValue.literal(float('nan'))
        with self.assertRaises(ValueError): JavaValue.literal(2**50)
        self.assertEqual('"\\\";evil();\\n"', JavaValue.literal('";evil();\n').source())

    def test_generic_bounds_do_not_create_false_inheritance(self):
        self.assertFalse(self.api.is_assignable('android.test.Generic', 'android.test.Parent'))
        self.assertFalse(self.api.is_assignable('android.test.Bad', 'java.lang.String'))
        self.assertTrue(self.api.is_assignable('android.test.Child', 'android.test.Parent'))
        self.assertIn('android.test.Generic<?>', self.api.emit('android.test.Generic#ordinary()', receiver=JavaValue.reference('item', 'android.test.Generic')).source)

    def test_records_separate_emittable_from_tested_and_availability(self):
        record = next(r for r in self.api.records() if r['id'] == 'android.test.Parent#display(java.lang.CharSequence)')
        self.assertTrue(record['emittable'])
        self.assertFalse(record['nativeTested'])
        self.assertIsNone(record['availability']['minimumApi'])
        self.assertEqual('nonnull', record['parameters'][0]['nullability'])
        self.assertEqual(0, self.api.stats()['declarations_unparsed'])
        self.assertEqual(0, self.api.stats()['members_native_tested'])

    def test_concrete_generics_preserve_native_types(self):
        api = AndroidAPI("""package android.test {
  public class Lists {
    method public java.util.List<java.lang.String> names();
    method public void take(java.util.List<? extends java.util.Map<java.lang.String,?>>);
    method public void callback(android.accounts.AccountManagerCallback<android.os.Bundle>);
  }
}
""")
        result = api.emit('android.test.Lists#names()', receiver=JavaValue.reference('item', 'android.test.Lists'))
        self.assertEqual('java.util.List<java.lang.String>', result.java_type)
        member = api.search('#take(')[0]
        value = JavaValue.reference('maps', member.parameters[0].java_type)
        self.assertIn('java.util.List<? extends java.util.Map<java.lang.String,?>>', api.emit(member.id, [value], JavaValue.reference('item', 'android.test.Lists')).source)
        self.assertTrue(api.search('#callback(')[0].emittable)
        for invalid in ['java.util.List<T>', 'java.util.List<int>', 'java.util.List<>', 'java.util.List<java.lang.String>;evil()', 'java.util.List<? extends T>']:
            with self.assertRaises(ValueError, msg=invalid): JavaValue.reference('value', invalid)

    def test_generic_wildcards_and_array_assignability_are_sound(self):
        self.assertTrue(self.api.is_assignable('java.util.List<android.test.Child>', 'java.util.List<? extends android.test.Parent>'))
        self.assertTrue(self.api.is_assignable('java.util.List<android.test.Parent>', 'java.util.List<? super android.test.Child>'))
        self.assertFalse(self.api.is_assignable('java.util.List<android.test.Child>', 'java.util.List<android.test.Parent>'))
        self.assertFalse(self.api.is_assignable('java.util.List<? extends android.test.Parent>', 'java.util.List<android.test.Child>'))
        self.assertFalse(self.api.is_assignable('java.util.List<? super android.test.Child>', 'java.util.List<? extends android.test.Parent>'))
        self.assertTrue(self.api.is_assignable('java.lang.String[]', 'java.lang.CharSequence[]'))
        self.assertFalse(self.api.is_assignable('int[]', 'long[]'))
        self.assertFalse(self.api.is_assignable('int[]', 'java.lang.Object[]'))
        self.assertFalse(self.api.is_assignable('java.util.List<java.lang.String>[]', 'java.util.List'))
        self.assertTrue(self.api.is_assignable('java.util.List<java.lang.String>[]', 'java.lang.Object'))
        for invalid in ['java.util.List<? extends int>', 'java.util.List<? super boolean>', 'android.int.Widget', 'java.util.List<? extends void>']:
            with self.assertRaises(ValueError, msg=invalid): JavaValue.reference('item', invalid)

    def test_flagged_types_nested_in_generics_are_rejected(self):
        api = AndroidAPI("""package android.test {
  @FlaggedApi("future") public class Future {
    ctor public Future();
  }
  public class Existing {
    method public java.util.List<android.test.Future> getFuture();
  }
}
""")
        self.assertFalse(api.get('android.test.Existing#getFuture()').emittable)
        with self.assertRaisesRegex(ValueError, 'flagged'):
            api.emit('android.test.Existing#getFuture()', receiver=JavaValue.reference('item', 'android.test.Existing'))

    def test_varargs_are_explicit_arrays(self):
        member = self.api.get('android.test.Child#values(java.lang.String[])')
        self.assertEqual('java.lang.String[]', member.parameters[0].java_type)
        self.assertTrue(self.api.get('android.test.Child#record(java.lang.String[])').emittable)


if __name__ == '__main__': unittest.main()
