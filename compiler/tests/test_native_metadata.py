import json
from pathlib import Path
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET
from dcflight.compiler import compile_app
from dcflight.validate import Diagnostic
from dcflight.sync import Conflict


def document(name='First name'):
    return {'version':2,'id':'com.example.metadata','name':name,'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'','body':{'id':'text','type':'text','props':{'text':'Metadata'}}}]}


class NativeMetadataTests(unittest.TestCase):
    def test_rename_updates_generated_metadata_and_preserves_user_projects(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'app.json';out=root/'native';doc=document();compile_app(source,out,document=doc)
            project=out/'ios/App.xcodeproj/project.pbxproj';manifest=out/'android/app/src/main/AndroidManifest.xml'
            project.write_text(project.read_text()+'\n// User build notes\n');manifest.write_text(manifest.read_text()+'\n<!-- User manifest notes -->\n')
            before=[p.read_bytes() for p in (project,manifest)]
            doc['name']='Renamed "team" & friends \\ test'
            changed=compile_app(source,out,document=doc)
            self.assertIn('ios/Native/AppInfo.plist',changed['write'])
            self.assertIn('android/app/src/main/res/values/native_app.xml',changed['write'])
            self.assertEqual(before,[p.read_bytes() for p in (project,manifest)])
            info=plistlib.loads((out/'ios/Native/AppInfo.plist').read_bytes());self.assertEqual(doc['name'],info['CFBundleDisplayName'])
            resource=ET.fromstring((out/'android/app/src/main/res/values/native_app.xml').read_text()).find('string').text
            self.assertEqual('"Renamed \\"team\\" & friends \\\\ test"',resource)
            self.assertEqual('@string/native_app_name',ET.fromstring(manifest.read_text()).find('application').get('{http://schemas.android.com/apk/res/android}label'))
            self.assertNotIn('INFOPLIST_KEY_CFBundleDisplayName',project.read_text())

    def test_modified_generated_name_conflicts_without_partial_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);out=root/'native';doc=document();compile_app(root/'app.json',out,document=doc)
            resource=out/'android/app/src/main/res/values/native_app.xml';resource.write_text(resource.read_text()+'<!-- edit -->')
            before=(out/'ios/Native/AppInfo.plist').read_bytes();doc['name']='Changed'
            with self.assertRaises(Conflict):compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,(out/'ios/Native/AppInfo.plist').read_bytes())

    def test_legacy_literal_requires_explicit_binding_on_rename(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);out=root/'native';doc=document();compile_app(root/'app.json',out,document=doc)
            manifest=out/'android/app/src/main/AndroidManifest.xml';manifest.write_text(manifest.read_text().replace('@string/native_app_name','First name'))
            before=manifest.read_bytes();compile_app(root/'app.json',out,document=doc)
            doc['name']='Second name'
            with self.assertRaisesRegex(Diagnostic,'manifest does not follow'):compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,manifest.read_bytes())

    def test_existing_generated_plist_binding_survives_feature_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);out=root/'native';doc=document();compile_app(root/'app.json',out,document=doc)
            project=out/'ios/App.xcodeproj/project.pbxproj';project.write_text(project.read_text().replace('Native/AppInfo.plist','Native/TransportInfo.plist'));before=project.read_bytes()
            doc['name']='Updated name';compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,project.read_bytes());self.assertEqual('Updated name',plistlib.loads((out/'ios/Native/TransportInfo.plist').read_bytes())['CFBundleDisplayName'])
            with self.assertRaisesRegex(Diagnostic,'native build-setting'):compile_app(root/'app.json',out,document=document('$(HOME)'))

    def test_legacy_ios_name_requires_binding_on_rename(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);out=root/'native';doc=document()
            compile_app(root/'app.json',out,document=doc)
            project=out/'ios/App.xcodeproj/project.pbxproj'
            text=project.read_text().replace('GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Native/AppInfo.plist;', 'GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = "First name";')
            self.assertIn('GENERATE_INFOPLIST_FILE = YES;',text)
            project.write_text(text);before=project.read_bytes()
            compile_app(root/'app.json',out,document=doc)
            doc['name']='Second name'
            with self.assertRaisesRegex(Diagnostic,'project does not follow'):
                compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,project.read_bytes())

    def test_mixed_ios_generation_configuration_rejected_before_sync(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);out=root/'native';doc=document()
            compile_app(root/'app.json',out,document=doc)
            project=out/'ios/App.xcodeproj/project.pbxproj'
            project.write_text(project.read_text().replace('GENERATE_INFOPLIST_FILE = NO;', 'GENERATE_INFOPLIST_FILE=YES;',1))
            before=project.read_bytes()
            with self.assertRaisesRegex(Diagnostic,'custom Info.plist configuration'):
                compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,project.read_bytes())
