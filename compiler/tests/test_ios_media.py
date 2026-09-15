import dataclasses
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from dcflight.ir import Node,Literal,ScalarType,MediaRef,Reference,State
from dcflight.media_ir import MediaState,PhotoOptions,PickPhotoEffect,ClearMediaEffect,MediaBody
from dcflight.flow_ir import FlowAction,FlowCase,RequestEffect,Transport,PathTemplate,ClockEffect,ReadCollectionEffect,Timer,ResponseOutput
from dcflight.backends.ios_routed import generate
from dcflight.registry import Registry
from dcflight.collection_ir import Collection,CollectionField
from test_ios_routed import fixture,text,node


def media_fixture():
    app=fixture()
    local=Node('preview','localImage',(('source',MediaRef('photo')),('fit',text('fit')),('accessibilityLabel',text('Authored preview'))),(node('empty','text',{'text':'Select a photo'}),node('error','text',{'text':'Authored error'})))
    actions=(FlowAction('pick',None,(),(FlowCase(0,(PickPhotoEffect('photo',PhotoOptions(),'done','done','done'),)),)),FlowAction('done',None,(),(FlowCase(0,()),)),FlowAction('clear',None,(),(FlowCase(0,(ClearMediaEffect('photo'),)),)),FlowAction('upload',None,(),(FlowCase(0,(RequestEffect('upload','POST','/v1/media',MediaBody(MediaRef('photo')),None,(),'done','done'),)),)))
    remote=Node('private','remoteImage',(('path',PathTemplate((text('/media/'),Reference('imageId',ScalarType.STRING)))),('bearer',Reference('token',ScalarType.STRING)),('maxBytes',Literal(1000000,ScalarType.INT)),('maxDecodedPixels',Literal(1000000,ScalarType.INT)),('maxEdge',Literal(1000,ScalarType.INT)),('fit',text('fit')),('accessibilityLabel',text('Private photo'))),(node('remoteLoading','text',{'text':'Loading authored'}),node('remoteFailure','text',{'text':'Failed authored'})))
    actions=(*actions,FlowAction('clock',None,(),(FlowCase(0,(ClockEffect('now','done'),)),)),FlowAction('lookup',None,(),(FlowCase(0,(ReadCollectionEffect('records',Reference('imageId',ScalarType.STRING),(ResponseOutput('token',('name',)),),'done','done'),)),)))
    app=dataclasses.replace(app,states=(State('token',text('')),State('imageId',text('')),State('now',Literal(0,ScalarType.INT))),collections=(Collection('records','id',(CollectionField('id',ScalarType.STRING),CollectionField('name',ScalarType.STRING))),),timers=(Timer('clockTimer',1000,'clock'),),routes=(app.routes[0],dataclasses.replace(app.routes[1],body=remote),*app.routes[2:]))
    return dataclasses.replace(app,routes=(dataclasses.replace(app.routes[0],body=local),*app.routes[1:]),media_states=(MediaState('photo'),),flow_actions=actions,transport=Transport('https://example.com'))

class IOSMediaTests(unittest.TestCase):
    def test_typed_media_is_transient_and_has_authored_callbacks(self):
        files=generate(media_fixture(),Registry());model=files['ios/App/Generated/AppModel.swift'].content
        self.assertIn('nativeTimers.forEach { $0.cancel() }',model)
        self.assertIn('Date().timeIntervalSince1970.rounded(.down)',model)
        self.assertIn('selectedOutput0 = selected.f_name',model)
        self.assertIn('@Published var m_photo: NativePreparedMedia?',model)
        self.assertIn('case .cancelled: self.f_done(navigate)',model)
        self.assertIn('generation == self.nativePhotoGeneration',model)
        self.assertIn('rawBody:requestMedia',model)
        self.assertIn('guard let requestMedia = self.m_photo?.data',model)
        self.assertIn('nativePhotoTarget == "photo"',model)
        self.assertIn('NativePhotoPresenter(request: model.nativePhotoRequest)',files['ios/App/Generated/RootView.swift'].content)
        self.assertIn('NativeURLComponent.encode(String(model.s_imageId))',files['ios/App/Generated/Nodes/n_private.swift'].content)
        self.assertIn('label: "Authored preview"',files['ios/App/Generated/Nodes/n_preview.swift'].content)
        native=files['ios/App/Generated/NativeMedia.swift'].content
        for forbidden in ('SocialSession','/v1/media','Choose a photo','UserDefaults','base64EncodedString'):self.assertNotIn(forbidden,native)
        self.assertIn('maximum+1',native)
        self.assertIn('CGImageSourceGetCount(source)==1',native)
        self.assertIn('loaded.identity==identity',native)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('xcrun'),'iOS SDK required')
    def test_generated_media_compiles_against_native_ios_sdk(self):
        files=generate(media_fixture(),Registry())
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for key,artifact in files.items():
                if key.endswith('.swift') and '/User/' not in key:
                    path=Path(directory)/Path(key).name;path.write_text(artifact.content);paths.append(str(path))
            result=subprocess.run(['xcrun','swiftc','-typecheck','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths],capture_output=True,text=True,timeout=120)
            self.assertEqual(result.returncode,0,result.stderr)
