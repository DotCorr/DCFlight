import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dcflight.platforms.ios_api import API,SDKCatalog,Reference
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.native_sequence import emit_sequence


def fixture(kind='struct',generic=False):
    owner={'identifier':{'precise':'owner'},'kind':{'identifier':'swift.'+kind},'pathComponents':['Flags'],'declarationFragments':[{'spelling':kind+' Flags'}]}
    if generic:owner['swiftGenerics']={'parameters':[{'name':'T','index':0,'depth':0}]}
    def method(identity,title,types,result,decl):
        return {'identifier':{'precise':identity},'kind':{'identifier':'swift.method'},'pathComponents':['Flags',title],
                'declarationFragments':[{'spelling':decl}],
                'functionSignature':{'parameters':[{'name':'p'+str(i),'declarationFragments':[{'spelling':'p'+str(i)+': '+typ}]} for i,typ in enumerate(types)],'returns':[{'spelling':result}]}}
    return {'symbols':[owner,method('union','union(_:)',('Self',),'Self','func union(_ other: Self) -> Self'),
                       method('form','formUnion(_:)',('Self',),'Void','mutating func formUnion(_ other: Self)'),
                       method('subset','isSubset(of:)',('Self',),'Bool','func isSubset(of other: Self) -> Bool')]}


class ConcreteSelfTests(unittest.TestCase):
    def catalog(self,root,data):
        path=root/'Fixture.symbols.json';path.write_text(json.dumps(data));return SDKCatalog.from_symbolgraphs([path],'Foundation')
    def test_value_self_resolution_and_mutating_ownership(self):
        with tempfile.TemporaryDirectory() as folder:
            for kind in ['struct','enum']:
                catalog=self.catalog(Path(folder),fixture(kind));api=catalog.get('union')
                self.assertEqual((),api.unsupported);self.assertEqual('Flags',api.result);self.assertEqual('Flags',api.parameters[0].type)
                self.assertIn('`left`.`union`',catalog.emit_call('union',[Reference('right','Flags')],receiver=Reference('left','Flags')).expression)
                with self.assertRaisesRegex(ValueError,'mutable receiver'):catalog.emit_call('form',[Reference('right','Flags')],receiver=Reference('left','Flags'))
                catalog.emit_call('form',[Reference('right','Flags')],receiver=Reference('left','Flags',mutable=True))
    def test_polymorphic_generic_and_dependent_cases_stay_blocked(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            for kind,generic in [('class',False),('protocol',False),('struct',True)]:
                self.assertTrue(self.catalog(root,fixture(kind,generic)).get('union').unsupported)
            for spelling in ['Self.Element','some View','Self']:
                data=fixture();symbol=data['symbols'][1]
                symbol['declarationFragments']=[{'spelling':'func union(_ other: Self) '+('rethrows ' if spelling=='Self' else '')+'-> '+spelling}]
                symbol['functionSignature']['returns']=[{'spelling':spelling}]
                self.assertTrue(self.catalog(root,data).get('union').unsupported)
            record=API('unsafe','Foundation',('Flags','value'),'property',(),'Self',(),(),owner_kind='struct').to_dict()
            with self.assertRaisesRegex(ValueError,'Self requires'):SDKCatalog.from_records([record])
    def test_structural_optional_collection_and_callback_substitution(self):
        from dcflight.platforms.ios_api import _concrete_self_type
        self.assertEqual('Dictionary<String, Array<Flags?>>',_concrete_self_type('[String: [Self?]]','Flags'))
        self.assertEqual('(@Sendable (Flags) async throws -> Flags?)?',_concrete_self_type('(@Sendable (Self) async throws -> Self?)?','Flags'))
        with self.assertRaisesRegex(ValueError,'Dependent Self'):_concrete_self_type('Self.Element','Flags')
    def test_evaluated_dart_native_steps_match_json(self):
        from dcflight.evaluated_frontend import load_evaluated_operation
        dart=os.environ.get('DCFLIGHT_DART') or shutil.which('dart')
        if not dart:self.skipTest('Dart SDK required')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);data=fixture()
            for name in ['first','second']:
                data['symbols'].append({'identifier':{'precise':name},'kind':{'identifier':'swift.type.property'},'pathComponents':['Flags',name],'declarationFragments':[{'spelling':'static var '+name+': Flags { get }'}]})
            catalog=self.catalog(root,data);database=root/'sdk.sqlite'
            with Catalog(database,write=True) as db:db.import_records('ios','Fixture','fixture',catalog.records(),{'fixture':True})
            path=root/'operation.dart';path.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeOperation buildOperation() => NativeOperation(name:'testFlags',result:NativeScalar.bool,
 ios:NativeImplementation(steps:[NativeCall('first',bind:'left'),NativeCall('second',bind:'right'),
 NativeCall('union',receiver:NativeRef('left'),arguments:[NativeRef('right')],bind:'combined'),
 NativeCall('subset',receiver:NativeRef('left'),arguments:[NativeRef('combined')],bind:'answer')],result:NativeRef('answer')),
 android:NativeImplementation(steps:[NativeCall('java.lang.Boolean#logicalOr(boolean,boolean)',arguments:[NativeLiteral(true),NativeLiteral(false)],bind:'answer')],result:NativeRef('answer')));
