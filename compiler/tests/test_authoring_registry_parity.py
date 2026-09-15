import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated
from dcflight.registry import Registry
from dcflight.validate import lower, Diagnostic
from dcflight.backends.android_routed import AndroidRouted as Android
from dcflight.backends.ios_routed import IOS
from dcflight.compiler import compile_app

ROOT = Path(__file__).resolve().parents[1]

class AuthoringRegistryParityTests(unittest.TestCase):
    def test_every_registry_capability_has_a_named_dart_node(self):
        source=(ROOT/'authoring/lib/dcflight.dart').read_text()
        named=set(re.findall(r"super\(\s*type:\s*'([^']+)'", source))
        self.assertEqual(set(),set(Registry().entries)-named)

    @unittest.skipUnless(shutil.which('dart'), 'Dart required')
    def test_named_nodes_reach_both_routed_backends(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'app.dart'
            path.write_text("import 'package:dcflight_authoring/dcflight.dart'; App buildApp()=>RoutedApp(id:'com.example.parity',name:'Parity',state:{'count':7},nativeOperations:[],sdkCatalog:'catalog.sqlite',root:NavigationStack(id:'root',initialRoute:'home'),screens:[Screen(id:'home',title:'Home',body:Column(id:'body',children:[Counter.bind(Ref<int>(name:'count'),id:'count'),Divider(id:'divider'),Progress(id:'progress'),NativeView('badge',id:'badge')]))]);")
            doc=load_evaluated(path,shutil.which('dart'))
            self.assertEqual('catalog.sqlite',doc['sdkCatalog'])
            self.assertEqual(['counter','divider','progress','native'],[v['type'] for v in doc['routes'][0]['body']['children']])
            app=lower(doc,Registry())
            android='\n'.join(v.content for v in Android().generate(app,Registry()).values())
            ios='\n'.join(v.content for v in IOS().generate(app,Registry()).values())
            for symbol in ('HorizontalDivider','CircularProgressIndicator','UserViews.v_badge(context,model)'):
                self.assertIn(symbol,android)
            for symbol in ('Divider()','ProgressView()','UserViews.v_badge(model: model)'):
                self.assertIn(symbol,ios)

    def test_new_permission_cannot_silently_leave_existing_manifest_stale(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);out=root/'native'
            doc={'version':2,'id':'com.example.permissions','name':'Permissions','root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'Home','body':{'id':'text','type':'text','props':{'text':'Hello'}}}]}
            compile_app(root/'app.json',out,document=doc)
            manifest=out/'android/app/src/main/AndroidManifest.xml';before=manifest.read_bytes()
            doc['state']={'permission':0};doc['permissionDescriptions']={'camera':'Take photos.'};doc['flowActions']=[{'id':'done','cases':[{'code':0,'effects':[]}]},{'id':'permit','cases':[{'code':0,'effects':[{'op':'permission','capability':'camera','statusTarget':'permission','success':'done','failure':'done'}]}]}]
            with self.assertRaisesRegex(Diagnostic,'required permission android.permission.CAMERA'):
                compile_app(root/'app.json',out,document=doc)
            self.assertEqual(before,manifest.read_bytes())
            manifest.write_text(before.decode().replace('<application ', '<uses-permission android:name="android.permission.CAMERA"/><application '))
            compile_app(root/'app.json',out,document=doc)
