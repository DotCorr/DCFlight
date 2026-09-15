import copy
import unittest
from dcflight.validate import lower,Diagnostic
from dcflight.registry import Registry
from dcflight.media_ir import MediaBody,MediaRef,PickPhotoEffect
from tests.test_collections import fixture


def media_app():
    data=fixture();data['media']=[{'name':'photo'}]
    data['flowActions'].append({'id':'pick','cases':[{'code':0,'effects':[{'op':'pickPhoto','target':'photo','success':'done','cancel':'done','failure':'done'}]}]})
    data['routes'][0]['body']={'id':'local','type':'localImage','props':{'source':{'media':'photo'},'accessibilityLabel':'Selected image'},'children':[{'id':'loading','type':'text','props':{'text':'Loading'}},{'id':'failed','type':'text','props':{'text':'Unavailable'}}]}
    return data

class MediaIRTests(unittest.TestCase):
    def test_transient_photo_and_binary_request(self):
        data=media_app();request=data['flowActions'][0]['cases'][0]['effects'][0]
        request.update(method='POST',body={'mediaBody':{'media':'photo'}})
        app=lower(data,Registry());self.assertEqual(app.media_states[0].name,'photo')
        self.assertIsInstance(app.routes[0].body.props()['source'],MediaRef)
        self.assertIsInstance(app.flow_actions[0].cases[0].effects[0].body,MediaBody)
        self.assertIsInstance(app.flow_actions[-1].cases[0].effects[0],PickPhotoEffect)
        self.assertEqual(app.flow_actions[-1].cases[0].effects[0].options.max_output_bytes,8388608)
        self.assertNotIn('photo',{s.name for s in app.states})

    def test_invalid_media_inputs_fail_closed(self):
        cases=[lambda d:d['media'][0].update(name='token'),
               lambda d:d['routes'][0]['body']['props'].update(source={'media':'unknown'}),
               lambda d:d['routes'][0]['body']['props'].update(source='/private/image.jpg'),
               lambda d:d['routes'][0]['body'].update(children=[]),
               lambda d:d['flowActions'][-1]['cases'][0]['effects'][0].update(source='camera'),
               lambda d:d['flowActions'][-1]['cases'][0]['effects'][0].update(options={'maxEdge':99999}),
               lambda d:d['flowActions'][-1]['cases'][0]['effects'][0].update(target='token')]
        for mutate in cases:
            data=media_app();mutate(data)
            with self.subTest(mutate=mutate),self.assertRaises(Diagnostic):lower(data,Registry())

    def test_timer_reachability_and_atomic_record_read(self):
        data=media_app();data['state']['clock']=0
        data['flowActions'].extend([
            {'id':'tick','cases':[{'code':0,'effects':[{'op':'clock','target':'clock','failure':'done'},{'op':'invoke','action':'expire'}]}]},
            {'id':'expire','cases':[{'code':0,'effects':[{'op':'clearMedia','target':'photo'}]}]},
            {'id':'selected','cases':[{'code':0,'effects':[{'op':'readCollection','collection':'people','key':{'ref':'selected'},'outputs':{'token':'name'},'success':'done','failure':'done'}]}]},
        ])
        data['timers']=[{'id':'expiry','intervalMs':1000,'action':'tick'}]
        app=lower(data,Registry());self.assertEqual(app.timers[0].interval_ms,1000)
        data['flowActions'][-2]['cases'][0]['effects']=[{'op':'invoke','action':'load'}]
        with self.assertRaisesRegex(Diagnostic,'Timer flow'):lower(data,Registry())
        data['flowActions'][-2]['cases'][0]['effects']=[{'op':'invoke','action':'pick'}]
        with self.assertRaisesRegex(Diagnostic,'Timer flow'):lower(data,Registry())

    def test_remote_image_requires_auth_and_scoped_fields(self):
        data=fixture();row=data['routes'][0]['body']['children'][0]
        row.update(type='remoteImage',props={'path':['/media/',{'field':{'collection':'people','name':'id'}}],'bearer':{'ref':'token'},'accessibilityLabel':'Private photo'},children=[{'id':'loading','type':'text','props':{'text':'Loading'}},{'id':'failed','type':'text','props':{'text':'Failed'}}])
        app=lower(data,Registry());self.assertEqual(app.routes[0].body.children[0].props()['path'].parts[1].field,'id')
        row['props']['bearer']={'ref':'missing'}
        with self.assertRaises(Diagnostic):lower(data,Registry())
