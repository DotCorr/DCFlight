import dataclasses
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from dcflight.navigation_ir import TitleDisplay, schema
from dcflight.registry import Registry
from dcflight.validate import lower
from dcflight.backends.ios_routed import generate
from dcflight.backends.android_routed import AndroidRouted
from dcflight.evaluated_frontend import load_evaluated
from test_navigation_ir import fixture


class TitleDisplayTests(unittest.TestCase):
    def test_default_compact_and_authored_large_reach_both_targets(self):
        data=fixture();data['routes'][1]['titleDisplay']='large'
        app=lower(data,Registry())
        self.assertEqual(app.routes[0].title_display,TitleDisplay.COMPACT)
        self.assertEqual(app.routes[1].title_display,TitleDisplay.LARGE)
        swift=generate(app,Registry())['ios/App/Generated/RouteContent.swift'].content
        kotlin='\n'.join(a.content for a in AndroidRouted().generate(app,Registry()).values() if isinstance(a.content,str))
        self.assertIn('.navigationTitle("Home").navigationBarTitleDisplayMode(.inline)',swift)
        self.assertIn('.navigationTitle("Settings").navigationBarTitleDisplayMode(.large)',swift)
        self.assertIn('TopAppBar(title={Text("Home")}',kotlin)
        self.assertIn('LargeTopAppBar(title={Text("Settings")}',kotlin)
        changed=dataclasses.replace(app,routes=(app.routes[0],dataclasses.replace(app.routes[1],title_display=TitleDisplay.COMPACT)))
        self.assertNotEqual(generate(changed,Registry()),generate(app,Registry()))
        self.assertNotEqual(AndroidRouted().generate(changed,Registry()),AndroidRouted().generate(app,Registry()))

    def test_invalid_modes_and_empty_large_titles_fail(self):
        for mode in ('automatic','native','',True,None,1):
            data=fixture();data['routes'][0]['titleDisplay']=mode
            with self.subTest(mode=mode),self.assertRaises(ValueError):lower(data,Registry())
        data=fixture();data['routes'][0].update(title='',titleDisplay='large')
        with self.assertRaisesRegex(ValueError,'nonempty'):lower(data,Registry())
        route=lower(fixture(),Registry()).routes[0]
        with self.assertRaises(ValueError):dataclasses.replace(route,title_display='large')
        with self.assertRaises(ValueError):dataclasses.replace(route,title='',title_display=TitleDisplay.LARGE)

    @unittest.skipUnless(shutil.which('dart'),'Dart SDK required')
    def test_evaluated_dart_has_typed_title_setting(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'app.dart'
            source.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp() => App(version:2,id:'com.example.titles',name:'Titles',
 root:NavigationStack(id:'root',initialRoute:'home'),routes:[
 Screen(id:'home',title:'Hello',titleDisplay:TitleDisplay.large,body:Text('Body',id:'body'))]);
""")
            doc=load_evaluated(source,shutil.which('dart'))
            self.assertEqual(doc['routes'][0]['titleDisplay'],'large')
            self.assertEqual(lower(doc,Registry()).routes[0].title_display,TitleDisplay.LARGE)

    @unittest.skipUnless(shutil.which('xcrun'),'iOS SDK required')
    def test_both_native_swift_title_modes_typecheck(self):
        data=fixture();data['routes'][1]['titleDisplay']='large';files=generate(lower(data,Registry()),Registry())
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for key,artifact in files.items():
                if key.endswith('.swift') and '/User/' not in key:
                    path=Path(directory)/Path(key).name;path.write_text(artifact.content);paths.append(str(path))
            result=subprocess.run(['xcrun','swiftc','-typecheck','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths],capture_output=True,text=True,timeout=120)
            self.assertEqual(result.returncode,0,result.stderr)
