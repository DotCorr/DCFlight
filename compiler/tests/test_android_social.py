import unittest
from dcflight.backends.android_social import generate
from dcflight.validate import lower
from dcflight.registry import Registry


def fixture():
    return {'version':1,'id':'com.example.social','name':'Social','service':{'baseUrl':'http://localhost:8765','development':True},'root':{'id':'tabs','type':'tabs','props':{},'children':[{'id':'chatTab','type':'tab','props':{'title':'Messages','icon':'chat'},'children':[{'id':'chat','type':'inbox','props':{}}]},{'id':'mapTab','type':'tab','props':{'title':'Friends','icon':'map'},'children':[{'id':'map','type':'friendMap','props':{}}]}]}}


class AndroidSocialTests(unittest.TestCase):
    def setUp(self):
        data=fixture()
        data['root']['children'].append({'id':'accountTab','type':'tab','props':{'title':'You','icon':'user'},'children':[{'id':'account','type':'account','props':{}}]})
        data['logic']={'source':'logic.dart','prelude':'prelude.dart','functions':[{'name':name,'parameters':['uint32']*arity,'returns':'uint32'} for name,arity in [('canSendMessage',2),('canUploadPhoto',1),('remainingStorySeconds',1),('shouldPublishLocation',2)]]}
        self.files=generate(lower(data,Registry()))
        self.java='android/app/src/main/java/com/example/social/'

    def test_configuration_and_native_ownership(self):
        source=self.files[self.java+'SocialActivity.java'].content
        self.assertIn('new String[]{"Messages","Friends","You"}',source)
        self.assertIn('new String[]{"inbox","friendMap","account"}',source)
        self.assertNotIn('__PACKAGE__',source)
        self.assertEqual('user',self.files[self.java+'MainActivity.java'].ownership)
        self.assertEqual('generated',self.files[self.java+'SocialActivity.java'].ownership)
        self.assertIn('http://10.0.2.2:8765',self.files[self.java+'ApiClient.java'].content)
        policy=self.files['android/app/src/main/res/xml/network_security_config.xml'].content
        self.assertIn('base-config cleartextTrafficPermitted="false"',policy)
        self.assertIn('<domain>10.0.2.2</domain>',policy)

    def test_shared_policy_and_platform_security(self):
        source=self.files[self.java+'SocialActivity.java'].content
        for name in ('canSendMessage','canUploadPhoto','remainingStorySeconds','shouldPublishLocation'):
            self.assertIn('SharedLogic.f_'+name+'(',source)
        self.assertIn('text.codePointCount(0,text.length())',source)
        self.assertIn('foreground=false',source)
        self.assertIn('messages?after="+messageCursor',source)
        self.assertIn('if(items.length()==100)loadMessages',source)
        self.assertIn('remaining*1000L',source)
        self.assertIn('changingConsent=true;consent.setChecked(true)',source)
        self.assertIn('caption.codePointCount(0,caption.length())',source)
        self.assertIn('stopLocation()',source)
        self.assertIn('AndroidKeyStore',self.files[self.java+'SessionStore.java'].content)
        self.assertIn('AES/GCM/NoPadding',self.files[self.java+'SessionStore.java'].content)
        self.assertIn('setInstanceFollowRedirects(false)',self.files[self.java+'ApiClient.java'].content)
        self.assertIn('setConnectTimeout(10000)',self.files[self.java+'ApiClient.java'].content)
        self.assertIn('Bitmap.CompressFormat.JPEG,85',self.files[self.java+'NativeCamera.java'].content)
        for artifact in self.files.values():
            self.assertNotIn('WebView',artifact.content)
            self.assertNotIn('System.loadLibrary("dcflight',artifact.content)

    def test_native_auth_hierarchy_accessibility_and_loading(self):
        source=self.files[self.java+'SocialActivity.java'].content
        self.assertIn('RippleDrawable',source)
        self.assertIn('setAutofillHints(View.AUTOFILL_HINT_PASSWORD)',source)
        self.assertIn('PasswordTransformationMethod.getInstance()',source)
        self.assertIn('username.setError(',source)
        self.assertIn('setFillViewport(true)',source)
        self.assertIn('trigger.setEnabled(false)',source)
        self.assertIn('trigger.setEnabled(true)',source)
        self.assertIn('setContentDescription(titles[i]',source)
        self.assertIn('New here? Create an account',source)
        self.assertIn('R.drawable.app_icon_camera',source)
        self.assertIn('Your people. Your moments.',source)

    def test_camera_unavailable_controls_are_honest(self):
        source=self.files[self.java+'SocialActivity.java'].content
        camera=self.files[self.java+'NativeCamera.java'].content
        self.assertIn('stage.setBackgroundColor(Color.BLACK)',source)
        self.assertIn('shutter.setEnabled(ready)',source)
        self.assertIn('flip.setEnabled(ready)',source)
        self.assertIn('Retry camera',source)
        self.assertIn('state.changed(true,',camera)
        self.assertIn('state.changed(false,',camera)
        self.assertNotIn('Connecting securely',source)
        self.assertIn('Signing in…',source)
        self.assertIn('Creating account…',source)

if __name__=='__main__':unittest.main()
