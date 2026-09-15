import unittest
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.backends.android_routed import AndroidRouted


class RoutedTextMetricsTests(unittest.TestCase):
    def test_authored_font_uses_native_metrics_without_changing_unstyled_text(self):
        children=[]
        for kind,props in [('text',{'text':'Heading'}),('counter',{'value':1}),('button',{'text':'Continue'}),('textField',{'value':{'ref':'value'},'placeholder':'Name'}),('secureField',{'value':{'ref':'value'},'placeholder':'Password'}),('toggle',{'value':{'ref':'enabled'},'text':'Setting'})]:
            children.append({'id':kind,'type':kind,'props':props,'style':{'fontSize':40}})
            if kind=='button':children[-1]['action']='press'
        children.append({'id':'default','type':'text','props':{'text':'Native default'}})
        doc={'version':2,'id':'com.example.metrics','name':'Metrics','state':{'value':'','enabled':True},'root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'','body':{'id':'body','type':'column','children':children}}]}
        doc['state']['count']=0
        doc['actions']=[{'id':'press','op':'increment','target':'count'}]
        registry=Registry();files=AndroidRouted().generate(lower(doc,registry),registry)
        source=files['android/app/src/main/java/com/example/metrics/AuthoredApplication.kt'].content
        self.assertEqual(8,source.count('LocalTextStyle.current.copy(lineHeight=TextUnit.Unspecified)'))
        self.assertIn('Text("Native default",modifier=Modifier.testTag("default"))',source)
        self.assertNotIn('lineHeight=40.sp',source)
