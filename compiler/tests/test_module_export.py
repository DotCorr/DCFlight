import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from dataclasses import asdict
from dcflight.modules.export import export_android,_entries
from dcflight.modules.manifest import read_manifest,digest
from dcflight.native_api import NativeAPI

JDK=Path(os.environ.get('JAVA_HOME','/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/toolchains/jdk-17.0.20.1+1/Contents/Home'))/'bin'

@unittest.skipUnless((JDK/'javac').is_file(),'JDK required for bytecode integration')
class ModuleExportTest(unittest.TestCase):
    def test_real_bytecode_emission(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);(p/'demo').mkdir()
            (p/'demo/Example.java').write_text('package demo; public class Example<T> { public static int add(int a,int b){return a+b;} public static String add(String a,String b){return a+b;} public java.util.List<String> names(){return null;} public T identity(T value){return value;} }')
            subprocess.run([str(JDK/'javac'),str(p/'demo/Example.java')],check=True)
            (p/'demo/ComparableValue.java').write_text('package demo; public class ComparableValue implements Comparable<ComparableValue> { public int compareTo(ComparableValue other){return 0;} }')
            subprocess.run([str(JDK/'javac'),str(p/'demo/ComparableValue.java')],check=True,capture_output=True)
            with zipfile.ZipFile(p/'fixture.jar','w') as z:
                z.write(p/'demo/Example.class','demo/Example.class')
                z.write(p/'demo/ComparableValue.class','demo/ComparableValue.class')
            manifest={'schemaVersion':1,'id':'fixture','version':'1.0.0','platform':'android','package':'demo:fixture','revision':'1.0.0'}
            (p/'module.json').write_text(json.dumps(manifest));m=read_manifest(p/'module.json')
            lock={'schemaVersion':1,'module':asdict(m),'manifestSha256':digest(p/'module.json'),'artifacts':[{'path':'fixture.jar','sha256':digest(p/'fixture.jar')}]}
            (p/'module.lock.json').write_text(json.dumps(lock))
            report=export_android(p/'module.lock.json',p/'catalog.db',javap=JDK/'javap')
            self.assertGreater(report['emittable'],2);self.assertFalse(report['compiled'])
            self.assertEqual(1,report['provenance']['bridgeMethodsExcluded'])
            from dcflight.catalog import Catalog
            with Catalog(p/'catalog.db') as c:
                self.assertTrue(c.get('android','demo.ComparableValue#compareTo(demo.ComparableValue)',report['scope'])['api']['emittable'])
                with self.assertRaises(ValueError):c.get('android','demo.ComparableValue#compareTo(java.lang.Object)',report['scope'])
            result=NativeAPI(p/'catalog.db').emit({'platform':'android','scope':report['scope'],'id':'demo.Example#add(int,int)','arguments':[{'literal':1},{'literal':2}]})
            self.assertEqual(result['runtimeDependency']['platform'],'android')
            self.assertIsNone(result['compilerRuntimeDependency'])
            self.assertEqual(result['source'],'demo.Example.add((int) (1), (int) (2))')
            (p/'Check.java').write_text('class Check { int x = '+result['source']+'; }')
            subprocess.run([str(JDK/'javac'),'-classpath',str(p/'fixture.jar'),str(p/'Check.java')],check=True)
            from dcflight.catalog import Catalog
            with Catalog(p/'catalog.db') as c:
                member=c.get('android','demo.Example#identity(T)',report['scope'])['api']
                self.assertFalse(member['emittable']);self.assertIn('T',str(member['unsupportedReasons']))
            with zipfile.ZipFile(p/'fixture.aar','w') as z:
                z.write(p/'fixture.jar','classes.jar')
            aar_lock={**lock,'artifacts':[{'path':'fixture.aar','sha256':digest(p/'fixture.aar')}]}
            (p/'aar.lock.json').write_text(json.dumps(aar_lock))
            aar=export_android(p/'aar.lock.json',p/'aar.db',javap=JDK/'javap')
            self.assertEqual(aar['indexed'], report['indexed'])
            with zipfile.ZipFile(p/'fixture.jar','a') as z:z.writestr('changed','x')
            with self.assertRaisesRegex(ValueError,'integrity'):export_android(p/'module.lock.json',p/'catalog.db',javap=JDK/'javap')

    def test_boot_classpath_cannot_replace_locked_class(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); source=root/'java/util/UUID.java';source.parent.mkdir(parents=True)
            source.write_text('package java.util; public final class UUID { public static int onlyInLockedArtifact(){return 7;} }')
            subprocess.run([str(JDK/'javac'),'--release','8',str(source)],check=True,capture_output=True)
            archive=root/'fixture.jar'
            with zipfile.ZipFile(archive,'w') as z:z.write(source.with_suffix('.class'),'java/util/UUID.class')
            manifest={'schemaVersion':1,'id':'fixture','version':'1.0.0','platform':'android','package':'demo:fixture','revision':'1.0.0'}
            (root/'module.json').write_text(json.dumps(manifest));m=read_manifest(root/'module.json')
            lock={'schemaVersion':1,'module':asdict(m),'manifestSha256':digest(root/'module.json'),'artifacts':[{'path':'fixture.jar','sha256':digest(archive)}]}
            (root/'module.lock.json').write_text(json.dumps(lock))
            report=export_android(root/'module.lock.json',root/'api.db',javap=JDK/'javap')
            self.assertEqual('exact-verified-class-files',report['provenance']['classResolution'])
            from dcflight.catalog import Catalog
            with Catalog(root/'api.db') as c:
                self.assertTrue(c.get('android','java.util.UUID#onlyInLockedArtifact()',report['scope'])['api']['emittable'])
                self.assertEqual(0,c.search('randomUUID',platform='android')['total'])
            from dcflight.modules.export import index_android_core
            core=index_android_core(archive,root/'core.db',javap=JDK/'javap',sdk=35)
            self.assertEqual('core-bytecode',core['scope'])
            self.assertEqual('platform-sdk',core['provenance']['dependencyKind'])
            self.assertNotIn('nativeModule',core['provenance'])
            self.assertFalse(core['compiled']);self.assertFalse(core['executed'])
            emitted=NativeAPI(root/'core.db').emit({'platform':'android','scope':'core-bytecode','id':'java.util.UUID#onlyInLockedArtifact()'})
            self.assertIsNone(emitted['runtimeDependency'])
            self.assertEqual('java.util.UUID.onlyInLockedArtifact()',emitted['source'])
            for sdk in (True,0,-1):
                with self.assertRaises(ValueError):index_android_core(archive,root/'bad-sdk.db',javap=JDK/'javap',sdk=sdk)
            # The class-file internal identity must also match its archive entry.
            with zipfile.ZipFile(archive,'w') as z:z.write(source.with_suffix('.class'),'java/util/NotUUID.class')
            lock['artifacts'][0]['sha256']=digest(archive);(root/'module.lock.json').write_text(json.dumps(lock))
            with self.assertRaisesRegex(ValueError,'identity differs'):
                export_android(root/'module.lock.json',root/'bad.db',javap=JDK/'javap')

    def test_zip_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad.jar'
            with zipfile.ZipFile(p,'w') as z:z.writestr('../bad.class',b'x')
            with zipfile.ZipFile(p) as z:
                with self.assertRaisesRegex(ValueError,'Unsafe'):_entries(z)
