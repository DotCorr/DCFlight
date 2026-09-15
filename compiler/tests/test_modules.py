import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from dataclasses import asdict
from dcflight.modules.manifest import read_manifest
from dcflight.modules.resolve import verify


class ModuleIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root/'module.json'
        self.data = dict(schemaVersion=1,id='maps',version='1.2.3',platform='android',
                         package='org.example:maps',revision='1.2.3',permissions=['android.permission.INTERNET'])
        self.write_manifest()

    def write_manifest(self):
        self.manifest.write_text(json.dumps(self.data))

    def lock(self):
        artifact = self.root/'maps.aar'
        artifact.write_bytes(b'fixture native artifact')
        lock = dict(schemaVersion=1,module=asdict(read_manifest(self.manifest)),
                    manifestSha256=hashlib.sha256(self.manifest.read_bytes()).hexdigest(),
                    artifacts=[dict(path='maps.aar',sha256=hashlib.sha256(artifact.read_bytes()).hexdigest())],
                    verification=dict(resolved=True,compiled=False,executed=False))
        path = self.root/'module.lock.json'
        path.write_text(json.dumps(lock))
        return path

    def test_artifact_and_manifest_tampering_rejected(self):
        path = self.lock()
        self.assertFalse(verify(path)['verification']['compiled'])
        (self.root/'maps.aar').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'integrity'):verify(path)
        self.lock()
        self.data['revision']='1.2.4';self.write_manifest()
        with self.assertRaisesRegex(ValueError,'declaration changed'):verify(path)

    def test_lock_cannot_reference_outside_root(self):
        path = self.lock();data=json.loads(path.read_text())
        data['artifacts'][0]['path']='../outside.aar';path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,'integrity'):verify(path)

    def test_reject_floating_or_executable_declarations(self):
        for key,value in [('revision','1.+'),('revision','latest.release'),('revision','1.2-SNAPSHOT'),
                          ('package',"org.example:maps'; exec('anything')"),
                          ('permissions',['androidXpermissionXINTERNET']),('schemaVersion',True)]:
            with self.subTest(key=key,value=value):
                original=self.data[key];self.data[key]=value;self.write_manifest()
                with self.assertRaises(ValueError):read_manifest(self.manifest)
                self.data[key]=original

    def test_spm_requires_https_and_immutable_commit(self):
        self.data.update(platform='ios',package='https://example.com/maps.git',revision='a'*40,products=['Maps'],permissions=[])
        self.write_manifest();self.assertEqual(read_manifest(self.manifest).products,('Maps',))
        for package,revision in [('https://user:secret@example.com/maps.git','a'*40),('https://example.com/maps.git','main')]:
            self.data.update(package=package,revision=revision);self.write_manifest()
            with self.assertRaises(ValueError):read_manifest(self.manifest)

    def test_generation_copies_locked_bytes_and_rejects_tampering(self):
        from dcflight.modules.generate import generate_modules
        from dcflight.ir import Application,Node,ModuleReference
        from dcflight.backends import Artifact
        path=self.lock();lock=json.loads(path.read_text())
        # JAR fixtures are opaque to copying; the exporter independently verifies bytecode.
        (self.root/'maps.aar').rename(self.root/'maps.jar')
        lock['artifacts'][0].update(path='maps.jar',coordinate='org.example:maps:1.2.3')
        path.write_text(json.dumps(lock))
        model=Application('com.example.test','Test',(),(),Node('root','text',(),()),modules=(ModuleReference('maps','android','module.lock.json'),))
        files={'android/app/build.gradle':Artifact('plugins {}\n','user'),
               'android/app/src/main/AndroidManifest.xml':Artifact('<manifest>\n  <application/>\n</manifest>','user')}
        generate_modules(model,self.root/'app.json',('android',),files)
        binaries=[x for name,x in files.items() if name.endswith('.jar')]
        self.assertEqual(binaries[0].content,b'fixture native artifact')
        self.assertIn("implementation files('libs/",files['android/app/native-modules.gradle'].content)
        self.assertIn('android.permission.INTERNET',files['android/app/src/main/AndroidManifest.xml'].content)
        (self.root/'maps.jar').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'integrity'):generate_modules(model,self.root/'app.json',('android',),{})

    def test_aligned_graph_keeps_locked_bytes_and_excludes_maven_duplicates(self):
        from dcflight.modules.generate import generate_modules
        from dcflight.ir import Application,Node,ModuleReference
        from dcflight.backends import Artifact
        path=self.lock();lock=json.loads(path.read_text())
        (self.root/'maps.aar').rename(self.root/'maps.jar')
        lock['artifacts'][0].update(path='maps.jar',coordinate='org.example:maps:1.2.3')
        lock['resolutionContext']={'kind':'androidRuntimeClasspath','configuration':'debugRuntimeClasspath','localArtifactsReplaceMaven':True}
        path.write_text(json.dumps(lock))
        model=Application('com.example.test','Test',(),(),Node('root','text',(),()),modules=(ModuleReference('maps','android','module.lock.json'),))
        files={'android/app/build.gradle':Artifact('plugins {}\n','user'),
               'android/app/src/main/AndroidManifest.xml':Artifact('<manifest><application/></manifest>','user')}
        generate_modules(model,self.root/'app.json',('android',),files)
        self.assertIn("exclude group: 'org.example', module: 'maps'",files['android/app/native-modules.gradle'].content)
        self.assertEqual([x.content for name,x in files.items() if name.endswith('.jar')],[b'fixture native artifact'])
        self.assertIn('android.permission.INTERNET',files['android/app/src/main/AndroidManifest.xml'].content)
        lock['artifacts'][0]['coordinate']="org.example:maps:1.2.3';evil"
        path.write_text(json.dumps(lock))
        with self.assertRaisesRegex(ValueError,'coordinate'):generate_modules(model,self.root/'app.json',('android',),{})
