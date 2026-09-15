import unittest
from dcflight.backends.android import Android
from dcflight.backends.android_presentation import color
from dcflight.registry import Registry
from dcflight.validate import lower


def fixture():
    data = {'version':1,'id':'com.example.presentation','name':'Presentation','state':{'show':True},'root':{'id':'root','type':'column','style':{'padding':20,'gap':12,'fill':True,'maxWidth':480},'children':[
        {'id':'row','type':'row','style':{'gap':8,'fill':True,'align':'center'},'children':[
            {'id':'camera','type':'icon','props':{'name':'camera'},'style':{'color':'#11223380'}},
            {'id':'space','type':'spacer'},
            {'id':'label','type':'text','props':{'text':'Camera'},'style':{'fontSize':18,'fontWeight':'semibold'}}]},
        {'id':'photo','type':'image','props':{'source':'https://example.com/image.png'},'style':{'width':120,'height':80,'radius':12},'visibleWhen':{'ref':'show'},'motion':{'kind':'slide','durationMs':200}},
        {'id':'progress','type':'progressBar','props':{'value':42},'style':{'fill':True,'color':'#123456'}},
        {'id':'scroll','type':'scroll','style':{'height':200,'fill':True},'children':[{'id':'card','type':'card','style':{'padding':16,'radius':12,'background':'#FFFFFF','borderColor':'#00000080','borderWidth':1},'children':[{'id':'body','type':'text','props':{'text':'Hello'}}]}]}
    ]}}
    def complete(node):
        node.setdefault('props',{})
        for child in node.get('children',[]): complete(child)
    complete(data['root'])
    return data


class AndroidPresentationTests(unittest.TestCase):
    def setUp(self):
        registry=Registry();self.files=Android().generate(lower(fixture(),registry),registry)
        self.source=self.files['android/app/src/main/java/com/example/presentation/AppScreen.java'].content

    def test_color_order_layout_and_native_resource_emission(self):
        self.assertEqual('0x80112233',color('#11223380'))
        self.assertIn('layout_space = new android.widget.LinearLayout.LayoutParams(0,',self.source)
        self.assertIn('layout_space.setMarginStart(dp(8))',self.source)
        self.assertIn('capWidth(width, dp(480))',self.source)
        self.assertIn('R.drawable.app_icon_camera',self.source)
        self.assertIn('setGravity(android.view.Gravity.CENTER_VERTICAL)',self.source)
        self.assertIn('new android.widget.ScrollView(activity)',self.source)
        self.assertIn('new android.widget.FrameLayout.LayoutParams',self.source)
        self.assertIn('android/app/src/main/res/drawable/app_icon_camera.xml',self.files)
        self.assertIn('Math.round(0 *',self.files['android/app/src/main/java/com/example/presentation/MainActivity.java'].content)

    def test_native_motion_loading_and_cleanup(self):
        self.assertIn('ValueAnimator.areAnimatorsEnabled()',self.source)
        self.assertIn('setTranslationY(dp(16))',self.source)
        self.assertIn('visible_photo(model.s_show)',self.source)
        self.assertIn('imageWorkers.shutdownNow()',self.source)
        self.assertIn('request_photo.cancel(true)',self.source)
        self.assertIn('token_photo == token',self.source)
        self.assertIn('connection.disconnect()',self.source)
        self.assertIn('Only HTTPS images are supported',self.source)
        self.assertIn('Image unavailable',self.source)
        self.assertIn('android.permission.INTERNET',self.files['android/app/src/main/AndroidManifest.xml'].content)
        self.assertNotIn('dcflight',self.source)


if __name__=='__main__':unittest.main()
