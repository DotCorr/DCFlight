import contextlib
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.cli import main
from dcflight.mcp import Server
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_operation import emit_operation,lower_contract
from dcflight.platforms.ios_api import API

SDK='''package java.util {
 public final class UUID {
  method public static java.util.UUID randomUUID();
  method public String toString();
 }
}
'''

class NativeOperationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.db=self.root/'api.db'
        (self.root/'sdk.txt').write_text(SDK);index_android(self.db,self.root/'sdk.txt')
        records=[API('new','Foundation',('UUID','init()'),'constructor',(),'UUID',(),()).to_dict(),API('text','Foundation',('UUID','uuidString'),'property',(),'String',(),()).to_dict()]
        with Catalog(self.db,write=True) as catalog:catalog.import_records('ios','Foundation','26.2',records,{'fixture':True})
        self.api=NativeAPI(self.db)
        self.operation={'name':'newIdentifier','result':'string','implementations':{
            'ios':{'steps':[{'id':'new','bind':'uuid'},{'id':'text','receiver':{'ref':'uuid'},'bind':'text'}],'return':{'ref':'text'}},
            'android':{'steps':[{'id':'java.util.UUID#randomUUID()','bind':'uuid'},{'id':'java.util.UUID#toString()','receiver':{'ref':'uuid'},'bind':'text'}],'return':{'ref':'text'}}}}

    def test_both_native_implementations_compile_and_execute(self):
        out=emit_operation(self.api,self.operation)
        self.assertEqual('string',out['contract']['result']);self.assertIsNone(out['compilerRuntimeDependency'])
        jdk=Path(os.environ.get('JAVA_HOME','/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/toolchains/jdk-17.0.20.1+1/Contents/Home'))/'bin'
        if not (jdk/'javac').exists() or not Path('/usr/bin/xcrun').exists():self.skipTest('Java and Swift toolchains required')
        android=out['targets']['android'];ios=out['targets']['ios']
        java=self.root/android['fileName'];java.write_text(android['source'])
        check=self.root/'Check.java';check.write_text('class Check { public static void main(String[] args) { String value=NativeOperation_newIdentifier.invoke(); java.util.UUID.fromString(value); if(value.length()!=36) throw new AssertionError(); } }')
        subprocess.run([str(jdk/'javac'),'-d',str(self.root),str(java),str(check)],check=True,capture_output=True)
        subprocess.run([str(jdk/'java'),'-cp',str(self.root),'Check'],check=True,capture_output=True)
        swift=self.root/ios['fileName'];swift.write_text(ios['source'])
        main=self.root/'main.swift';main.write_text('import Foundation\nlet value=NativeOperation_newIdentifier.invoke()\nprecondition(value.count == 36 && UUID(uuidString:value) != nil)\n')
        binary=self.root/'verify'
        subprocess.run(['/usr/bin/xcrun','swiftc',str(swift),str(main),'-o',str(binary)],check=True,capture_output=True)
        subprocess.run([str(binary)],check=True,capture_output=True)

    def test_rejects_divergent_or_incomplete_contracts(self):
        cases=[]
        for mutation in [lambda o:o['implementations'].pop('android'),lambda o:o.update(result='int'),lambda o:o.update(throws='yes'),lambda o:o.update(name='bad;code'),lambda o:o['implementations']['ios'].update(platform='android'),lambda o:o['implementations']['android'].update(returnValue='raw'),lambda o:o['implementations']['ios'].update({'return':{'ref':'missing'}}),lambda o:o.update(parameters=[{'name':'a','type':'string'},{'name':'a','type':'int'}])]:
            value=copy.deepcopy(self.operation);mutation(value);cases.append(value)
        for value in cases:
            with self.subTest(value=value),self.assertRaises(ValueError):emit_operation(self.api,value)

    def test_cli_and_mcp(self):
        path=self.root/'operation.json';path.write_text(json.dumps(self.operation))
        stdout=io.StringIO()
        with contextlib.redirect_stdout(stdout):code=main(['sdk','emit-operation',str(path),'--catalog',str(self.db)])
        self.assertEqual(0,code);expected=emit_operation(self.api,self.operation)
        self.assertEqual(expected,json.loads(stdout.getvalue()))
        server=Server(self.db);server.handle({'jsonrpc':'2.0','id':1,'method':'initialize'})
        result=server.handle({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'sdk_emit_operation','arguments':{'operation':self.operation}}})['result']
        self.assertFalse(result['isError']);self.assertEqual(expected,json.loads(result['content'][0]['text']))

    def test_dart_authoring_uses_identical_contract_and_native_source(self):
        from dcflight.evaluated_frontend import load_evaluated_operation
        dart=Path('/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/dart-3.12.2/dart-sdk/bin/dart')
        if not dart.exists():self.skipTest('Dart SDK required')
        path=self.root/'operation.dart'
        path.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeImplementation makeImplementation(String create, String read) => NativeImplementation(
  steps: [NativeCall(create, bind: 'uuid'), NativeCall(read, receiver: const NativeRef('uuid'), bind: 'text')],
  result: const NativeRef('text'));
NativeOperation buildOperation() => NativeOperation(name: 'newIdentifier', result: NativeScalar.string,
  ios: makeImplementation('new', 'text'),
  android: makeImplementation('java.util.UUID#randomUUID()', 'java.util.UUID#toString()'));
