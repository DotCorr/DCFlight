import copy
import unittest
from dcflight.registry import Registry
from dcflight.validate import lower


def app():
    return {'version':1,'id':'com.example.snap','name':'Snap','service':{'baseUrl':'http://localhost:8765','development':True},
            'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[
                {'name':name,'parameters':['uint32']*count,'returns':'uint32'} for name,count in
                [('canSendMessage',2),('canUploadPhoto',1),('remainingStorySeconds',1),('shouldPublishLocation',2)]]},
            'root':{'id':'tabs','type':'tabs','props':{},'children':[{'id':'profileTab','type':'tab','props':{'title':'You','icon':'user'},
                    'children':[{'id':'profile','type':'account','props':{}}]}]}}


class SocialContractTests(unittest.TestCase):
    def test_policies_required_and_exact_abi(self):
        data=app();self.assertEqual(lower(data,Registry()).logic.functions[0].returns.value,'uint32')
        for mutate in [lambda d:d.pop('logic'),lambda d:d['logic']['functions'].pop(),lambda d:d['logic']['functions'][0].update(returns='bool')]:
            changed=copy.deepcopy(data);mutate(changed)
            with self.assertRaisesRegex(ValueError,'social'):lower(changed,Registry())

    def test_loopback_only_explicit_development(self):
        for service in [{'baseUrl':'http://localhost:8765'}, {'baseUrl':'http://example.com','development':True}, {'baseUrl':'https://user:pass@example.com'}]:
            data=app();data['service']=service
            with self.assertRaises(ValueError):lower(data,Registry())

    def test_account_controls_cannot_be_removed(self):
        data=app();data['root']['children'][0]['children'][0]['type']='camera'
        with self.assertRaisesRegex(ValueError,'account controls'):lower(data,Registry())

    def test_ignored_social_customizations_fail_closed(self):
        for field,value in [('style',{'padding':8}),('motion',{'kind':'fade','durationMs':100}),('visibleWhen',False)]:
            data=app();data['root'][field]=value
            with self.assertRaisesRegex(ValueError,'customization'):lower(data,Registry())
        data=app();data['state']={'label':'Hello'}
        with self.assertRaisesRegex(ValueError,'state/actions'):lower(data,Registry())

    def test_generic_tabs_and_theme_fail_closed(self):
        generic={'version':1,'id':'com.example.app','name':'App','root':{'id':'txt','type':'text','props':{'text':'Hello'}}}
        themed=copy.deepcopy(generic);themed['theme']={'padding':20}
        with self.assertRaisesRegex(ValueError,'theme requires'):lower(themed,Registry())
        data=app();data.pop('service');data.pop('logic');data['root']['children'][0]['children'][0]=generic['root']
        with self.assertRaisesRegex(ValueError,'generic tabs'):lower(data,Registry())

    def test_inapplicable_styles_rejected(self):
        for style in [{'gap':8},{'color':'#123456'},{'fontSize':18}]:
            node_type='image' if 'gap' not in style else 'text'
            props={'source':'https://example.com/a.jpg'} if node_type=='image' else {'text':'Hello'}
            data={'version':1,'id':'com.example.app','name':'App','root':{'id':'node','type':node_type,'props':props,'style':style}}
            with self.assertRaises(ValueError):lower(data,Registry())

    def test_registry_harness_valid_contexts(self):
        from tools.check_registry import fixture,social_fixture
        from dcflight.compiler import BACKENDS
        registry=Registry()
        for data in (fixture(),social_fixture()):
            application=lower(data,registry)
            for generator in BACKENDS.values():
                self.assertTrue(generator().generate(application,registry))

    def test_action_arguments_are_not_silently_ignored(self):
        data={'version':1,'id':'com.example.app','name':'App','state':{'count':0},'actions':[{'id':'go','op':'increment','target':'count','args':[]}],'root':{'id':'text','type':'text','props':{'text':'Hello'}}}
        with self.assertRaisesRegex(ValueError,'function/args'):lower(data,Registry())