""")
            evaluated=load_evaluated_operation(path,dart)
            steps=[{'id':'first','bind':'left'},{'id':'second','bind':'right'},
                   {'id':'union','receiver':{'ref':'left'},'arguments':[{'ref':'right'}],'bind':'combined'},
                   {'id':'subset','receiver':{'ref':'left'},'arguments':[{'ref':'combined'}],'bind':'answer'}]
            native=NativeAPI(database)
            expected=emit_sequence(native,{'platform':'ios','steps':steps})
            actual=emit_sequence(native,{'platform':'ios','steps':evaluated['implementations']['ios']['steps']})
            self.assertEqual(expected,actual)
    def test_public_native_api_sequence_executes_option_set_behavior(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);catalog=self.catalog(root,fixture());database=root/'sdk.sqlite'
            with Catalog(database,write=True) as db:db.import_records('ios','Fixture','fixture',catalog.records(),{'fixture':True})
            native=NativeAPI(database)
            sequence={'platform':'ios','inputs':[{'name':'left','type':'Flags','mutable':True},{'name':'right','type':'Flags'}],
                      'steps':[{'id':'union','receiver':{'ref':'left'},'arguments':[{'ref':'right'}],'bind':'combined'},
                               {'id':'subset','receiver':{'ref':'left'},'arguments':[{'ref':'combined'}],'bind':'subset'},
                               {'id':'form','receiver':{'ref':'left'},'arguments':[{'ref':'right'}]}]}
            generated=emit_sequence(native,sequence)
            self.assertIsNone(generated['compilerRuntimeDependency']);self.assertEqual('Flags',generated['bindings'][0]['type'])
            if not shutil.which('swiftc'):self.skipTest('Swift compiler required')
            source=root/'main.swift';source.write_text('''import Foundation
struct Flags: OptionSet { let rawValue: Int; static let first=Flags(rawValue:1); static let second=Flags(rawValue:2) }
var left=Flags.first
let right=Flags.second
'''+generated['source']+'''
precondition(dcfLocal0.rawValue == 3)
precondition(dcfLocal1)
precondition(left.rawValue == 3)
print("OptionSet behavior passed")
''')
            binary=root/'proof';built=subprocess.run(['swiftc','-module-cache-path',str(root/'cache'),str(source),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(0,built.returncode,built.stderr)
            run=subprocess.run([str(binary)],capture_output=True,text=True);self.assertEqual(0,run.returncode,run.stderr);self.assertIn('passed',run.stdout)


if __name__=='__main__':unittest.main()
