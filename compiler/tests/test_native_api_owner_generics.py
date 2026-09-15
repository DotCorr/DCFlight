import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.native_api import NativeAPI, index_android
from dcflight.native_sequence import emit_sequence

SDK = '''package java.util {
 public interface List<E> {
  method public abstract boolean add(E);
  method public abstract E get(int);
 }
 public class ArrayList<E> implements java.util.List<E> {
 }
}
package sample {
 public class Hidden<T> {
  method private T read();
 }
}'''


class OwnerGenericIntegrationTests(unittest.TestCase):
    def setup_api(self, root):
        source=root/'sdk.txt';source.write_text(SDK)
        database=root/'sdk.sqlite';index_android(database, source)
        return NativeAPI(database)

    def test_catalog_receiver_specializes_parameters_and_results(self):
        with tempfile.TemporaryDirectory() as folder:
            api=self.setup_api(Path(folder))
            receiver={'ref':'items','type':'java.util.ArrayList<java.lang.String>'}
            result=api.emit({'platform':'android','id':'java.util.List#get(int)',
                             'receiver':receiver,'arguments':[{'literal':0}]})
            self.assertEqual('java.lang.String',result['resultType'])
            self.assertIsNone(result['compilerRuntimeDependency'])
            api.emit({'platform':'android','id':'java.util.List#add(E)',
                      'receiver':receiver,'arguments':[{'literal':'hello'}]})
            with self.assertRaises(ValueError):
                api.emit({'platform':'android','id':'java.util.List#add(E)',
                          'receiver':receiver,'arguments':[{'literal':17}]})
            with self.assertRaises(ValueError):
                api.emit({'platform':'android','id':'java.util.List#get(int)',
                          'receiver':{'ref':'items','type':'java.util.List'},'arguments':[{'literal':0}]})

    def test_receiver_does_not_bypass_catalog_restrictions(self):
        with tempfile.TemporaryDirectory() as folder:
            api=self.setup_api(Path(folder))
            with self.assertRaisesRegex(ValueError,'non-public'):
                api.emit({'platform':'android','id':'sample.Hidden#read()',
                          'receiver':{'ref':'hidden','type':'sample.Hidden<java.lang.String>'}})
            with self.assertRaisesRegex(ValueError,'array'):
                api.emit({'platform':'android','id':'java.util.List#get(int)',
                          'receiver':{'ref':'items','type':'java.util.List<java.lang.String>'},
                          'arguments':[{'literal':0}], 'typeArguments':None})

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'),'JDK required')
    def test_sequence_infers_native_element_type_and_executes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);api=self.setup_api(root)
            sequence=emit_sequence(api,{'platform':'android',
                'inputs':[{'name':'items','type':'java.util.ArrayList<java.lang.String>'}],
                'steps':[{'id':'java.util.List#add(E)','receiver':{'ref':'items'},'arguments':[{'literal':'hello'}]},
                         {'id':'java.util.List#get(int)','receiver':{'ref':'items'},'arguments':[{'literal':0}],'bind':'value'}]})
            self.assertIn('java.lang.String',sequence['source'])
            source=root/'Main.java'
            source.write_text('public class Main { public static void main(String[] args) { java.util.ArrayList<String> items=new java.util.ArrayList<>(); '+sequence['source']+' if(items.size()!=1 || !items.get(0).equals("hello"))throw new AssertionError(); } }')
            compile=subprocess.run(['javac','-Xlint:unchecked','-Werror',str(source)],capture_output=True,text=True)
            self.assertEqual(0,compile.returncode,compile.stderr)
            run=subprocess.run(['java','-cp',str(root),'Main'],capture_output=True,text=True)
            self.assertEqual(0,run.returncode,run.stderr)
