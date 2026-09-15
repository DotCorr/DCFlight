import unittest
from dcflight.validate import lower,Diagnostic
from dcflight.registry import Registry
from dcflight.device_ir import CameraResource,MapRegion,PermissionEffect
from tests.test_media_ir import media_app


def camera_app():
    data=media_app();data['cameraResources']=[{'id':'camera'}];data['permissionDescriptions']={'camera':'Take a photo.'}
    data['state'].update(active=False,ready=False,permission=0)
    data['routes'][0]['body'].update(type='cameraPreview',props={'resource':'camera','active':{'ref':'active'},'ready':{'ref':'ready'},'accessibilityLabel':'Camera'})
    data['flowActions'].append({'id':'permit','cases':[{'code':0,'effects':[{'op':'permission','capability':'camera','statusTarget':'permission','success':'done','failure':'done'}]}]})
    return data

class DeviceIRTests(unittest.TestCase):
    def test_explicit_camera_resource_permission_and_binding(self):
        app=lower(camera_app(),Registry())
        self.assertEqual(app.camera_resources,(CameraResource('camera'),))
        self.assertIsInstance(app.flow_actions[-1].cases[0].effects[0],PermissionEffect)
        self.assertEqual(app.routes[0].body.props()['ready'].name,'ready')

    def test_unknown_camera_and_permission_missing_rejected(self):
        for mutate in [lambda d:d['permissionDescriptions'].clear(),lambda d:d['routes'][0]['body']['props'].update(resource='unknown'),lambda d:d['routes'][0]['body']['props'].update(ready={'ref':'active'})]:
            data=camera_app();mutate(data)
            with self.assertRaises(Diagnostic):lower(data,Registry())

    def test_map_scoped_native_annotation_and_bounds(self):
        data=media_app();data['modules']=[{'id':'maplibre','platform':'android','lock':'module.lock.json'}]
        data['mapConfig']={'androidModule':'maplibre','styleUrl':'https://example.com/style.json','attribution':'Provider attribution'}
        data['collections'][0]['fields'].update(latitude={'type':'int'},longitude={'type':'int'})
        children=data['routes'][0]['body']['children']
        data['routes'][0]['body'].update(type='nativeMap',props={'collection':'people','latitudeField':'latitude','longitudeField':'longitude','titleField':'name','region':{'latitudeE6':0,'longitudeE6':0,'latitudeSpanE6':1000000,'longitudeSpanE6':1000000}},children=[{'id':'annotation','type':'text','props':{'text':{'field':{'collection':'people','name':'name'}}}},*children])
        app=lower(data,Registry());self.assertIsInstance(app.routes[0].body.props()['region'],MapRegion)
        self.assertEqual(app.routes[0].body.children[0].props()['text'].collection,'people')
        data['routes'][0]['body']['props']['region']['longitudeE6']=180000000
        with self.assertRaisesRegex(Diagnostic,'antimeridian'):lower(data,Registry())
        data['routes'][0]['body']['props']['region']['longitudeE6']=0
        data['routes'][0]['body']['children'][0].update(type='button',action='done')
        with self.assertRaisesRegex(Diagnostic,'annotation'):lower(data,Registry())
