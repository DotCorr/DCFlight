import json
from pathlib import Path
import tempfile
import unittest
from dcflight.platforms.ios_api import SDKCatalog, Literal, Reference, parse_cli_value


def symbol(kind='swift.method', title='setValue(_:enabled:)', types=('String', 'Bool'), result='Void', **extra):
    value = {'identifier': {'precise': 'sdk:exact-overload'}, 'kind': {'identifier': kind},
             'pathComponents': ['Widget', title], 'declarationFragments': [{'spelling': 'func setValue()'}],
             'functionSignature': {'parameters': [{'name': 'arg'+str(i), 'declarationFragments': [{'spelling': 'arg: '+typ}]} for i,typ in enumerate(types)],
                                   'returns': [{'spelling': result}]}}
    value.update(extra)
    return value


class IOSAPITests(unittest.TestCase):
    def catalog(self, s):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'SDK.symbols.json'
            path.write_text(json.dumps({'symbols': [s]}))
            return SDKCatalog.from_symbolgraphs([path], 'Foundation')

    def test_direct_call_labels_and_receiver(self):
        c=self.catalog(symbol())
        out=c.emit_call('sdk:exact-overload',[Literal('hi'),Literal(True)],receiver=Reference('widget','Widget'))
        self.assertEqual(out.expression,'`widget`.`setValue`("hi", `enabled`: true)')
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
        self.assertEqual(c.emit_call('sdk:exact-overload').expression,'`Widget`()')
        c=self.catalog(symbol(kind='swift.type.property', title='current',types=(),declarationFragments=[{'spelling':'static var current: Widget { get }'}]))
        out=c.emit_call('sdk:exact-overload')
        self.assertEqual(out.expression,'`Widget`.`current`')
        self.assertEqual(out.result_type,'Widget')

    def test_unsupported_shapes_explained(self):
        for s in [symbol(types=('(Int) -> Void','Bool')),symbol(swiftGenerics={'parameters':[{'name':'T'}]}),symbol(result='some View')]:
            c=self.catalog(s)
            self.assertFalse(list(c.records())[0]['emittable'])
            with self.assertRaises(ValueError):
                c.emit_call('sdk:exact-overload')

    def test_async_throw_requires_context(self):
        c=self.catalog(symbol(title='load()',types=(),declarationFragments=[{'spelling':'func load() async throws'}]))
        with self.assertRaises(ValueError):
            c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget'))
        self.assertEqual(c.emit_call('sdk:exact-overload',receiver=Reference('x','Widget'),allow_async=True,allow_throws=True).expression,'try await `x`.`load`()')

    def test_precise_identity_export(self):
        c=self.catalog(symbol())
        self.assertEqual(list(c.records())[0]['id'],'sdk:exact-overload')
        json.dumps(list(c.records()))
        self.assertIsNone(c.coverage()['native_tested'])

if __name__ == '__main__':
    unittest.main()
