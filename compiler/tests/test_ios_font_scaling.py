import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from dcflight.ir import Node,Literal,ScalarType,Style,Motion
from dcflight.backends.ios_presentation import render,render_button


def sample():
    text=Node('text','text',(('text',Literal('MMMM',ScalarType.STRING)),),(),style=Style(font_size=40))
    heading=render(text,'Text("MMMM")')
    parent=render(Node('parent','column',(),(),style=Style(font_size=80)), '',children_source='ScaledText()')
    button=render_button(Node('button','button',text.properties,(),style=Style(font_size=40,padding=4),motion=Motion('fade',100)), '{}')
    field=render(Node('field','textField',(),(),style=Style(font_size=40)), 'TextField("Prompt",text:.constant("MMMM")).textFieldStyle(.plain)')
    secure=render(Node('secure','secureField',(),(),style=Style(font_size=40)), 'SecureField("Prompt",text:.constant("MMMM")).textFieldStyle(.plain)')
    return dict(ScaledText=heading,ParentText=parent,ScaledButton=button,ScaledField=field,ScaledSecure=secure)


def swift_source():
    source='import SwiftUI\nimport UIKit\n'
    for name,presentation in sample().items():
        source+='struct '+name+': View {\n'+presentation.declarations+'var body: some View {\n'+presentation.body+'\n}\n}\n'
    return source+'''
@MainActor func measure<V:View>(_ view:V,_ size:DynamicTypeSize)->CGSize {
 let host=UIHostingController(rootView:view.environment(\\.dynamicTypeSize,size).fixedSize())
 return host.sizeThatFits(in:CGSize(width:10000,height:10000))
}
@main struct Verify {
 @MainActor static func main() {
  let baseline=measure(Text("MMMM").font(.system(size:40)),.large)
  let normal=measure(ScaledText(),.large)
  let accessible=measure(ScaledText(),.accessibility3)
  let nested=measure(ParentText(),.accessibility3)
  precondition(normal.height>0 && abs(normal.height-baseline.height)<0.6 && abs(normal.width-baseline.width)<0.6)
  precondition(accessible.height>normal.height*1.5 && accessible.width>normal.width*1.5)
  precondition(abs(nested.height-accessible.height)<0.6 && abs(nested.width-accessible.width)<0.6)
  let button=measure(ScaledButton(),.large),largeButton=measure(ScaledButton(),.accessibility3)
  let field=measure(ScaledField(),.large),largeField=measure(ScaledField(),.accessibility3)
  let secure=measure(ScaledSecure(),.large),largeSecure=measure(ScaledSecure(),.accessibility3)
  precondition(largeButton.height>button.height*1.5)
  precondition(largeField.height>field.height*1.5 && largeSecure.height>secure.height*1.5)
  let report:[String:Any]=["status":"passed","defaultFontPoints":40,
   "nativeFixed40Height":baseline.height,"normalTextHeight":normal.height,"accessibleTextHeight":accessible.height,
   "normalTextWidth":normal.width,"accessibleTextWidth":accessible.width,
   "nestedAccessibleHeight":nested.height,"buttonHeights":[button.height,largeButton.height],
   "fieldHeights":[field.height,largeField.height],"secureHeights":[secure.height,largeSecure.height],
   "defaultDynamicType":"large","accessibleDynamicType":"accessibility3","offscreen":true,"productUIInspected":false]
  let data=try! JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]);print(String(data:data,encoding:.utf8)!)
 }
}
'''


class IOSFontScalingTests(unittest.TestCase):
    def test_metric_and_button_motion_declarations_preserved(self):
        values=sample()
        for name,value in values.items():
            self.assertIn('@ScaledMetric(relativeTo: .body)',value.declarations,name)
            self.assertIn('size: authoredFontSize',value.body,name)
        self.assertIn('private var authoredFontSize: Double = 40',values['ScaledText'].declarations)
        self.assertIn('accessibilityReduceMotion',values['ScaledButton'].declarations)
        self.assertIn('presentationAppeared',values['ScaledButton'].declarations)

    @unittest.skipUnless(shutil.which('xcrun') and os.environ.get('DCFLIGHT_IOS_SIMULATOR'),'Set DCFLIGHT_IOS_SIMULATOR for offscreen native measurements')
    def test_native_default_accessibility_and_nested_metrics(self):
        simulator=os.environ['DCFLIGHT_IOS_SIMULATOR']
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'Measurement.swift';source.write_text(swift_source())
            bundle=root/'FontMeasurement.app';bundle.mkdir();binary=bundle/'FontMeasurement'
            sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
            compiled=subprocess.run(['xcrun','swiftc','-parse-as-library','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',str(source),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(compiled.returncode,0,compiled.stderr)
            (bundle/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.dotcorr.test.fontmeasurement','CFBundleExecutable':'FontMeasurement','CFBundleName':'FontMeasurement','CFBundlePackageType':'APPL'}))
            subprocess.run(['codesign','--force','--sign','-',str(bundle)],check=True,capture_output=True)
            result=subprocess.run(['xcrun','simctl','spawn',simulator,str(binary)],capture_output=True,text=True,timeout=45)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            report=json.loads(result.stdout.strip().splitlines()[-1]);self.assertEqual(report['status'],'passed')
            if os.environ.get('DCFLIGHT_FONT_REPORT'):
                import hashlib
                report.update(simulator=simulator,sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),binarySha256=hashlib.sha256(binary.read_bytes()).hexdigest())
                path=Path(os.environ['DCFLIGHT_FONT_REPORT']);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps(report,sort_keys=True))
