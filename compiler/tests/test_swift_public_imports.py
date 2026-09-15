import json,os,subprocess,sys,tempfile,unittest
from pathlib import Path
from dcflight.platforms.ios_api import SDKCatalog
from dcflight.platforms.swift_imports import public_imports

class SwiftPublicImportsTests(unittest.TestCase):
 def catalog(self,root,module,path,kind,declaration,bystanders=()):
  graph=root/(module+'.symbols.json');graph.write_text(json.dumps({'module':{'name':module,'bystanders':list(bystanders)},'symbols':[{'identifier':{'precise':'fixture-'+module},'kind':{'identifier':kind},'pathComponents':path,'declarationFragments':[{'spelling':declaration}]}]}))
  return SDKCatalog.from_symbolgraphs([graph],module)
 def test_known_public_entrypoints_only_and_no_source_identity_rewrite(self):
  with tempfile.TemporaryDirectory() as temp:
   c=self.catalog(Path(temp),'SwiftUICore',['Color','red'],'swift.type.property','static var red: Color { get }')
   self.assertEqual('SwiftUICore',c.get('fixture-SwiftUICore').module)
   call=c.emit_call('fixture-SwiftUICore');self.assertEqual(('SwiftUI',),call.imports);self.assertEqual('`Color`.`red`',call.expression)
   restored=SDKCatalog.from_records([c.get('fixture-SwiftUICore').to_dict()]);self.assertEqual(call,restored.emit_call('fixture-SwiftUICore'))
 def test_bystander_entrypoints_deduplicate_and_unmapped_stay_exact(self):
  with tempfile.TemporaryDirectory() as temp:
   c=self.catalog(Path(temp),'Fixture',['value()'],'swift.func','func value() -> Int',['SwiftUICore','SwiftUI','RealityFoundation','RealityKit','Foundation'])
   self.assertEqual(('Fixture','Foundation','RealityKit','SwiftUI'),c.emit_call('fixture-Fixture').imports)
   self.assertEqual(('FutureSDK','_Unknown'),public_imports(['_Unknown','FutureSDK']))
 def test_verifier_routes_dependency_and_explicit_module_imports_together(self):
  from dcflight.ios_verification import candidate_for
  with tempfile.TemporaryDirectory() as temp:
   c=self.catalog(Path(temp),'SwiftUICore',['Color','red'],'swift.type.property','static var red: Color { get }')
   call=candidate_for(c,c.get('fixture-SwiftUICore'),'SwiftUICore',(18,0),['SwiftUICore','SwiftUI','Foundation'])
   self.assertEqual(['Foundation','SwiftUI'],call['imports'])
 def test_invalid_import_names_reject(self):
  for value in ['SwiftUI\nimport Unsafe','SwiftUI;bad','../SwiftUI',1,None]:
   with self.subTest(value=value),self.assertRaises(ValueError):public_imports([value])
 @unittest.skipUnless(sys.platform=='darwin','Requires Apple SDK')
 def test_sdk_public_entrypoints_compile_generated_expressions(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);swift=[];imports=set()
   for module,path,kind,declaration in [('SwiftUICore',['Color','red'],'swift.type.property','static var red: Color { get }'),('RealityFoundation',['Entity','init()'],'swift.init','init()')]:
    c=self.catalog(root,module,path,kind,declaration);call=c.emit_call('fixture-'+module);imports.update(call.imports);swift.append('let _: '+call.result_type+' = '+call.expression)
   source=root/'Verify.swift';source.write_text(''.join('import '+x+'\n' for x in sorted(imports))+'@MainActor func verify() { '+ '; '.join(swift)+' }\n')
   sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
   p=subprocess.run(['xcrun','swiftc','-typecheck','-swift-version','6','-target','arm64-apple-ios18.0-simulator','-sdk',sdk,str(source)],text=True,capture_output=True,timeout=120)
   self.assertEqual(0,p.returncode,p.stdout+p.stderr)
