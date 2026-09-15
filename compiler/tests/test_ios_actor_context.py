import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Reference
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_operation import emit_operation

@unittest.skipUnless(shutil.which('xcrun'),'Native Swift toolchain required')
class IOSActorContextTests(unittest.TestCase):
    def test_custom_global_actor_identity_roundtrip_and_native_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'Fixture.swift'
            source.write_text('''@globalActor public actor DatabaseActor {
                public static let shared = DatabaseActor()
            }
            @DatabaseActor public class Store {
                public init() {}
                public func value() -> Int32 { 9 }
                nonisolated public func label() -> String { "store" }
            }
            ''')
            subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-emit-module',
                '-module-name', 'Fixture', str(source), '-emit-module-path', str(root/'Fixture.swiftmodule')],
                check=True, capture_output=True)
            target = json.loads(subprocess.check_output(['xcrun', 'swiftc', '-print-target-info'], text=True))['target']['triple']
            sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
            subprocess.run(['xcrun', 'swift-symbolgraph-extract', '-module-name', 'Fixture', '-I', tmp,
                '-output-dir', tmp, '-target', target, '-sdk', sdk], check=True, capture_output=True)
            graph = root / 'Fixture.symbols.json'
            api = SDKCatalog.from_symbolgraphs([graph], 'Fixture')
            methods = {a.path: a for a in api.apis.values()}
            member = methods[('Store', 'value()')]
            context = 'global:Fixture.DatabaseActor'
            self.assertEqual(context, member.actor_isolation)
            self.assertEqual('nonisolated', methods[('Store', 'label()')].actor_isolation)
            receiver = Reference('store', 'Store')
            for wrong in (None, 'main', 'nonisolated', 'global:Other.DatabaseActor'):
                with self.assertRaisesRegex(ValueError, 'matching actor context'):
                    api.emit_call(member.id, receiver=receiver, actor_context=wrong)
            expression = api.emit_call(member.id, receiver=receiver, actor_context=context).expression
            caller = root / 'Caller.swift'
            caller.write_text('@DatabaseActor func verify() -> Int32 { let store = Store(); return ' + expression + ''' }
            @main struct Runner { static func main() async {
                let value = await verify(); precondition(value == 9)
            } }
            ''')
            executable = root / 'verify'
            subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library',
                str(source), str(caller), '-o', str(executable)], check=True, capture_output=True)
            subprocess.run([str(executable)], check=True, capture_output=True, timeout=15)
            caller.write_text('func verify(_ store: Store) -> Int32 { return ' + expression + ' }')
            rejected = subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-typecheck',
                str(source), str(caller)], capture_output=True, text=True)
            self.assertNotEqual(0, rejected.returncode)
            self.assertIn('actor', rejected.stderr)
            database = root / 'api.db'
            with Catalog(database, write=True) as catalog:
                catalog.import_records('ios', 'Fixture', '26.2', [member.to_dict()], {'fixture': True})
            request = {'platform': 'ios', 'id': member.id, 'receiver': {'ref': 'store', 'type': 'Store'}, 'actorContext': context}
            self.assertEqual(context, NativeAPI(database).emit(request)['actorIsolation'])
            # The owner carries the contract when a member omits repeated attributes.
            data = json.loads(graph.read_text())
            for symbol in data['symbols']:
                if symbol['pathComponents'] == ['Store', 'value()']:
                    symbol['declarationFragments'] = [{'kind': 'text', 'spelling': 'func value() -> Int32'}]
            graph.write_text(json.dumps(data))
            self.assertEqual(context, SDKCatalog.from_symbolgraphs([graph], 'Fixture').get(member.id).actor_isolation)

    def test_actual_symbolgraph_actor_validation_and_swift_compilation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);source=root/'ActorFixture.swift'
            source.write_text('@MainActor public class Counter { public init() {}\n public func value() -> Int32 { 7 }\n nonisolated public func label() -> String { "counter" }\n}\n')
            subprocess.run(['xcrun','swiftc','-emit-module','-module-name','ActorFixture',str(source),'-emit-module-path',str(root/'ActorFixture.swiftmodule')],check=True,capture_output=True)
            target=json.loads(subprocess.check_output(['xcrun','swiftc','-print-target-info'],text=True))['target']['triple']
            sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            subprocess.run(['xcrun','swift-symbolgraph-extract','-module-name','ActorFixture','-I',tmp,'-output-dir',tmp,'-target',target,'-sdk',sdk],check=True,capture_output=True)
            graph=root/'ActorFixture.symbols.json';api=SDKCatalog.from_symbolgraphs([graph],'ActorFixture')
            methods={a.path[-1]:a for a in api.apis.values()}
            self.assertEqual('main',methods['value()'].actor_isolation)
            self.assertEqual('nonisolated',methods['label()'].actor_isolation)
            receiver=Reference('counter','Counter')
            with self.assertRaisesRegex(ValueError,'MainActor'):api.emit_call(methods['value()'].id,receiver=receiver)
            expression=api.emit_call(methods['value()'].id,receiver=receiver,actor_context='main').expression
            api.emit_call(methods['label()'].id,receiver=receiver,actor_context='nonisolated')
            caller=root/'Caller.swift';caller.write_text('import ActorFixture\n@MainActor func verify(_ counter:Counter) { let value='+expression+'; precondition(value==7) }')
            subprocess.run(['xcrun','swiftc','-swift-version','6','-typecheck','-I',tmp,str(caller)],check=True,capture_output=True)
            caller.write_text(caller.read_text().replace('@MainActor func','func'))
            rejected=subprocess.run(['xcrun','swiftc','-swift-version','6','-typecheck','-I',tmp,str(caller)],capture_output=True,text=True)
            self.assertNotEqual(0,rejected.returncode);self.assertIn('main actor',rejected.stderr.lower())
            database=root/'api.db'
            with Catalog(database,write=True) as c:c.import_records('ios','Fixture','26.2',[a.to_dict() for a in api.apis.values()],{'fixture':True})
            request={'platform':'ios','id':methods['value()'].id,'receiver':{'ref':'counter','type':'Counter'}}
            with self.assertRaisesRegex(ValueError,'MainActor'):NativeAPI(database).emit(request)
            self.assertEqual('main',NativeAPI(database).emit({**request,'actorContext':'main'})['actorIsolation'])
            # Owner metadata also covers member fragments without repeated attributes.
            data=json.loads(graph.read_text())
            for symbol in data['symbols']:
                if symbol['pathComponents']==['Counter','value()']:
                    symbol['declarationFragments']=[{'kind':'text','spelling':'func value() -> Int32'}]
            graph.write_text(json.dumps(data))
            inherited=SDKCatalog.from_symbolgraphs([graph],'ActorFixture')
            self.assertEqual('main',inherited.get(methods['value()'].id).actor_isolation)

    def test_main_actor_context_passes_through_operation(self):
        from dcflight.platforms.ios_api import API
        from dcflight.native_api import index_android
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);database=root/'api.db';source=root/'android.txt'
            source.write_text('package demo {\n public class Counter {\n method public static String label();\n }\n}\n')
            index_android(database,source)
            descriptor=API('label','Fixture',('Counter','label()'),'static_method',(),'String',(),(),actor_isolation='main').to_dict()
            with Catalog(database,write=True) as c:c.import_records('ios','Fixture','26.2',[descriptor],{'fixture':True})
            operation={'name':'label','result':'string','execution':'main','implementations':{
                'ios':{'steps':[{'id':'label','bind':'result'}],'return':{'ref':'result'}},
                'android':{'steps':[{'id':'demo.Counter#label()','bind':'result'}],'return':{'ref':'result'}}}}
            out=emit_operation(NativeAPI(database),operation);self.assertIn('@MainActor',out['targets']['ios']['source'])
            operation['execution']='caller'
            with self.assertRaisesRegex(ValueError,'MainActor'):emit_operation(NativeAPI(database),operation)
