"""Operation/context evidence must survive actual compiler revalidation."""
import copy,json,shutil,tempfile,unittest
from pathlib import Path
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI
from dcflight.ios_invocation_evidence import verify_invocations,conditional_records,certificate_digest


def symbol(identity,kind,path,declaration):
    return {'identifier':{'precise':identity},'kind':{'identifier':'swift.'+kind},'pathComponents':path,'declarationFragments':[{'kind':'text','spelling':declaration}]}


@unittest.skipUnless(shutil.which('xcrun'),'Apple SDK/compiler required')
class IOSInvocationEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory();cls.root=Path(cls.temp.name);cls.graphs=cls.root/'graphs';cls.graphs.mkdir()
        symbols=[symbol('renderer','class',['AVSampleBufferVideoRenderer'],'class AVSampleBufferVideoRenderer'),symbol('export','class',['AVAssetExportSession'],'class AVAssetExportSession'),symbol('write','property',['AVSampleBufferVideoRenderer','presentationTimeExpectation'],'var presentationTimeExpectation: AVSampleBufferVideoRenderer.PresentationTimeExpectation { get set }'),symbol('async','property',['AVAssetExportSession','compatibleFileTypes'],'var compatibleFileTypes: [AVFileType] { get async }'),symbol('duration','property',['AVAssetExportSession','estimatedMaximumDuration'],'var estimatedMaximumDuration: CMTime { get async throws }')]
        (cls.graphs/'AVFoundation.symbols.json').write_text(json.dumps({'symbols':symbols}))
        cls.report=verify_invocations(cls.graphs,'AVFoundation',['write','async','duration'],cls.root/'report.json',contexts=('main','nonisolated'),additional_imports=['CoreImage'])
        cls.records=conditional_records(cls.report)
    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def api(self,report=None,records=None):
        database=self.root/('case'+str(len(list(self.root.glob('case*'))))+'.sqlite')
        with Catalog(database,write=True) as catalog:catalog.import_records('ios','AVFoundation','fixture',records or conditional_records(report or self.report),{})
        return NativeAPI(database)
    def request(self,identity,context='main',setter=False):
        request={'platform':'ios','id':identity,'actorContext':context,'receiver':{'ref':'receiver','type':'AVSampleBufferVideoRenderer' if identity=='write' else 'AVAssetExportSession'},'allowAsync':True}
        if setter:request['set']={'ref':'value','type':'AVSampleBufferVideoRenderer.PresentationTimeExpectation'}
        return request
    def test_real_getter_rejected_setter_passed_no_whole_symbol_promotion(self):
        api=self.api();self.assertTrue(all(r['emittable'] is False for r in self.records))
        emitted=api.emit(self.request('write',setter=True))
        self.assertIn(' = ',emitted['source']);self.assertIn('CoreImage',emitted['imports'])
        with self.assertRaises(ValueError):api.emit(self.request('write'))
    def test_real_async_context_is_exact_and_unknown_context_fails(self):
        api=self.api();self.assertIn('await',api.emit(self.request('async','nonisolated'))['source'])
        for context in ('main',None,'unknown'):
            request=self.request('async',context)
            if context is None:request.pop('actorContext')
            with self.subTest(context=context),self.assertRaises(ValueError):api.emit(request)
    def test_forged_pass_status_revalidated_by_native_compiler(self):
        report=copy.deepcopy(self.report)
        for row in report['invocations']:
            if row['id']=='async' and row['actorContext']=='main':row['status']='passed';row['diagnostics']=[]
        with self.assertRaises(ValueError):self.api(report).emit(self.request('async'))
    def test_forged_descriptor_or_source_cannot_inject_native_code(self):
        records=copy.deepcopy(self.records);record=next(r for r in records if r['id']=='write');record['resultType']='Int32'
        with self.assertRaises(ValueError):self.api(records=records).emit(self.request('write',setter=True))
        report=copy.deepcopy(self.report);report['invocations'][0]['source']='fatalError("injected")'
        with self.assertRaises(ValueError):self.api(report).emit(self.request('write',setter=True))
    def test_mutated_hash_missing_and_duplicate_context_proof_rejected(self):
        report=copy.deepcopy(self.report);report['invocations'].append(copy.deepcopy(report['invocations'][0]))
        with self.assertRaises(ValueError):conditional_records(report)
        records=copy.deepcopy(self.records);records[0]['nativeInvocationEvidence']['sha256']='0'*64
        with self.assertRaises(ValueError):self.api(records=records).emit(self.request(records[0]['id'],setter=records[0]['id']=='write'))
        report=copy.deepcopy(self.report);report['invocations']=[r for r in report['invocations'] if r['actorContext']!='nonisolated']
        with self.assertRaises(ValueError):self.api(report).emit(self.request('async','nonisolated'))
    def test_emitter_rejects_sdk_and_compiler_mismatch_and_rehashed_spoof(self):
        for key,value in [('sdkVersion','0.0'),('compilerSources',{}),('compilerUnchanged',False)]:
            report=copy.deepcopy(self.report);report[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):self.api(report).emit(self.request('write',setter=True))

    def test_worker_operation_keeps_objects_local_and_main_cannot_reuse_proof(self):
        import subprocess
        from dcflight.platforms.ios_api import API,Parameter
        from dcflight.native_api import index_android
        from dcflight.native_operation import emit_operation
        api=self.api();records=[
            API('url','Foundation',('URL','init(fileURLWithPath:)'),'constructor',(Parameter('fileURLWithPath','path','String'),),'URL',(),(),owner_kind='struct'),
            API('asset','AVFoundation',('AVAsset','init(url:)'),'constructor',(Parameter('url','url','URL'),),'AVAsset',(),(),owner_kind='class'),
            API('session','AVFoundation',('AVAssetExportSession','init(asset:presetName:)'),'constructor',(Parameter('asset','asset','AVAsset'),Parameter('presetName','presetName','String')),'AVAssetExportSession?',(),(),owner_kind='class'),
            API('valid','CoreMedia',('CMTime','isValid'),'property',(),'Bool',(),(),owner_kind='struct')]
        with Catalog(api.catalog_path,write=True) as catalog:catalog.import_records('ios','Construction','fixture',[r.to_dict() for r in records],{})
        android=self.root/'android.txt';android.write_text('package java.lang {\n public class Boolean {\n method public static boolean logicalOr(boolean,boolean);\n }\n}')
        index_android(api.catalog_path,android)
        operation={'name':'inspect','parameters':[{'name':'path','type':'string'}],'result':'bool','execution':'worker','suspends':True,'throws':True,'implementations':{
            'ios':{'steps':[{'id':'url','arguments':[{'ref':'path'}],'bind':'urlValue'},{'id':'asset','arguments':[{'ref':'urlValue'}],'bind':'assetValue'},{'id':'session','arguments':[{'ref':'assetValue'},{'literal':'AVAssetExportPresetPassthrough'}],'bind':'optionalSession'},{'unwrap':{'ref':'optionalSession'},'bind':'localSession','message':'Missing export session'},{'id':'duration','receiver':{'ref':'localSession'},'bind':'duration'},{'id':'valid','receiver':{'ref':'duration'},'bind':'valid'}],'return':{'ref':'valid'}},
            'android':{'steps':[{'id':'java.lang.Boolean#logicalOr(boolean,boolean)','arguments':[{'literal':True},{'literal':False}],'bind':'valid'}],'return':{'ref':'valid'}}}}
        generated=emit_operation(api,operation)['targets']['ios']['source']
        self.assertIn('try await',generated);self.assertNotIn('@MainActor',generated)
        from dcflight.ios_invocation_evidence import _compile
        passed,diagnostic=_compile(generated,self.report);self.assertTrue(passed,diagnostic)
        for context in ('main','caller'):
            operation['execution']=context
            with self.subTest(context=context),self.assertRaises(ValueError):emit_operation(api,operation)

    def test_cli_emits_only_conditional_records_and_refuses_existing_evidence(self):
        import contextlib,io
        from dcflight.cli import main
        output=self.root/'cli.json';records=self.root/'cli.jsonl'
        command=['sdk','verify-ios-invocations',str(self.graphs),'--module','AVFoundation','--id','async','--context','nonisolated','--report',str(output),'--records',str(records)]
        stdout=io.StringIO()
        with contextlib.redirect_stdout(stdout):code=main(command)
        self.assertEqual(code,0);self.assertEqual(json.loads(stdout.getvalue())['wholeDescriptorPromotions'],0)
        stored=[json.loads(line) for line in records.read_text().splitlines()]
        self.assertEqual(len(stored),1);self.assertIs(stored[0]['emittable'],False)
        before=(output.read_bytes(),records.read_bytes())
        with contextlib.redirect_stderr(io.StringIO()):self.assertEqual(main(command),1)
        self.assertEqual(before,(output.read_bytes(),records.read_bytes()))

    def test_legacy_records_unchanged_and_no_conditional_marker_bypass(self):
        from dcflight.platforms.ios_api import API
        record=API('old','Foundation',('ProcessInfo','processInfo'),'static_property',(),'ProcessInfo',(),()).to_dict()
        api=self.api(records=[record]);self.assertIn('processInfo',api.emit({'platform':'ios','id':'old'})['source'])
        records=copy.deepcopy(self.records);record=next(r for r in records if r['id']=='write');record['emittable']=True
        with self.assertRaises(ValueError):self.api(records=records).emit(self.request('write',setter=True))
        for mutate in (lambda r:r['invocations'][0].update(specialization={'receiverType':'Other'}),lambda r:r['invocations'][0].update(operation='execute'),lambda r:r['invocations'][0].update(actorContext='inherited')):
            report=copy.deepcopy(self.report);mutate(report)
            with self.assertRaises(ValueError):conditional_records(report)