""")
        evaluated=load_evaluated_operation(path,str(dart))
        expected=emit_operation(self.api,self.operation)
        self.assertEqual(expected,emit_operation(self.api,evaluated))
        self.assertEqual(lower_contract(self.operation),lower_contract(evaluated))
        stdout=io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code=main(['sdk','emit-operation',str(path),'--catalog',str(self.db),'--evaluate-dart','--dart-sdk',str(dart)])
        self.assertEqual(0,code);self.assertEqual(expected,json.loads(stdout.getvalue()))
        # Without opt-in the restricted parser must reject executable Dart.
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertNotEqual(0,main(['sdk','emit-operation',str(path),'--catalog',str(self.db)]))
        path.write_text("import 'package:dcflight_authoring/dcflight.dart';\nApp buildOperation() => App(id:'com.test.bad',name:'Bad',root:Text('Bad',id:'bad'));")
        with self.assertRaisesRegex(ValueError,'Dart authoring failed'):
            load_evaluated_operation(path,str(dart))

    def test_routed_application_generation_and_ownership(self):
        from dcflight.compiler import compile_app
        from dcflight.registry import Registry
        from dcflight.navigation_ir import schema
        from dcflight.validate import lower
        from dcflight.audit import source_consistency
        from dcflight.sync import Conflict
        operation=copy.deepcopy(self.operation);operation['execution']='main'
        document={'version':2,'id':'com.example.operation','name':'Native operation',
            'state':{'identifier':'','status':''}, 'sdkCatalog':str(self.db), 'nativeOperations':[operation],
            'root':{'id':'stack','type':'navigationStack','props':{'initialRoute':'home'}},
            'routes':[{'id':'home','title':'Identifier','body':{'id':'label','type':'text','props':{'text':{'ref':'identifier'}}}}],
            'flowActions':[
                {'id':'generate','cases':[{'code':0,'effects':[{'op':'nativeOperation','operation':'newIdentifier','target':'identifier','success':'accepted','failure':'rejected'}]}]},
                {'id':'accepted','cases':[{'code':0,'effects':[{'op':'set','target':'status','value':'ok'}]}]},
                {'id':'rejected','cases':[{'code':0,'effects':[{'op':'set','target':'status','value':'failed'}]}]}],
            'initialAction':'generate'}
        import jsonschema
        jsonschema.validate(document,schema(Registry()))
        app=lower(document,Registry());self.assertEqual('main',app.native_operations[0].execution)
        source=self.root/'app.json';source.write_text(json.dumps(document));out=self.root/'native'
        compile_app(source,out)
        swift=out/'ios/App/Generated/Operations/NativeOperation_newIdentifier.swift'
        java=out/'android/app/src/main/java/com/example/operation/NativeOperation_newIdentifier.java'
        self.assertIn('@MainActor',swift.read_text());self.assertTrue(java.read_text().startswith('package com.example.operation;'))
        self.assertEqual('matched',source_consistency(out)['status'])
        original=swift.read_text();swift.write_text(original+'// developer edit\n')
        changed=copy.deepcopy(document);changed['nativeOperations'][0]['throws']=True
        with self.assertRaises(Conflict):compile_app(source,out,document=changed)
        self.assertTrue(swift.read_text().endswith('// developer edit\n'))
        swift.write_text(original)
        with Catalog(self.db) as catalog:
            records=[catalog.get('ios',identity,'Foundation')['api'] for identity in ('new','text')]
        with Catalog(self.db,write=True) as catalog:catalog.import_records('ios','Foundation','26.2',records,{'fixture':True,'revision':2})
        compile_app(source,out,targets=('ios',))
        self.assertEqual('mismatched',source_consistency(out)['status'])
        compile_app(source,out,targets=('android',))
        self.assertEqual('matched',source_consistency(out)['status'])
        for mutation in [lambda d:d['nativeOperations'][0].update(execution='caller'),lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(target='missing'),lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(arguments=[1]),lambda d:d['flowActions'][0]['cases'][0]['effects'][0].update(success='generate')]:
            bad=copy.deepcopy(document);mutation(bad)
            with self.assertRaises(ValueError):lower(bad,Registry())

    def test_canonical_parameters(self):
        value=copy.deepcopy(self.operation);value['parameters']=[{'name':'supplied','type':'string'}]
        for implementation in value['implementations'].values():implementation['return']={'ref':'supplied'}
        out=emit_operation(self.api,value)
        self.assertIn('invoke(_ `supplied`: String)',out['targets']['ios']['source'])
        self.assertIn('invoke(java.lang.String supplied)',out['targets']['android']['source'])
        self.assertEqual(lower_contract(value).parameters[0].type.value,'string')

    def test_worker_contract_retains_sync_native_implementation(self):
        import jsonschema
        from dcflight.native_operation import schema
        value=copy.deepcopy(self.operation);value['execution']='worker'
        jsonschema.validate(value,schema())
        self.assertEqual('worker',lower_contract(value).execution)
        result=emit_operation(self.api,value)
        self.assertNotIn('@MainActor',result['targets']['ios']['source'])
        self.assertEqual('worker',result['contract']['execution'])
        # Scheduling belongs to generated app effects, not the SDK body itself.
        self.assertNotIn('Task.detached',result['targets']['ios']['source'])
