import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from dcflight.android_availability import import_availability, verify_report
from dcflight.android_sdk_guard import gradle_guard
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_sequence import emit_sequence
from dcflight.platforms.android_api import AndroidAPI

SDK_TEXT='''package sample {
 public class Candidate {
  method @FlaggedApi("test.enabled") public static int enabled(int);
  method @FlaggedApi("test.missing") public static int missing();
  method @FlaggedApi("test.private") private static int hidden();
 }
}'''
JDK=Path(os.environ['JAVA_HOME']) if os.environ.get('JAVA_HOME') else Path(shutil.which('javac') or '/missing/jdk/bin/javac').resolve().parent.parent
SDK=Path(os.environ.get('DCFLIGHT_ANDROID_SDK_JAR') or str(Path(os.environ.get('DCFLIGHT_ANDROID_SDK') or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '/missing/android-sdk')/'platforms/android-35/android.jar'))
GRADLE_HOME=Path(os.environ.get('GRADLE_HOME') or Path(shutil.which('gradle') or '/missing/gradle/bin/gradle').resolve().parent.parent)


@unittest.skipUnless((JDK/'bin/javac').is_file() and SDK.is_file(),'JDK and Android 35 SDK required')
class AndroidAvailabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary=tempfile.TemporaryDirectory();cls.root=Path(cls.temporary.name)
        cls.source=cls.root/'api.txt';cls.source.write_text(SDK_TEXT)
        fixture=cls.root/'stub/sample/Candidate.java';fixture.parent.mkdir(parents=True)
        fixture.write_text('package sample; public class Candidate { public static int enabled(int value) { return value+1; } }')
        subprocess.run([str(JDK/'bin/javac'),'--release','8',str(fixture)],check=True,capture_output=True)
        cls.sdk=cls.root/'android.jar';shutil.copyfile(SDK,cls.sdk)
        with zipfile.ZipFile(cls.sdk,'a') as jar:jar.write(fixture.with_suffix('.class'),'sample/Candidate.class')
        cls.environment=patch.dict(os.environ,{'DCFLIGHT_ANDROID_SDK_JAR':str(cls.sdk),'JAVA_HOME':str(JDK)})
        cls.environment.start()
        tool=os.environ.get('DCFLIGHT_AVAILABILITY_VERIFIER')
        if tool:
            spec=importlib.util.spec_from_file_location('availability_verifier',tool)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        else:
            from tools import verify_android_availability as module
        cls.report=module.verify(cls.source,cls.sdk,JDK/'bin/javac')
        cls.report_path=cls.root/'report.json';cls.report_path.write_text(json.dumps(cls.report))

    @classmethod
    def tearDownClass(cls):cls.environment.stop();cls.temporary.cleanup()

    def catalog(self,name):
        path=self.root/(name+'.sqlite');index_android(path,self.source)
        return path

    def test_only_generator_verified_members_are_enabled_for_exact_sdk(self):
        self.assertEqual(self.report['candidateCount'],2)
        self.assertEqual(self.report['compiledCount'],1)
        database=self.catalog('valid')
        import_availability(database,self.report_path,self.sdk)
        api=NativeAPI(database)
        request={'platform':'android','id':'sample.Candidate#enabled(int)','arguments':[{'literal':7}]}
        for identity in (None,'0'*64):
            with self.subTest(identity=identity),self.assertRaisesRegex(ValueError,'exact verified Android SDK'):
                api.emit({**request,**({'androidSdkSha256':identity} if identity else {})})
        result=api.emit({**request,'androidSdkSha256':self.report['sdkSha256']})
        self.assertIn('sample.Candidate.enabled',result['source'])
        self.assertIsNone(result['conditionalAvailability']['runtimeSupported'])
        self.assertIsNone(result['conditionalAvailability']['minimumApi'])
        api.android_sdk=SDK
        with self.assertRaisesRegex(ValueError,'SDK hash mismatch'):
            api.emit({**request,'androidSdkSha256':self.report['sdkSha256']})
        with Catalog(database) as catalog:
            selected=catalog.get('android',request['id'])
            self.assertTrue(selected['api']['availability']['conditional'])
            self.assertTrue(selected['api']['availability']['annotations'])
            self.assertEqual(selected['evidence'][0]['level'],'compiled')
        for name in ('missing','hidden'):
            with self.subTest(name=name),self.assertRaises(ValueError):
                api.emit({'platform':'android','id':'sample.Candidate#'+name+'()',
                          'androidSdkSha256':self.report['sdkSha256']})

    def test_malformed_stale_and_forged_member_proofs_are_rejected(self):
        api=AndroidAPI(SDK_TEXT)
        mutations=[]
        for key,value in [('sourceSha256','0'*64),('apiLevel',34),('compilerSources',{}),
                          ('compiledCount',7),('dependencyScanPassed',False),('runtimeSupported',True),
                          ('command',[]),('generator','manual')]:
            report=copy.deepcopy(self.report);report[key]=value;mutations.append(report)
        report=copy.deepcopy(self.report);report['members'][0]['probeSha256']='0'*64;mutations.append(report)
        report=copy.deepcopy(self.report);report['members'][1]['id']=report['members'][0]['id'];mutations.append(report)
        report=copy.deepcopy(self.report);report['members'][1]['id']='sample.Candidate#hidden()';mutations.append(report)
        for report in mutations:
            with self.subTest(report=report),self.assertRaises(ValueError):verify_report(report,api)
        with self.assertRaisesRegex(ValueError,'SDK hash mismatch'):
            import_availability(self.catalog('wrongSdk'),self.report_path,SDK)
        forged=copy.deepcopy(self.report)
        for row in forged['members']:row['compiled']=True
        forged['compiledCount']=len(forged['members'])
        path=self.root/'forged.json';path.write_text(json.dumps(forged))
        database=self.catalog('forged')
        with self.assertRaisesRegex(ValueError,'failed native revalidation'):
            import_availability(database,path,self.sdk)
        with Catalog(database) as catalog:
            self.assertFalse(catalog.get('android','sample.Candidate#missing()')['api']['emittable'])
        # Even bypassing the guarded importer cannot make NativeAPI trust a
        # hand-built catalog certificate instead of actual native SDK proof.
        from dcflight.android_availability import _candidate_view,report_digest
        with Catalog(database) as catalog:source=catalog.source('android','framework')
        records=_candidate_view(api,[r['id'] for r in forged['members']]).records()
        with Catalog(database,write=True) as catalog:
            catalog.import_records('android','framework','35',records,{**source['provenance'],
                'flaggedAvailability':{'report':forged,'sha256':report_digest(forged)}})
        with self.assertRaisesRegex(ValueError,'failed native revalidation'):
            NativeAPI(database).emit({'platform':'android','id':'sample.Candidate#missing()',
                                     'androidSdkSha256':self.report['sdkSha256']})
        for rows in (None,{},[None],[{}],[{'id':'sample.Candidate#enabled(int)','compiled':'yes'}]):
            malformed=copy.deepcopy(self.report);malformed['members']=rows
            with Catalog(database,write=True) as catalog:
                catalog.import_records('android','framework','35',records,{**source['provenance'],
                    'flaggedAvailability':{'report':malformed,'sha256':report_digest(malformed)}})
            with self.subTest(rows=rows),self.assertRaises(ValueError):
                NativeAPI(database).emit({'platform':'android','id':'sample.Candidate#missing()',
                                         'androidSdkSha256':self.report['sdkSha256']})

    def test_source_replacement_and_evidence_import_are_atomic(self):
        database=self.catalog('atomic')
        with Catalog(database) as catalog:before=catalog.source('android','framework')
        with Catalog(database,write=True) as catalog:
            with self.assertRaisesRegex(ValueError,'unknown or unsupported'):
                catalog.import_records('android','framework','35',AndroidAPI(SDK_TEXT).records(),{'replacement':True},
                                       evidence_entries=[{'ids':['not-an-api'],'level':'compiled',
                                                          'evidence':{'command':'check','toolchain':{'name':'fixture'}}}])
        with Catalog(database) as catalog:self.assertEqual(catalog.source('android','framework'),before)

    def test_generated_linkage_boundary_reaches_exception_handler_without_catching_oom(self):
        database=self.catalog('linkage');import_availability(database,self.report_path,self.sdk)
        sequence={'platform':'android','androidSdkSha256':self.report['sdkSha256'],
                  'steps':[{'id':'sample.Candidate#enabled(int)','arguments':[{'literal':7}],'bind':'answer'}]}
        with self.assertRaisesRegex(ValueError,'throwing/failure'):emit_sequence(NativeAPI(database),sequence)
        emitted=emit_sequence(NativeAPI(database),{**sequence,'allowThrows':True})
        self.assertIn('catch (java.lang.LinkageError',emitted['source'])
        self.assertNotIn('catch (java.lang.Throwable',emitted['source'])
        root=self.root/'runtime';root.mkdir();(root/'sample').mkdir()
        # Compile generator output against the exact certified SDK; run against
        # a native class without the method to exercise the real linkage error.
        source=root/'Check.java'
        source.write_text('public class Check { static int invoke() throws Throwable { '+emitted['source']+' return dcfLocal0; } public static void main(String[] args) throws Throwable { try { invoke(); throw new AssertionError("missing failure"); } catch (IllegalStateException e) { if (!(e.getCause() instanceof NoSuchMethodError)) throw e; System.out.print("FAILURE_BRANCH"); } } }')
        build=subprocess.run([str(JDK/'bin/javac'),'-source','8','-target','8','-bootclasspath',str(self.sdk),'-Xlint:unchecked','-Werror',str(source)],capture_output=True,text=True)
        self.assertEqual(build.returncode,0,build.stderr)
        replacement=root/'sample/Candidate.java';replacement.write_text('package sample; public class Candidate {}')
        subprocess.run([str(JDK/'bin/javac'),'--release','8',str(replacement)],check=True,capture_output=True)
        executed=subprocess.run([str(JDK/'bin/java'),'-cp',str(root),'Check'],capture_output=True,text=True)
        self.assertEqual(executed.returncode,0,executed.stderr);self.assertEqual(executed.stdout,'FAILURE_BRANCH')
        replacement.write_text('package sample; public class Candidate { public static int enabled(int v) { throw new OutOfMemoryError("fixture"); } }')
        subprocess.run([str(JDK/'bin/javac'),'--release','8',str(replacement)],check=True,capture_output=True)
        oom=subprocess.run([str(JDK/'bin/java'),'-cp',str(root),'Check'],capture_output=True,text=True)
        self.assertNotEqual(oom.returncode,0);self.assertIn('OutOfMemoryError',oom.stderr)

    def test_generated_build_guard_pins_sdk_and_rejects_mixed_requirements(self):
        from dcflight.android_sdk_guard import active_guard_hook,DIRECTIVE
        requirement={'apiLevel':35,'sdkSha256':self.report['sdkSha256']}
        guard=gradle_guard([requirement])
        self.assertIn(self.report['sdkSha256'],guard)
        self.assertIn("it.name == 'preBuild'",guard)
        self.assertIn('android.bootClasspath',guard)
        with self.assertRaises(ValueError):gradle_guard([requirement,{**requirement,'sdkSha256':'0'*64}])
        self.assertTrue(active_guard_hook("plugins { id 'com.android.application' }\n"+DIRECTIVE+'\n'))
        for text in ('// '+DIRECTIVE,'/*\n'+DIRECTIVE+'\n*/',
                     'if (false) {\n'+DIRECTIVE+'\n}', 'if (false)\n'+DIRECTIVE,
                     'def text = """\n'+DIRECTIVE+'\n"""'):
            with self.subTest(text=text):self.assertFalse(active_guard_hook(text))

    def test_routed_native_operation_emits_sdk_guard_and_requires_failure_contract(self):
        from dcflight.platforms.ios_api import API
        from dcflight.compiler import compile_app
        from dcflight.native_operation import emit_operation
        database=self.catalog('app');import_availability(database,self.report_path,self.sdk)
        with Catalog(database,write=True) as catalog:
            catalog.import_records('ios','Foundation','26.2',[
                API('uuid','Foundation',('UUID','init()'),'constructor',(),'UUID',(),()).to_dict()],{'fixture':True})
        operation={'name':'readConditional','parameters':[{'name':'value','type':'int'}],
                   'result':'int','throws':True,'execution':'main','implementations':{
                       'ios':{'steps':[{'id':'uuid','bind':'unused'}],'return':{'ref':'value'}},
                       'android':{'androidSdkSha256':self.report['sdkSha256'],
                                  'steps':[{'id':'sample.Candidate#enabled(int)','arguments':[{'ref':'value'}],'bind':'answer'}],
                                  'return':{'ref':'answer'}}}}
        rejected=copy.deepcopy(operation);rejected['throws']=False
        with self.assertRaisesRegex(ValueError,'throwing/failure'):emit_operation(NativeAPI(database),rejected)
        document={'version':2,'id':'com.example.availability','name':'Conditional','state':{'answer':0},
                  'sdkCatalog':str(database),'nativeOperations':[operation],
                  'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
                  'routes':[{'id':'home','title':'Home','body':{'id':'text','type':'text','props':{'text':'Conditional'}}}],
                  'flowActions':[{'id':'invoke','cases':[{'code':0,'effects':[{'op':'nativeOperation','operation':'readConditional',
                        'arguments':[7],'target':'answer','success':'done','failure':'failed'}]}]},
                        {'id':'done','cases':[{'code':0,'effects':[]}]},
                        {'id':'failed','cases':[{'code':0,'effects':[{'op':'set','target':'answer','value':-1}]}]}]}
        root=self.root/'project';source=self.root/'app.json';source.write_text(json.dumps(document))
        compile_app(source,root,targets=('android',))
        build=root/'android/app/build.gradle'
        self.assertIn("apply from: 'verified-android-sdk.gradle'",build.read_text())
        self.assertIn(self.report['sdkSha256'],(root/'android/app/verified-android-sdk.gradle').read_text())
        self.assertIn('catch (java.lang.LinkageError',(root/'android/app/src/main/java/com/example/availability/NativeOperation_readConditional.java').read_text())
        original=build.read_text()
        without=copy.deepcopy(document);without['nativeOperations']=[];without['flowActions']=[]
        compile_app(source,root,targets=('android',),document=without)
        self.assertEqual(build.read_text(),original)
        self.assertIn('no SDK-qualified conditional calls',(root/'android/app/verified-android-sdk.gradle').read_text())
        compile_app(source,root,targets=('android',))
        for disabled in ('// ', 'if (false) '):
            build.write_text(original.replace("apply from: 'verified-android-sdk.gradle'",disabled+"apply from: 'verified-android-sdk.gradle'"))
            with self.assertRaisesRegex(ValueError,'user-owned android/app/build.gradle'):compile_app(source,root,targets=('android',))
        build.write_text(original)
        build.write_text(build.read_text().replace("apply from: 'verified-android-sdk.gradle'",''))
        with self.assertRaisesRegex(ValueError,'user-owned android/app/build.gradle'):compile_app(source,root,targets=('android',))

    @unittest.skipUnless((GRADLE_HOME/'lib').is_dir(),'Gradle Groovy distribution required')
    def test_sdk_guard_executes_with_real_hash_and_rejects_different_sdk(self):
        root=self.root/'guard';root.mkdir()
        guard=root/'guard.gradle';guard.write_text(gradle_guard([{'apiLevel':35,'sdkSha256':self.report['sdkSha256']}]))
        wrapper=root/'Check.groovy'
        wrapper.write_text('''class GradleException extends RuntimeException { GradleException(String m) { super(m) } }
class Task { void doLast(Closure c) { c() } }
class Tasks {
 Object register(String n,Closure c) { c.delegate=new Task();c.resolveStrategy=Closure.DELEGATE_FIRST;c();return this }
 Object matching(Closure c) { return this }
 void configureEach(Closure c) {}
}
def inputs = new Binding([android:[bootClasspath:[new File(args[0])]],tasks:new Tasks()])
new GroovyShell(this.class.classLoader,inputs).evaluate(new File(args[1]))
print('PASS')
''')
        command=[str(JDK/'bin/java'),'-cp',str(GRADLE_HOME/'lib/*'),
                 'groovy.ui.GroovyMain',str(wrapper)]
        matched=subprocess.run([*command,str(self.sdk),str(guard)],capture_output=True,text=True)
        self.assertEqual(matched.returncode,0,matched.stderr);self.assertEqual(matched.stdout,'PASS')
        mismatch=subprocess.run([*command,str(SDK),str(guard)],capture_output=True,text=True)
        self.assertNotEqual(mismatch.returncode,0)
        self.assertIn('Android SDK differs from verified conditional API snapshot',mismatch.stderr)
