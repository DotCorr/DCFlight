import dataclasses
import plistlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from dcflight.ir import Node,Literal,ScalarType,State,Reference
from dcflight.collection_ir import Collection,CollectionField,FieldReference
from dcflight.device_ir import CameraResource,PermissionEffect,CameraFacingEffect,CapturePhotoEffect,LocationEffect,MapRegion,MapConfig
from dcflight.media_ir import PhotoOptions
from dcflight.flow_ir import FlowAction,FlowCase
from dcflight.backends.ios_routed import generate
from dcflight.registry import Registry
from test_ios_media import media_fixture
from test_ios_routed import node,text


def device_fixture():
    app=media_fixture()
    camera=Node('cameraView','cameraPreview',(('resource',text('lens')),('active',Reference('cameraActive',ScalarType.BOOL)),('ready',Reference('cameraReady',ScalarType.BOOL)),('fit',text('fill')),('accessibilityLabel',text('Authored camera'))),(node('cameraLoading','text',{'text':'Waiting authored'}),node('cameraFailure','text',{'text':'Unavailable authored'})))
    annotation=Node('marker','text',(('text',FieldReference('places','name',ScalarType.STRING)),),())
    mapnode=Node('mapView','nativeMap',(('collection',text('places')),('latitudeField',text('latitude')),('longitudeField',text('longitude')),('titleField',text('name')),('region',MapRegion(52000000,4000000,1000000,1000000))),(annotation,node('mapLoading','text',{'text':'Loading map authored'}),node('mapFailure','text',{'text':'Map unavailable authored'})))
    collection=Collection('places','id',(CollectionField('id',ScalarType.STRING),CollectionField('name',ScalarType.STRING),CollectionField('latitude',ScalarType.INT),CollectionField('longitude',ScalarType.INT)))
    effects=(('permission',PermissionEffect('camera','permission','done','done')),('locationPermission',PermissionEffect('location','permission','done','done')),('face',CameraFacingEffect('lens','front','done','done')),('capture',CapturePhotoEffect('lens','photo',PhotoOptions(),'done','done','done')),('locate',LocationEffect('latitude','longitude','accuracy','done','done','done')))
    states=(*app.states,State('cameraActive',Literal(False,ScalarType.BOOL)),State('cameraReady',Literal(False,ScalarType.BOOL)),*(State(name,Literal(0,ScalarType.INT)) for name in ['permission','latitude','longitude','accuracy']))
    return dataclasses.replace(app,states=states,collections=(*app.collections,collection),camera_resources=(CameraResource('lens'),),permission_descriptions=(('camera','Authored camera purpose'),('location','Authored location purpose')),map_config=MapConfig('maps','https://example.com/style.json','Explicit provider attribution'),routes=(dataclasses.replace(app.routes[0],body=Node('deviceLayout','column',(),(camera,mapnode))),*app.routes[1:]),flow_actions=(*app.flow_actions,*(FlowAction(name,None,(),(FlowCase(0,(effect,)),)) for name,effect in effects)))

class IOSDeviceTests(unittest.TestCase):
    def test_permission_copy_and_native_surfaces_are_shared(self):
        files=generate(device_fixture(),Registry());model=files['ios/App/Generated/AppModel.swift'].content
        info=plistlib.loads(files['ios/Native/TransportInfo.plist'].content.encode())
        self.assertEqual(info['NSCameraUsageDescription'],'Authored camera purpose')
        self.assertEqual(info['NSLocationWhenInUseUsageDescription'],'Authored location purpose')
        self.assertIn('INFOPLIST_FILE = Native/TransportInfo.plist',files['ios/App.xcodeproj/project.pbxproj'].content)
        self.assertIn('self.s_latitude=coordinate.latitude;self.s_longitude=coordinate.longitude;self.s_accuracy=coordinate.accuracy',model)
        self.assertIn('NativePermission.camera()',model)
        self.assertIn('nativeDeviceGeneration &+= 1',model)
        self.assertIn('nativeCancelAcquisition',model)
        mapview=files['ios/App/Generated/Nodes/n_mapView.swift'].content
        self.assertIn('n_marker(model: model, item: item).environmentObject(router)',mapview)
        self.assertIn('latitude: 52000000, longitude: 4000000',mapview)
        self.assertIn('Text(item.f_name)',files['ios/App/Generated/Nodes/n_marker.swift'].content)
        helper=files['ios/App/Generated/NativeDevice.swift'].content
        self.assertIn('self.captureID==photo.resolvedSettings.uniqueID',helper)
        self.assertIn('camera.setActive(false);ready=false',helper)
        self.assertIn('guard manager === samplingManager',helper)
        self.assertIn('samplingManager?.delegate=nil',helper)
        self.assertIn('NativeCoordinate.from(location,notBefore:started)',helper)
        self.assertNotIn('Request sent',helper)
        self.assertNotIn('https://example.com',helper)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('xcrun'),'iOS SDK required')
    def test_generated_device_sources_typecheck_against_sdk(self):
        files=generate(device_fixture(),Registry());sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for key,artifact in files.items():
                if key.endswith('.swift') and '/User/' not in key:
                    path=Path(directory)/Path(key).name;path.write_text(artifact.content);paths.append(str(path))
            result=subprocess.run(['xcrun','swiftc','-typecheck','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths],capture_output=True,text=True,timeout=120)
            self.assertEqual(result.returncode,0,result.stderr)
