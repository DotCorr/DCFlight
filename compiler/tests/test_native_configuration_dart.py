"""Typed Dart native metadata must retain the canonical tagged input document."""
import os
import shutil
import tempfile
import unittest
from pathlib import Path

from dcflight.evaluated_frontend import load_evaluated
from dcflight.validate import Diagnostic


@unittest.skipUnless(shutil.which('dart'), 'Dart SDK required')
class NativeConfigurationDartTests(unittest.TestCase):
    def evaluate(self, expression):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authoring = None
            staged = os.environ.get('DCFLIGHT_TEST_AUTHORING_LIBRARY')
            if staged:
                authoring = root / 'authoring'
                (authoring / 'lib').mkdir(parents=True)
                shutil.copyfile(staged, authoring / 'lib/dcflight.dart')
            source = root / 'app.dart'
            source.write_text("import 'package:dcflight_authoring/dcflight.dart';\n"
                              'App buildApp() => ' + expression + ';')
            return load_evaluated(source, shutil.which('dart'), authoring=authoring)

    def test_all_plist_types_and_manifest_match_canonical_json(self):
        doc = self.evaluate("""const App(id:'com.example.config', name:'Config',
 root:Node(id:'root',type:'text',props:{'text':'Metadata'}),
 nativeConfiguration:NativeConfiguration(
  ios:IOSConfiguration(infoPlist:{
   'Label':PlistValue.string('A & B'),
   'Count':PlistValue.integer(3),
   'Scale':PlistValue.real(1.25),
   'Enabled':PlistValue.boolean(true),
   'Payload':PlistValue.data('AAH/'),
   'Timestamp':PlistValue.date('2026-09-14T12:00:00Z'),
   'Groups':PlistValue.array([PlistValue.string('one'),PlistValue.integer(2)]),
   'Nested':PlistValue.dictionary({'Empty':PlistValue.array([])}),
  },entitlements:{'keychain-access-groups':PlistValue.array([PlistValue.string('group.example')])}),
  android:AndroidConfiguration(manifest:ManifestElement('manifest',attributes:{
   'xmlns:android':'http://schemas.android.com/apk/res/android'
  },children:[ManifestElement('uses-permission',attributes:{'android:name':'android.permission.INTERNET'}),
   ManifestElement('application',children:[ManifestElement('meta-data',attributes:{
    'android:name':'example.label','android:value':'A & B'
   })])]))))""")
        def value(kind, data):
            return {'type': kind, 'value': data}
        expected = {
            'ios': {'deploymentTarget': [17, 0], 'infoPlist': {
                'Label': value('string', 'A & B'), 'Count': value('integer', 3),
                'Scale': value('real', 1.25), 'Enabled': value('boolean', True),
                'Payload': value('data', 'AAH/'),
                'Timestamp': value('date', '2026-09-14T12:00:00Z'),
                'Groups': value('array', [value('string', 'one'), value('integer', 2)]),
                'Nested': value('dictionary', {'Empty': value('array', [])}),
            }, 'entitlements': {
                'keychain-access-groups': value('array', [value('string', 'group.example')]),
            }},
            'android': {'compileSdk':35,'minSdk':26,'targetSdk':35,'validateNativeAvailability':False,'sourceSets': ['debug', 'release'], 'manifest': {
                'tag': 'manifest', 'attributes': {'xmlns:android': 'http://schemas.android.com/apk/res/android'},
                'children': [
                    {'tag': 'uses-permission', 'attributes': {'android:name': 'android.permission.INTERNET'}, 'children': []},
                    {'tag': 'application', 'attributes': {}, 'children': [
                        {'tag': 'meta-data', 'attributes': {'android:name': 'example.label', 'android:value': 'A & B'}, 'children': []},
                    ]},
                ],
            }},
        }
        self.assertEqual(doc['nativeConfiguration'], expected)

    def test_routed_app_forwards_metadata_and_custom_source_sets(self):
        doc = self.evaluate("""const RoutedApp(id:'com.example.routed',name:'Routed',
 root:Node(id:'root',type:'text',props:{'text':'Hello'}),screens:[],
 nativeConfiguration:NativeConfiguration(android:AndroidConfiguration(sourceSets:['qa','release'])))""")
        self.assertEqual(doc['version'], 2)
        self.assertEqual(doc['nativeConfiguration'], {'android': {'compileSdk':35,'minSdk':26,'targetSdk':35,'validateNativeAvailability':False,'sourceSets': ['qa', 'release']}})

    def test_omitted_configuration_stays_absent(self):
        doc = self.evaluate("const App(id:'com.example.plain',name:'Plain',root:Node(id:'root',type:'text'))")
        self.assertNotIn('nativeConfiguration', doc)

    def test_registered_manifest_extension_namespaces_are_preserved(self):
        doc = self.evaluate("""const App(id:'com.example.module',name:'Module',
 root:Node(id:'root',type:'text'),nativeConfiguration:NativeConfiguration(
 android:AndroidConfiguration(namespaces:{'dist':'http://schemas.android.com/apk/distribution'},
  manifest:ManifestElement('manifest',children:[ManifestElement('dist:module',
   attributes:{'dist:instant':'false'},children:[ManifestElement('dist:delivery',
    children:[ManifestElement('dist:install-time')])])]))))""")
        android = doc['nativeConfiguration']['android']
        self.assertEqual(android['namespaces'], {'dist': 'http://schemas.android.com/apk/distribution'})
        self.assertEqual(android['manifest']['children'], [{
            'tag': 'dist:module', 'attributes': {'dist:instant': 'false'}, 'children': [{
                'tag': 'dist:delivery', 'attributes': {}, 'children': [{
                    'tag': 'dist:install-time', 'attributes': {}, 'children': [],
                }],
            }],
        }])

    def test_dart_rejects_untyped_values_before_serialization(self):
        configurations = (
            "NativeConfiguration(ios:IOSConfiguration(infoPlist:{'key':'untyped'}))",
            "NativeConfiguration(ios:IOSConfiguration(infoPlist:{'key':PlistValue.integer('3')}))",
            "NativeConfiguration(ios:IOSConfiguration(infoPlist:{'key':PlistValue.boolean(1)}))",
            "NativeConfiguration(ios:IOSConfiguration(infoPlist:{'key':PlistValue.array(['raw'])}))",
            "NativeConfiguration(ios:IOSConfiguration(infoPlist:{'key':PlistValue.dictionary({'nested':false})}))",
            "NativeConfiguration(android:AndroidConfiguration(manifest:ManifestElement('application',attributes:{'enabled':true})))",
            "NativeConfiguration(android:AndroidConfiguration(manifest:ManifestElement('manifest',children:['raw XML'])))",
            "NativeConfiguration(android:AndroidConfiguration(sourceSets:[1]))",
            "NativeConfiguration(android:AndroidConfiguration(namespaces:{'dist':false}))",
        )
        for config in configurations:
            with self.subTest(config=config), self.assertRaisesRegex(Diagnostic, 'Dart authoring failed'):
                self.evaluate("const App(id:'com.example.invalid',name:'Invalid',"
                              "root:Node(id:'root',type:'text'),nativeConfiguration:" + config + ')')
