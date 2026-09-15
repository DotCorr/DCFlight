import copy
import json
import plistlib
import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
from dcflight.compiler import compile_app
from dcflight.validate import Diagnostic
from dcflight.sync import Conflict

def doc():
    return {'version':2,'id':'com.example.config','name':'Configuration',
        'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},
        'routes':[{'id':'home','title':'Home','body':{'id':'text','type':'text','props':{'text':'Hello'}}}],
        'nativeConfiguration':{'ios':{'infoPlist':{'NSMicrophoneUsageDescription':{'type':'string','value':'Record audio.'},
            'CFBundleURLTypes':{'type':'array','value':[{'type':'dictionary','value':{'CFBundleURLSchemes':{'type':'array','value':[{'type':'string','value':'example'}]}}}]}},
            'entitlements':{'com.apple.developer.associated-domains':{'type':'array','value':[{'type':'string','value':'applinks:example.com'}]}}},
            'android':{'manifest':{'tag':'manifest','children':[
                {'tag':'uses-permission','attributes':{'android:name':'android.permission.RECORD_AUDIO'}},
                {'tag':'uses-feature','attributes':{'android:name':'android.hardware.microphone','android:required':'false'}},
                {'tag':'queries','children':[{'tag':'package','attributes':{'android:name':'com.example.other'}}]},
                {'tag':'application','children':[{'tag':'meta-data','attributes':{'android:name':'sample.key','android:value':'hello & native'}}]}]}}}}

class NativeConfigurationGenerationTests(unittest.TestCase):
    def test_native_files_bindings_and_edit_regeneration(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'native';data=doc();source=Path(tmp)/'app.json'
            compile_app(source,out,document=data)
            info=plistlib.loads((out/'ios/Native/AppInfo.plist').read_bytes())
            self.assertEqual('Record audio.',info['NSMicrophoneUsageDescription'])
            self.assertEqual(['example'],info['CFBundleURLTypes'][0]['CFBundleURLSchemes'])
            project=out/'ios/App.xcodeproj/project.pbxproj';manifest=out/'android/app/src/main/AndroidManifest.xml'
            self.assertIn('CODE_SIGN_ENTITLEMENTS = Native/App.entitlements;',project.read_text())
            before=(project.read_bytes(),manifest.read_bytes())
            for variant in ('debug','release'):
                xml=ET.fromstring((out/f'android/app/src/{variant}/AndroidManifest.xml').read_text())
                self.assertIsNotNone(xml.find('queries/package'))
            data['nativeConfiguration']['ios']['infoPlist']['NSMicrophoneUsageDescription']['value']='Updated purpose.'
            data['nativeConfiguration']['ios']['entitlements']={}
            data['nativeConfiguration']['android']['manifest']['children']=[]
            compile_app(source,out,document=data)
            self.assertEqual(before,(project.read_bytes(),manifest.read_bytes()))
            self.assertEqual({},plistlib.loads((out/'ios/Native/App.entitlements').read_bytes()))
            self.assertIsNone(ET.fromstring((out/'android/app/src/debug/AndroidManifest.xml').read_text()).find('uses-permission'))
            del data['nativeConfiguration'];compile_app(source,out,document=data)
            self.assertTrue((out/'ios/Native/App.entitlements').exists())
            self.assertNotIn('NSMicrophoneUsageDescription',plistlib.loads((out/'ios/Native/AppInfo.plist').read_bytes()))

    def test_shared_permissions_update_in_generated_overlays(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'native';data=doc();source=Path(tmp)/'app.json'
            compile_app(source,out,document=data);manifest=out/'android/app/src/main/AndroidManifest.xml';before=manifest.read_bytes()
            data.update(state={'permission':0},permissionDescriptions={'camera':'Take photos.'},flowActions=[{'id':'done','cases':[{'code':0,'effects':[]}]},{'id':'permit','cases':[{'code':0,'effects':[{'op':'permission','capability':'camera','statusTarget':'permission','success':'done','failure':'done'}]}]}])
            compile_app(source,out,document=data)
            self.assertEqual(before,manifest.read_bytes())
            self.assertIn('android.permission.CAMERA',(out/'android/app/src/debug/AndroidManifest.xml').read_text())
            self.assertEqual('Take photos.',plistlib.loads((out/'ios/Native/AppInfo.plist').read_bytes())['NSCameraUsageDescription'])

    def test_user_overlay_conflict_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'native';overlay=out/'android/app/src/debug/AndroidManifest.xml';overlay.parent.mkdir(parents=True)
            overlay.write_text('<manifest><!-- user --> </manifest>')
            with self.assertRaises(Conflict):compile_app(Path(tmp)/'app.json',out,document=doc())
            self.assertEqual('<manifest><!-- user --> </manifest>',overlay.read_text())

    def test_identity_and_existing_project_binding_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'app.json';out=Path(tmp)/'native';data=doc()
            data['nativeConfiguration']['ios']['infoPlist']['CFBundleIdentifier']={'type':'string','value':'other.id'}
            with self.assertRaisesRegex(Diagnostic,'identity'):compile_app(source,out,document=data)
            data=doc();del data['nativeConfiguration'];compile_app(source,out,document=data)
            with self.assertRaisesRegex(Diagnostic,'CODE_SIGN_ENTITLEMENTS'):compile_app(source,out,document=doc())

    def test_custom_source_set_and_stale_overlay_removal(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'app.json';out=Path(tmp)/'native';data=doc()
            data['nativeConfiguration']['android']['sourceSets']=['debug','release','staging']
            compile_app(source,out,document=data)
            self.assertTrue((out/'android/app/src/staging/AndroidManifest.xml').exists())
            data['nativeConfiguration']['android']['sourceSets']=['debug','release']
            compile_app(source,out,document=data)
            self.assertFalse((out/'android/app/src/staging/AndroidManifest.xml').exists())
