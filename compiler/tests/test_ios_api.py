import json
import shutil
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from dcflight.platforms.ios_api import API, Parameter, SDKCatalog, Literal, Reference, parse_cli_value


def symbol(kind='swift.method', title='setValue(_:enabled:)', types=('String', 'Bool'), result='Void', **extra):
    value = {'identifier': {'precise': 'sdk:exact-overload'}, 'kind': {'identifier': kind},
             'pathComponents': ['Widget', title], 'declarationFragments': [{'spelling': 'func setValue()'}],
             'functionSignature': {'parameters': [{'name': 'arg'+str(i), 'declarationFragments': [{'spelling': 'arg: '+typ}]} for i,typ in enumerate(types)],
                                   'returns': [{'spelling': result}]}}
    value.update(extra)
    return value


class IOSAPITests(unittest.TestCase):
    def test_callable_effects_exclude_callback_parameter_and_result_effects(self):
        from dcflight.platforms.ios_api import _call_effects
        cases=[
            ('func use(_ callback: () async throws -> Void)', 'swift.method', (False,False)),
            ('func make() -> () async throws -> Void', 'swift.method', (False,False)),
            ('func fetch(_ callback: () throws -> Void) async throws -> Int', 'swift.method', (True,True)),
            ('var callback: () async throws -> Void { get }', 'swift.property', (False,False)),
            ('var value: Int { get async throws }', 'swift.property', (True,True)),
        ]
        for declaration,kind,expected in cases:
            with self.subTest(declaration=declaration):self.assertEqual(expected,_call_effects(declaration,kind))

    def test_required_native_imports_are_preserved_and_validated(self):
        from dataclasses import replace
        catalog=self.catalog(symbol())
        original=catalog.get('sdk:exact-overload')
        api=replace(original,required_imports=('CoreImage','Foundation'))
        loaded=SDKCatalog.from_records([api.to_dict()])
        out=loaded.emit_call(api.id,[Literal('x'),Literal(True)],receiver=Reference('widget','Widget'))
        self.assertEqual(('CoreImage','Foundation'),out.imports)
        for imports in ('CoreImage',['UIKit; bad()'],[None]):
            record=api.to_dict();record['requiredImports']=imports
            with self.assertRaises(ValueError):SDKCatalog.from_records([record])

    def catalog(self, s):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'SDK.symbols.json'
            path.write_text(json.dumps({'symbols': [{'identifier':{'precise':'owner:Widget'},'kind':{'identifier':'swift.class'},'pathComponents':['Widget']}, s]}))
            catalog = SDKCatalog.from_symbolgraphs([path], 'Foundation')
            catalog.apis.pop('owner:Widget')
            return catalog

    def test_direct_call_labels_and_receiver(self):
        c=self.catalog(symbol())
        out=c.emit_call('sdk:exact-overload',[Literal('hi'),Literal(True)],receiver=Reference('widget','Widget'))
        self.assertEqual(out.expression,'(`widget`.`setValue`(("hi" as String), `enabled`: (true as Bool)) as Void)')
        self.assertEqual(out.imports,('Foundation',))

    def test_no_source_escape(self):
        c=self.catalog(symbol())
        for receiver in [Reference('x); evil()','Widget'), Reference('x','Other')]:
            with self.assertRaises(ValueError):
                c.emit_call('sdk:exact-overload',[Literal('hi'),Literal(True)],receiver=receiver)
        with self.assertRaises(ValueError):
            parse_cli_value({'swift':'evil()'})
        out=c.emit_call('sdk:exact-overload',[Literal('\\(evil())\n"'),Literal(False)],receiver=Reference('x','Widget'))
        self.assertIn('\\\\(evil())\\u{a}\\"',out.expression)

    def test_types_arity_and_integer_range(self):
        c=self.catalog(symbol(title='setValue(_:)',types=('UInt8',)))
        for value in [-1,256,True,'1']:
            with self.assertRaises(ValueError):
                c.emit_call('sdk:exact-overload',[Literal(value)],receiver=Reference('x','Widget'))
        with self.assertRaises(ValueError):
            c.emit_call('sdk:exact-overload',[],receiver=Reference('x','Widget'))

    def test_availability(self):
        c=self.catalog(symbol(availability=[{'domain':'iOS','introduced':{'major':20}}]))
        with self.assertRaisesRegex(ValueError,'availability'):
            c.emit_call('sdk:exact-overload',[Literal('hi'),Literal(True)],receiver=Reference('x','Widget'))

    def test_constructor_static_property(self):
        c=self.catalog(symbol(kind='swift.init',title='init()',types=()))
        self.assertEqual(c.emit_call('sdk:exact-overload').expression,'(`Widget`() as Widget)')
        c=self.catalog(symbol(kind='swift.type.property', title='current',types=(),declarationFragments=[{'spelling':'static var current: Widget { get }'}]))
        out=c.emit_call('sdk:exact-overload')
        self.assertEqual(out.expression,'`Widget`.`current`')
        self.assertEqual(out.result_type,'Widget')

    def test_unsupported_shapes_explained(self):
        for s in [symbol(types=('@UnknownActor (Int) -> Void','Bool')),symbol(swiftGenerics={'parameters':[{'name':'T'}]}),symbol(result='some View')]:
            c=self.catalog(s)
            self.assertFalse(list(c.records())[0]['emittable'])
            with self.assertRaises(ValueError):
                c.emit_call('sdk:exact-overload')

    def test_async_throw_requires_context(self):
        c=self.catalog(symbol(title='load()',types=(),declarationFragments=[{'spelling':'func load() async throws'}]))
        with self.assertRaises(ValueError):
            c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget'))
        self.assertEqual(c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget'),allow_async=True,allow_throws=True).expression,'(try await `x`.`load`() as Void)')

    def test_writable_property(self):
        c=self.catalog(symbol(kind='swift.property',title='text',types=(),declarationFragments=[{'spelling':'var text: String? { get set }'}]))
        self.assertEqual(c.emit_set('sdk:exact-overload',Literal('hello'),receiver=Reference('label','Widget')).expression, '`label`.`text` = "hello"')
        c=self.catalog(symbol(kind='swift.property',title='text',types=(),declarationFragments=[{'spelling':'var text: String? { get }'}]))
        with self.assertRaises(ValueError):
            c.emit_set('sdk:exact-overload',Literal('hello'),receiver=Reference('label','Widget'))

    def test_optional_objc_method_and_mutation(self):
        c=self.catalog(symbol(title='save()',types=(),declarationFragments=[{'spelling':'optional func save()'}]))
        self.assertEqual(c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget')).expression,'(`x`.`save`?() as Void?)')
        c=self.catalog(symbol(title='update()',types=(),declarationFragments=[{'spelling':'mutating func update()'}]))
        with self.assertRaises(ValueError):
            c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget'))
        self.assertEqual(c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget',mutable=True)).expression,'(`x`.`update`() as Void)')

    def test_obsolete_swift_alias_is_unsupported(self):
        c=self.catalog(symbol(availability=[{'domain':'Swift','obsoleted':{'major':3},'renamed':'newName'}]))
        self.assertIn('obsolete Swift spelling',c.get('sdk:exact-overload').unsupported[0])

    def test_optional_objc_property_read_preserves_optional_result(self):
        c=self.catalog(symbol(kind='swift.property',title='text',types=(),declarationFragments=[{'spelling':'optional var text: String { get }'}]))
        result=c.emit_call('sdk:exact-overload',receiver=Reference('delegate','Widget'))
        self.assertEqual('String?',result.result_type)
        self.assertEqual('`delegate`.`text`',result.expression)

    def test_precise_identity_export(self):
        c=self.catalog(symbol())
        self.assertEqual(list(c.records())[0]['id'],'sdk:exact-overload')
        records=list(c.records())
        json.dumps(records)
        self.assertEqual(SDKCatalog.from_records(records).get('sdk:exact-overload'),c.get('sdk:exact-overload'))
        del records[0]['path']
        self.assertEqual(SDKCatalog.from_records(records).get('sdk:exact-overload'),c.get('sdk:exact-overload'))
        self.assertIsNone(c.coverage()['native_tested'])

class IOSAPIAuditTests(unittest.TestCase):
    def record(self):
        return API('precise','Fixture',('select(_:)',),'function',(Parameter('_','value','Double'),),'String',(),()).to_dict()

    def test_normalized_descriptors_reject_injection_and_disagreement(self):
        for change in [{'module':'Foundation; evil()'}, {'path':['select(_:) { evil() }']},
                       {'owner':'WrongOwner'}, {'resultType':'String; evil()'},
                       {'async':'false'}, {'availability':[{'domain':'iOS','introduced':{'major':'18'}}]},
                       {'parameters':[{'label':'x); evil(','name':'x','type':'Double'}]}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                SDKCatalog.from_records([{**self.record(),**change}])

    def test_explicit_rejection_and_identity_collision_fail_closed(self):
        for change in [{'emittable':False},{'nativeConformance':{'status':'rejected'}}]:
            catalog=SDKCatalog.from_records([{**self.record(),**change}])
            with self.assertRaises(ValueError): catalog.emit_call('precise',[Literal(1.0)])
        with self.assertRaises(ValueError):
            SDKCatalog.from_records([self.record(),{**self.record(),'resultType':'Int'}])

    def test_literal_bounds_and_unicode_scalars(self):
        for typ,value in [('Float',1e100),('Double',10**1000),('Double',float('nan')),('String','\ud800')]:
            record=self.record();record['parameters'][0]['type']=typ
            catalog=SDKCatalog.from_records([record])
            with self.subTest(type=typ), self.assertRaises(ValueError): catalog.emit_call('precise',[Literal(value)])

    def test_swift_availability_is_rechecked_on_normalized_records(self):
        record=self.record();record['availability']=[{'domain':'Swift','obsoleted':{'major':3}}]
        with self.assertRaises(ValueError): SDKCatalog.from_records([record]).emit_call('precise',[Literal(1.0)])

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('xcrun'),'requires Apple Swift toolchain')
    def test_native_overload_selection_uses_parameter_and_result_types(self):
        catalog=SDKCatalog.from_records([self.record(),API('return-overload','Fixture',('pick()',),'function',(),'String',(),()).to_dict()])
        source='func select(_ value: Int) -> String { "int" }\nfunc select(_ value: Double) -> String { "double" }\nfunc pick() -> Int { 1 }\nfunc pick() -> String { "string" }\n'
        source+='print('+catalog.emit_call('precise',[Literal(1)]).expression+')\n'
        source+='print('+catalog.emit_call('return-overload').expression+')\n'
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'main.swift';path.write_text(source);binary=Path(directory)/'verify'
            subprocess.run(['xcrun','swiftc','-module-name','Fixture',str(path),'-o',str(binary)],check=True,capture_output=True)
            self.assertEqual(subprocess.check_output([str(binary)],text=True),'double\nstring\n')

if __name__ == '__main__':
    unittest.main()


class SetterOwnershipTests(unittest.TestCase):
    def make(self, kind, owner='URLComponents', member='path', nonmutating=False):
        prop=symbol(kind='swift.property',title=member,types=(),declarationFragments=[{'spelling':'var '+member+': String { get '+('nonmutating ' if nonmutating else '')+'set }'}])
        prop['pathComponents']=[owner,member]
        nominal={'identifier':{'precise':'owner'},'kind':{'identifier':'swift.'+kind},'pathComponents':[owner]}
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'graph.json';path.write_text(json.dumps({'symbols':[prop,nominal]}))
            return SDKCatalog.from_symbolgraphs([path], 'Foundation')

    def test_value_class_and_legacy_records(self):
        for kind in ('struct','enum'):
            c=self.make(kind)
            with self.assertRaisesRegex(ValueError,'mutable receiver'):
                c.emit_set('sdk:exact-overload',Literal('/a'),receiver=Reference('parts','URLComponents'))
            c.emit_set('sdk:exact-overload',Literal('/a'),receiver=Reference('parts','URLComponents',True))
            record=c.get('sdk:exact-overload').to_dict()
            self.assertEqual(record['ownerKind'],kind);self.assertIs(record['setterMutating'],True)
            restored=SDKCatalog.from_records([record])
            with self.assertRaises(ValueError):restored.emit_set(record['id'],Literal('/a'),receiver=Reference('parts','URLComponents'))
        c=self.make('class','Person','name')
        self.assertEqual(c.emit_set('sdk:exact-overload',Literal('A'),receiver=Reference('person','Person')).expression,'`person`.`name` = "A"')
        record=c.get('sdk:exact-overload').to_dict();record.pop('ownerKind');record.pop('setterMutating')
        c=SDKCatalog.from_records([record])
        with self.assertRaises(ValueError):c.emit_set(record['id'],Literal('A'),receiver=Reference('person','Person'))
        c.emit_set(record['id'],Literal('A'),receiver=Reference('person','Person',True))

    def test_nonmutating_setter_and_invalid_metadata(self):
        c=self.make('struct',nonmutating=True)
        c.emit_set('sdk:exact-overload',Literal('/a'),receiver=Reference('parts','URLComponents'))
        record=c.get('sdk:exact-overload').to_dict();record['setterMutating']='false'
        with self.assertRaises(ValueError):SDKCatalog.from_records([record])

    @unittest.skipUnless(shutil.which('xcrun'),'Swift SDK required')
    def test_real_swift_value_and_reference_assignment(self):
        value=self.make('struct').emit_set('sdk:exact-overload',Literal('/a'),receiver=Reference('parts','URLComponents',True)).expression
        reference=self.make('class','Person','name').emit_set('sdk:exact-overload',Literal('A'),receiver=Reference('person','Person')).expression
        source='import Foundation\nfinal class Person { var name = "" }\nfunc check() { var parts = URLComponents(); let person = Person(); '+value+'; '+reference+' }'
        result=subprocess.run(['xcrun','swiftc','-typecheck','-'],input=source,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        invalid=source.replace('var parts =','let parts =')
        result=subprocess.run(['xcrun','swiftc','-typecheck','-'],input=invalid,text=True,capture_output=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn("'parts' is a 'let' constant",result.stderr)
