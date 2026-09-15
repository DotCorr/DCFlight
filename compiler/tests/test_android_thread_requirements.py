import tempfile
import unittest
from pathlib import Path
from dcflight.platforms.android_api import AndroidAPI,JavaValue
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_operation import emit_operation
from dcflight.catalog import Catalog
from dcflight.platforms.ios_api import API

CATALOG='''package sample {
 @MainThread public class Calls {
  method public static int ui();
  method @WorkerThread public static int background();
  method @AnyThread public static int anywhere();
  method @MainThread @WorkerThread public static int conflict();
  method @AnyThread public static void callback(@UiThread java.lang.Runnable);
  field public static final java.lang.String LABEL = "@WorkerThread";
 }
}'''


class AndroidThreadRequirementsTests(unittest.TestCase):
    def test_owner_method_override_and_callback_annotations(self):
        api=AndroidAPI(CATALOG)
        for name,required in [('ui','main'),('background','worker'),('anywhere','any'),('conflict','conflicting')]:
            self.assertEqual(required,api.thread_requirement(api.get('sample.Calls#'+name+'()')))
        self.assertEqual('any',api.thread_requirement(api.get('sample.Calls#callback(java.lang.Runnable)')))
        self.assertEqual('main',api.thread_requirement(api.get('sample.Calls#LABEL')))
        api.emit('sample.Calls#background()',execution_context='worker')
        api.emit('sample.Calls#ui()',execution_context='main')
        api.emit('sample.Calls#anywhere()',execution_context='unknown')
        for name,context in [('background','main'),('ui','worker'),('ui','unknown'),('conflict','main'),('anywhere','bad')]:
            with self.subTest(name=name,context=context),self.assertRaises(ValueError):
                api.emit('sample.Calls#'+name+'()',execution_context=context)
        records={r['id']:r for r in api.records()}
        self.assertEqual('worker',records['sample.Calls#background()']['threadRequirement'])

    def test_shared_main_operation_cannot_call_worker_api(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'api.txt';source.write_text(CATALOG)
            db=root/'api.sqlite';index_android(db,source)
            with Catalog(db,write=True) as catalog:
                catalog.import_records('ios','Fixture','26.2',[API('fixture','Fixture',('Fixture','value()'),'static_method',(),'Int32',(),()).to_dict()],{'fixture':True})
            api=NativeAPI(db)
            def impl(identity):return {'steps':[{'id':identity,'bind':'value'}],'return':{'ref':'value'}}
            operation={'name':'value','result':'int','execution':'main','implementations':{'ios':impl('fixture'),'android':impl('sample.Calls#background()')}}
            with self.assertRaisesRegex(ValueError,'requires worker'):emit_operation(api,operation)
            operation['implementations']['android']=impl('sample.Calls#ui()')
            self.assertIn('sample.Calls.ui()',emit_operation(api,operation)['targets']['android']['source'])
            operation['execution']='worker'
            with self.assertRaisesRegex(ValueError,'requires main'):emit_operation(api,operation)
            operation['implementations']['android']=impl('sample.Calls#background()')
            self.assertIn('sample.Calls.background()',emit_operation(api,operation)['targets']['android']['source'])
            operation['implementations']['android']=impl('sample.Calls#ui()')
            operation['execution']='caller'
            with self.assertRaisesRegex(ValueError,'requires main'):emit_operation(api,operation)
            result=api.emit({'platform':'android','id':'sample.Calls#background()'})
            self.assertEqual('worker',result['threadRequirement'])
            with self.assertRaises(ValueError):api.emit({'platform':'android','id':'sample.Calls#background()','executionContext':None})
