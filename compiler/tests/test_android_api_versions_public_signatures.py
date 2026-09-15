import os,shutil,subprocess,tempfile,unittest,zipfile
from pathlib import Path
from dcflight.modules.export import index_android_sdk
from dcflight.catalog import Catalog

class PublicSignatureTests(unittest.TestCase):
 def test_implicit_object_and_intersection_have_exact_descriptor_bindings(self):
  home=os.environ.get('JAVA_HOME');javac=str(Path(home)/'bin/javac') if home else shutil.which('javac');javap=str(Path(home)/'bin/javap') if home else shutil.which('javap')
  if not javac or not javap:self.skipTest('Configure JAVA_HOME or javac/javap')
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);src=root/'fixture/Generic.java';src.parent.mkdir();src.write_text('package fixture;public class Generic {public static <T> T identity(T x){return x;} public static <T extends Object & Comparable<? super T>> T bounded(T x){return x;}}')
   subprocess.run([javac,'--release','8',str(src)],check=True,capture_output=True,timeout=30)
   jar=root/'android.jar'
   with zipfile.ZipFile(jar,'w') as z:
    for p in root.rglob('*.class'):z.write(p,str(p.relative_to(root)))
   (root/'source.properties').write_text('AndroidVersion.ApiLevel=36\nAndroidVersion.IsBaseSdk=true\n')
   xml=root/'api-versions.xml';xml.write_text('<api version="3"><class name="fixture/Generic" since="1"><method name="identity(Ljava/lang/Object;)Ljava/lang/Object;" since="12"/><method name="bounded(Ljava/lang/Object;)Ljava/lang/Object;" since="15"/></class></api>')
   plain=index_android_sdk(jar,root/'plain.sqlite',javap=javap);enriched=index_android_sdk(jar,root/'facts.sqlite',javap=javap,api_versions=xml)
   self.assertEqual(plain['provenance']['sourceSha256'],enriched['provenance']['sourceSha256'])
   self.assertEqual(enriched['provenance']['availabilityExactMatches'],2);self.assertEqual(enriched['provenance']['availabilityJvmDescriptorMode'],'javap-public-signatures')
   with Catalog(root/'facts.sqlite') as c:
    for name,since in [('identity',12),('bounded',15)]:
     record=c.get('android','fixture.Generic#'+name+'(T)','sdk-bytecode:36')['api']
     self.assertEqual(record['availability']['minimumApi'],since);self.assertEqual(record['availability']['jvmIdentity']['descriptor'],'(Ljava/lang/Object;)Ljava/lang/Object;')
     self.assertFalse(record['nativeTested'])
