"""Native field writes: structured inputs, immutable contracts, real Java binding."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from dcflight.native_api import NativeAPI, index_android
from dcflight.platforms.android_api import AndroidAPI, JavaValue

SDK = '''package demo {
 public class Fields {
  ctor public Fields();
  field public int count;
  field public static String label;
  field @NonNull public String required;
  field public final int fixed = 3;
  field public static final String TOKEN = "final";
  method public void update();
 }
 public class Child extends demo.Fields {
  ctor public Child();
 }
 public interface Constants {
  field public int VALUE = 3;
 }
 public enum Choice {
  enum_constant public static final demo.Choice FIRST;
 }
}
'''

class AndroidFieldAssignmentTests(unittest.TestCase):
    def test_readonly_types_and_receiver_constraints(self):
        api = AndroidAPI(SDK)
        obj = JavaValue.reference('obj', 'demo.Child')
        self.assertEqual('((demo.Fields) obj).count = (int) (7)', api.emit_set('demo.Fields#count', JavaValue.literal(7), obj).source)
        self.assertEqual('demo.Fields.label = (java.lang.String) ("ready")', api.emit_set('demo.Fields#label', JavaValue.literal('ready')).source)
        for identity in ['demo.Fields#fixed', 'demo.Fields#TOKEN', 'demo.Fields#update()', 'demo.Constants#VALUE', 'demo.Choice#FIRST']:
            with self.subTest(identity=identity), self.assertRaisesRegex(ValueError, 'writable'):
                api.emit_set(identity, JavaValue.literal(2), obj)
        for identity, value, receiver in [
            ('demo.Fields#count', JavaValue.literal('wrong'), obj),
            ('demo.Fields#count', JavaValue.literal(1), None),
            ('demo.Fields#count', JavaValue.literal(1), JavaValue.reference('x','java.lang.String')),
            ('demo.Fields#label', JavaValue.literal('x'), obj),
            ('demo.Fields#required', JavaValue.null('java.lang.String'), obj),
        ]:
            with self.subTest(identity=identity, value=value), self.assertRaises(ValueError):
                api.emit_set(identity, value, receiver)
        records = {r['id']:r for r in api.records()}
        self.assertTrue(records['demo.Fields#count']['writable'])
        self.assertFalse(records['demo.Fields#fixed']['writable'])
        # A constant's initializer must not be mistaken for a modifier.
        quoted = AndroidAPI(SDK.replace('static String label;', 'static String label = "final";'))
        self.assertTrue(quoted.is_writable(quoted.get('demo.Fields#label')))

    def test_catalog_roundtrip_and_structured_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'api.txt').write_text(SDK)
            index_android(root/'api.db', root/'api.txt')
            api=NativeAPI(root/'api.db')
            request={'platform':'android','id':'demo.Fields#count','receiver':{'ref':'obj','type':'demo.Fields'},'set':{'literal':4}}
            result=api.emit(request)
            self.assertEqual('((demo.Fields) obj).count = (int) (4)',result['source'])
            self.assertEqual('int',result['resultType'])
            self.assertIsNone(result['compilerRuntimeDependency'])
            for change in [{'arguments':[{'literal':1}]}, {'set':{'literal':'wrong'}}, {'set':{'source':'run()'}}, {'receiver':{'ref':'x);run()','type':'demo.Fields'}}]:
                with self.subTest(change=change),self.assertRaises(ValueError):api.emit({**request,**change})

    def test_generated_assignments_compile_and_execute(self):
        jdk=Path(os.environ.get('JAVA_HOME','/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/toolchains/jdk-17.0.20.1+1/Contents/Home'))/'bin'
        if not (jdk/'javac').is_file(): self.skipTest('JDK required')
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'demo').mkdir()
            (root/'demo/Fields.java').write_text('package demo; public class Fields { public int count; public static String label; public String required; public final int fixed=3; }')
            (root/'demo/Child.java').write_text('package demo; public class Child extends Fields {}')
            api=AndroidAPI(SDK)
            write=api.emit_set('demo.Fields#count', JavaValue.literal(42), JavaValue.reference('obj','demo.Child')).source
            label=api.emit_set('demo.Fields#label', JavaValue.literal('native')).source
            null=api.emit_set('demo.Fields#label', JavaValue.null('java.lang.String')).source
            (root/'Check.java').write_text('class Check { public static void main(String[] args) { demo.Child obj=new demo.Child(); '+write+'; '+label+'; if(obj.count!=42 || !demo.Fields.label.equals("native")) throw new AssertionError(); '+null+'; if(demo.Fields.label!=null) throw new AssertionError(); System.out.println("native-field-writes-passed"); } }')
            subprocess.run([str(jdk/'javac'),'-d',str(root),str(root/'demo/Fields.java'),str(root/'demo/Child.java'),str(root/'Check.java')],check=True,capture_output=True)
            result=subprocess.run([str(jdk/'java'),'-cp',str(root),'Check'],check=True,capture_output=True,text=True)
            self.assertEqual('native-field-writes-passed',result.stdout.strip())
