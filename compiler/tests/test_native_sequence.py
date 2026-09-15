import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.native_sequence import emit_sequence
from dcflight.platforms.ios_api import API
from dcflight.cli import main

SDK='''package demo {
 public class Box {
  ctor public Box();
  field public int count;
  method public int read();
  method public void finish();
 }
}
'''

class NativeSequenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.db=self.root/'catalog.db'
        source=self.root/'sdk.txt';source.write_text(SDK)
        index_android(self.db,source)
        records=[API('uuid-new','Foundation',('UUID','init()'),'constructor',(),'UUID',(),()).to_dict(),
                 API('uuid-string','Foundation',('UUID','uuidString'),'property',(),'String',(),()).to_dict()]
        with Catalog(self.db,write=True) as catalog:catalog.import_records('ios','Fixture','26.2',records,{'fixture':True})
        self.api=NativeAPI(self.db)

    def sequence(self):
        return {'platform':'android','steps':[
            {'id':'demo.Box#<init>()','bind':'box'},
            {'id':'demo.Box#count','receiver':{'ref':'box'},'set':{'literal':42}},
            {'id':'demo.Box#read()','receiver':{'ref':'box'},'bind':'answer'},
            {'id':'demo.Box#count','receiver':{'ref':'box'}},
            {'id':'demo.Box#finish()','receiver':{'ref':'box'}}]}

    def test_java_native_execution_and_cli(self):
        seq=self.sequence();result=emit_sequence(self.api,seq)
        self.assertEqual([{'name':'box','type':'demo.Box','nativeName':'dcfLocal0'},{'name':'answer','type':'int','nativeName':'dcfLocal2'}],result['bindings'])
        self.assertIsNone(result['compilerRuntimeDependency'])
        source=self.root/'sequence.json';source.write_text(json.dumps(seq))
        output=io.StringIO()
        with contextlib.redirect_stdout(output):code=main(['sdk','emit-sequence',str(source),'--catalog',str(self.db)])
        self.assertEqual(0,code);self.assertEqual(result,json.loads(output.getvalue()))
        jdk=Path(os.environ.get('JAVA_HOME','/Users/ghostportal/Documents/Codex/2026-09-13/referenced-chatgpt-conversation-this-is-an-2/work/toolchains/jdk-17.0.20.1+1/Contents/Home'))/'bin'
        if not (jdk/'javac').exists():self.skipTest('JDK required')
        (self.root/'demo').mkdir()
        (self.root/'demo/Box.java').write_text('package demo; public class Box { public int count; public int read(){return count;} public void finish(){} }')
        (self.root/'Check.java').write_text('class Check { public static void main(String[] args) { '+result['source']+' if(dcfLocal2!=42) throw new AssertionError(); } }')
        subprocess.run([str(jdk/'javac'),'-d',str(self.root),str(self.root/'demo/Box.java'),str(self.root/'Check.java')],check=True,capture_output=True)
        subprocess.run([str(jdk/'java'),'-cp',str(self.root),'Check'],check=True,capture_output=True)

    def test_swift_native_execution(self):
        seq={'platform':'ios','steps':[{'id':'uuid-new','bind':'UUID'},{'id':'uuid-string','receiver':{'ref':'UUID'},'bind':'text'},{'id':'uuid-new','bind':'second'}]}
        result=emit_sequence(self.api,seq)
        self.assertEqual(['Foundation'],result['imports'])
        self.assertEqual('String',result['bindings'][1]['type'])
        if not Path('/usr/bin/xcrun').exists():self.skipTest('Swift compiler required')
        source=self.root/'main.swift';binary=self.root/'verify'
        source.write_text('import Foundation\n'+result['source']+'\nprecondition(dcfLocal1.count == 36)\n')
        subprocess.run(['/usr/bin/xcrun','swiftc',str(source),'-o',str(binary)],check=True,capture_output=True)
        subprocess.run([str(binary)],check=True,capture_output=True)

    def test_rejects_invalid_dataflow(self):
        mutations=[
            lambda s:s['steps'][0].update(bind='dcfLocal0'),
            lambda s:s['steps'][0].update(bind='bad;code'),
            lambda s:s['steps'][2].update(bind='box'),
            lambda s:s['steps'][1].update(receiver={'ref':'later'}),
            lambda s:s['steps'][1].update(receiver={'ref':'box','type':'demo.Other'}),
            lambda s:s['steps'][1].update(bind='assignment'),
            lambda s:s['steps'][4].update(bind='nothing'),
            lambda s:s['steps'][1].update(set={'literal':'wrong'}),
            lambda s:s['steps'][1].update(platform='ios'),
            lambda s:s.update(inputs=[{'name':'box','type':'demo.Box'}]),
        ]
        for change in mutations:
            seq=self.sequence();change(seq)
            with self.subTest(seq=seq),self.assertRaises(ValueError):emit_sequence(self.api,seq)
        for seq in [{'platform':'android','steps':[]},{'platform':'android','steps':[{}]},{'platform':'android','steps':self.sequence()['steps'],'allowAsync':True}]:
            with self.assertRaises(ValueError):emit_sequence(self.api,seq)

    def test_external_symbol_cannot_shadow_sdk_constructor(self):
        with self.assertRaisesRegex(ValueError,'shadows'):
            emit_sequence(self.api,{'platform':'ios','inputs':[{'name':'UUID','type':'UUID'}],'steps':[{'id':'uuid-new','bind':'created'}]})

    def test_mcp_sequence_dispatch(self):
        from dcflight.mcp import Server
        server=Server(self.db)
        server.handle({'jsonrpc':'2.0','id':1,'method':'initialize'})
        result=server.handle({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'sdk_emit_sequence','arguments':{'sequence':self.sequence()}}})['result']
        self.assertFalse(result['isError'])
        self.assertEqual(emit_sequence(self.api,self.sequence()),json.loads(result['content'][0]['text']))

    def test_external_inputs_have_explicit_types(self):
        result=emit_sequence(self.api,{'platform':'android','inputs':[{'name':'source','type':'demo.Box'}],'steps':[{'id':'demo.Box#read()','receiver':{'ref':'source'},'bind':'value'}]})
        self.assertIn('int dcfLocal0 = ((demo.Box) source).read();',result['source'])
