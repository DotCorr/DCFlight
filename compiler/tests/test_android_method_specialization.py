import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import AndroidAPI, JavaValue
from dcflight.native_api import NativeAPI, index_android
from dcflight.native_sequence import emit_sequence

CATALOG = '''package java.lang {
 public class Number {
 }
 public class Integer extends java.lang.Number {
 }
}
package java.util {
 public interface List<E> {
  method public abstract <T> T[] toArray(T[]);
 }
 public class Collections {
  method public static <T> java.util.List<T> singletonList(T);
  method public static <T> java.util.List<T> emptyList();
 }
}
package sample {
 public class Calls {
  method public static <T extends java.lang.Number> T number(T);
  method public <T> T instance(T);
  method private static <T> T hidden(T);
 }
}'''


class MethodSpecializationTests(unittest.TestCase):
    def test_generic_varargs_competitor_rejects_ambiguous_array(self):
        api=AndroidAPI('''package sample {
 public class Calls {
  method public static <T> void apply(java.util.List<T>, java.lang.String...);
  method public static <V> void apply(java.util.List<V>, V...);
 }
}''')
        args=[JavaValue.reference('values','java.util.List<java.lang.Object>'),JavaValue.array([], 'java.lang.String[]')]
        with self.assertRaisesRegex(ValueError,'overload may be ambiguous'):
            api.emit('sample.Calls#apply(java.util.List<T>,java.lang.String[])',args,type_arguments=['java.lang.Object'])
        args[0]=JavaValue.reference('values','java.util.List<java.lang.Integer>')
        self.assertIn('.<java.lang.Integer>apply',api.emit('sample.Calls#apply(java.util.List<T>,java.lang.String[])',args,type_arguments=['java.lang.Integer']).source)

    def test_explicit_parameters_preserve_result_and_bounds(self):
        api=AndroidAPI(CATALOG)
        result=api.emit('java.util.Collections#singletonList(T)',[JavaValue.literal('hello')],type_arguments=['java.lang.String'])
        self.assertEqual('java.util.List<java.lang.String>',result.java_type)
        self.assertIn('.<java.lang.String>singletonList((java.lang.String)',result.source)
        self.assertEqual('java.lang.Integer',api.specialize('sample.Calls#number(T)',['java.lang.Integer']).java_type)
        for arguments in ([],['int'],['java.lang.String'],['java.lang.Integer','java.lang.Integer']):
            with self.subTest(arguments=arguments), self.assertRaises(ValueError):
                api.specialize('sample.Calls#number(T)',arguments)
        with self.assertRaisesRegex(ValueError,'Receiver'):
            api.emit('sample.Calls#instance(T)',[JavaValue.literal('x')],type_arguments=['java.lang.String'])
        with self.assertRaisesRegex(ValueError,'non-public'):
            api.emit('sample.Calls#hidden(T)',[JavaValue.literal('x')],type_arguments=['java.lang.String'])
        with self.assertRaises(ValueError):api.emit('java.util.Collections#emptyList()')

    def test_catalog_request_and_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'api.txt';source.write_text(CATALOG)
            database=root/'api.sqlite';index_android(database,source)
            api=NativeAPI(database)
            request={'platform':'android','id':'java.util.Collections#emptyList()','typeArguments':['java.lang.String']}
            result=api.emit(request)
            self.assertEqual('java.util.List<java.lang.String>',result['resultType'])
            self.assertEqual('java.util.Collections.<java.lang.String>emptyList()',result['source'])
            self.assertIsNone(result['compilerRuntimeDependency'])
            sequence=emit_sequence(api,{'platform':'android','steps':[{'id':request['id'],'typeArguments':['java.lang.String'],'bind':'items'}]})
            self.assertIn('java.util.List<java.lang.String>',sequence['source'])
            with self.assertRaises(ValueError):api.emit({**request,'typeArguments':None})
            with self.assertRaises(ValueError):api.emit({**request,'id':'sample.Calls#hidden(T)','arguments':[{'literal':'x'}]})

    def test_generic_instance_array_call_and_receiver_checks(self):
        api=AndroidAPI(CATALOG)
        receiver=JavaValue.reference('items','java.util.List<java.lang.String>')
        array=JavaValue.array([], 'java.lang.String[]')
        result=api.emit('java.util.List#toArray(T[])',[array],receiver,type_arguments=['java.lang.String'])
        self.assertEqual('java.lang.String[]',result.java_type)
        self.assertIn('((java.util.List<?>) items).<java.lang.String>toArray',result.source)
        with self.assertRaisesRegex(ValueError,'Receiver'):
            api.emit('java.util.List#toArray(T[])',[array],JavaValue.reference('bad','java.lang.String'),type_arguments=['java.lang.String'])
        with self.assertRaisesRegex(ValueError,'Expected java.lang.Integer'):
            api.emit('java.util.List#toArray(T[])',[array],receiver,type_arguments=['java.lang.Integer'])

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'JDK required')
    def test_native_generic_calls_compile_without_unchecked_conversion(self):
        api=AndroidAPI(CATALOG)
        one=api.emit('java.util.Collections#singletonList(T)',[JavaValue.literal('hello')],type_arguments=['java.lang.String']).source
        empty=api.emit('java.util.Collections#emptyList()',type_arguments=['java.lang.Integer']).source
        array=api.emit('java.util.List#toArray(T[])',[JavaValue.array([], 'java.lang.String[]')],JavaValue.reference('one','java.util.List<java.lang.String>'),type_arguments=['java.lang.String']).source
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'Main.java'
            source.write_text('public class Main { public static void main(String[] args) { java.util.List<String> one='+one+'; java.util.List<Integer> empty='+empty+'; String[] array='+array+'; if(!one.get(0).equals("hello") || !empty.isEmpty() || array.length!=1 || !array[0].equals("hello"))throw new AssertionError(); } }')
            build=subprocess.run(['javac','-Xlint:unchecked','-Werror',str(source)],capture_output=True,text=True)
            self.assertEqual(0,build.returncode,build.stderr)
            run=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
