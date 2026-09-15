import dataclasses
import plistlib
import unittest
import shutil
import subprocess
import tempfile
from pathlib import Path
from dcflight.backends.ios_social import artifacts, render
from dcflight.registry import Registry
from dcflight.shared_logic import c_alias
from dcflight.validate import lower
from test_social_contract import app


class IOSSocialTests(unittest.TestCase):
    def setUp(self):
        self.app=lower(app(),Registry())
        self.files=artifacts(self.app)

    def test_required_native_policy_abi(self):
        source=self.files['App/Generated/Social/Configuration.swift']
        for function in self.app.logic.functions:
            self.assertIn(c_alias(self.app,function.name)+'(',source)
        self.assertNotIn('8388608',source)
        self.assertNotIn('86400 - age',source)
        with self.assertRaisesRegex(ValueError,'Missing required'):
            artifacts(dataclasses.replace(self.app,logic=None))

    def test_network_exceptions_are_scoped(self):
        info=plistlib.loads(self.files['Native/ServiceInfo.plist'].encode())
        self.assertEqual(info['NSAppTransportSecurity'],{'NSAllowsLocalNetworking':True})
        secure=dataclasses.replace(self.app,service=dataclasses.replace(self.app.service,base_url='https://service.example',development=False))
        self.assertNotIn('NSAppTransportSecurity',plistlib.loads(artifacts(secure)['Native/ServiceInfo.plist'].encode()))

    def test_native_screens_and_privacy_lifecycle(self):
        messaging=self.files['App/Generated/Social/Messaging.swift']
        self.assertIn('Story expired',messaging)
        self.assertIn('TimelineView(.periodic(from:.now,by:1))',messaging)
        camera=self.files['App/Generated/Social/Camera.swift']
        self.assertIn('CGImageSourceCreateThumbnailAtIndex',camera)
        self.assertIn('AVCapturePhotoOutput()',camera)
        service=self.files['App/Generated/Social/Service.swift']
        self.assertIn('requestToken != token',service)
        self.assertIn('previous token may remain valid',service)
        self.assertIn('kSecAttrAccessibleWhenUnlockedThisDeviceOnly',service)
        for source in self.files.values():
            self.assertNotIn('WKWebView',source)
            self.assertNotIn('import dcflight',source)

    def test_tabs_come_from_shared_input(self):
        source,_=render(self.app.root,self.app)
        self.assertIn('Label("You", systemImage: "person")',source)
        self.assertIn('.tag("profileTab")',source)
        self.assertIn('Tab("You", systemImage: "person", value: "profileTab")',source)
        self.assertIn('.accessibilityIdentifier("tab.profileTab")',source)
        self.assertIn('if #available(iOS 18.0, *)',source)

    @unittest.skipUnless(shutil.which('swift'), 'Swift toolchain required')
    def test_native_field_validation_does_not_echo_inputs(self):
        source=self.files['App/Generated/Social/Service.swift']
        helper=source[source.index('enum ServiceValidation'):source.index('struct ServiceFailure')]
        checks='\nprecondition(ServiceValidation.credentials(username:"ios.qa",password:"abcdefghijkl",displayName:"QA")!.contains("Username"))\nprecondition(ServiceValidation.credentials(username:"ios_qa",password:"abcdefghijkl",displayName:"QA")==nil)\nprecondition(ServiceValidation.message([["loc":["body","password"],"msg":"Too short","input":"SECRET"]])=="Password: Too short")\nprecondition(ServiceValidation.message([["loc":["body","unknown"],"msg":"SECRET"]])==nil)\n'
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'validation.swift';path.write_text('import Foundation\n'+helper+checks)
            result=subprocess.run(['swift',str(path)],capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)
