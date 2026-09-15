#!/usr/bin/env python3
"""Compile and execute typed collection/encoding regressions in an isolated native fixture."""
import sys,json,threading,subprocess,os
from pathlib import Path
from http.server import BaseHTTPRequestHandler,HTTPServer
import sys
from pathlib import Path
from dataclasses import replace
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT),str(ROOT/'tests')]
from test_android_flow import flow_fixture,lit
from dcflight.ir import Node,Reference,ScalarType
from dcflight.collection_ir import Collection,CollectionField,FieldReference
from dcflight.flow_ir import ResponseOutput,PathTemplate
from dcflight.backends.android_routed import AndroidRouted
app=flow_fixture()
c=Collection('people','id',(CollectionField('id',ScalarType.STRING),CollectionField('name',ScalarType.STRING,lit('Unnamed')),CollectionField('age',ScalarType.INT)))
row=Node('personName','text',(('text',FieldReference('people','name',ScalarType.STRING)),),())
repeat=Node('peopleRows','repeat',(('collection',lit('people')),('selection',Reference('value',ScalarType.STRING))),(row,),action='submit')
f=app.flow_actions[0];case=f.cases[0]
r=replace(case.effects[0],path=PathTemplate((lit('/v1/people/'),Reference('value',ScalarType.STRING))),outputs=(ResponseOutput('people',('people',)),ResponseOutput('token',('token',))))
app=replace(app,collections=(c,),routes=(replace(app.routes[0],body=repeat),app.routes[1]),flow_actions=(replace(f,cases=(replace(case,effects=(r,)),)),)+app.flow_actions[1:])

from dcflight.flow_ir import NavigateEffect,Transport
f=app.flow_actions
app=replace(app,transport=Transport('http://localhost:8877',True),flow_actions=(f[0],replace(f[1],cases=(replace(f[1].cases[0],effects=(NavigateEffect('go'),)),)),replace(f[2],cases=(replace(f[2].cases[0],effects=f[2].cases[0].effects+(NavigateEffect('go'),)),))))
import argparse
parser=argparse.ArgumentParser(description='Separate API35 native fixture; does not operate shared app UI/session.')
parser.add_argument('--work',type=Path,required=True)
parser.add_argument('--sdk',type=Path,required=True)
parser.add_argument('--java-home',type=Path,required=True)
parser.add_argument('--gradle',type=Path,required=True)
parser.add_argument('--serial',required=True)
args=parser.parse_args()
output=args.work.resolve();output.mkdir(parents=True,exist_ok=True)
from dcflight.flow_ir import ClearCollectionEffect,FlowAction,FlowCase
append_request=replace(app.flow_actions[0].cases[0].effects[0],outputs=(ResponseOutput('people',('people',),'append'),ResponseOutput('token',('token',))))
append_flow=replace(app.flow_actions[0],id='append',cases=(FlowCase(0,(append_request,)),))
app=replace(app,flow_actions=app.flow_actions+(append_flow,FlowAction('clear',None,(),(FlowCase(0,(ClearCollectionEffect('people'),)),))))
for path,artifact in AndroidRouted().generate(app,None).items():
 p=output/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(artifact.content)
manifest=output/'android/app/src/main/AndroidManifest.xml';s=manifest.read_text().replace('</manifest>','<instrumentation android:name="com.example.routes.CollectionChecks" android:targetPackage="com.example.routes"/></manifest>');manifest.write_text(s)
source=r'''package com.example.routes
import android.app.Instrumentation
import android.os.Bundle
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import androidx.navigation.createGraph
import androidx.navigation.compose.composable
class CollectionChecks:Instrumentation(){
 var count=0
 fun check(ok:Boolean){count++;if(!ok)throw AssertionError("check $count")}
 override fun onCreate(args:Bundle?){super.onCreate(args);start()}
 override fun onStart(){val result=org.json.JSONObject();var passed=false
 try{
 runOnMainSync {
 val root=androidx.navigation.NavHostController(targetContext)
 root.navigatorProvider.addNavigator(androidx.navigation.compose.ComposeNavigator())
 root.graph=root.createGraph(startDestination="auth") { composable("auth"){};composable("privateTabs"){};composable("privateDetail"){} }
 root.navigate("privateTabs");root.navigate("privateDetail")
 check(root.previousBackStackEntry!=null)
 root.navigate("auth") { popUpTo(root.graph.id) { inclusive=true };launchSingleTop=true }
 check(root.currentDestination?.route=="auth")
 check(root.previousBackStackEntry==null)
 check(!root.popBackStack())
 }
 val effects=NativeEffects(targetContext)
 check(effects.pathSegment("AZaz09-._~")=="AZaz09-._~")
 check(effects.pathSegment("a /?&#%+é")=="a%20%2F%3F%26%23%25%2B%C3%A9")
 check(effects.pathSegment("😀")=="%F0%9F%98%80")
 var rejected=false;try{effects.pathSegment("\uD800")}catch(e:Exception){rejected=true};check(rejected)
 for(kind in listOf("valid","duplicate","wrong","missing","nullDefault","appendValid","appendExisting")){
 lateinit var model:AuthoredState
 val latch=CountDownLatch(1)
 runOnMainSync {model=AuthoredState(targetContext);model.s_value=kind;model.s_token="unchanged";model.c_people=listOf(Record_people("prior","Prior",9));if(kind.startsWith("append"))model.f_append { latch.countDown() } else model.f_submit { latch.countDown() }}
 check(latch.await(30,TimeUnit.SECONDS))
 runOnMainSync {
 if(kind=="appendValid") {check(model.s_token=="new-token");check(model.c_people.size==2);check(model.c_people[0].v_id=="prior");check(model.c_people[1].v_name=="Unnamed");model.f_clear {};check(model.c_people.isEmpty())}
 else if(kind=="valid"||kind=="nullDefault") {check(model.s_token=="new-token");check(model.c_people.size==1);check(model.c_people[0].v_name=="Unnamed");check(model.s_status==200)}
 else {check(model.s_token=="unchanged");check(model.c_people[0].v_id=="prior");check(model.s_status==0)}
 }
 }
 effects.close();passed=true
 }catch(error:Throwable){result.put("error",android.util.Log.getStackTraceString(error))}
 result.put("passed",passed).put("checks",count).put("sdk",android.os.Build.VERSION.SDK_INT)
 val out=Bundle();out.putString("resultJson",result.toString());finish(if(passed)-1 else 0,out)
 }
}
'''
(output/'android/app/src/main/java/com/example/routes/CollectionChecks.kt').write_text(source)
class Handler(BaseHTTPRequestHandler):
 def do_POST(self):
  self.rfile.read(int(self.headers.get('Content-Length','0')))
  kind=self.path.rsplit('/',1)[-1]
  row={'id':'prior' if kind=='appendExisting' else 'one','age':4}
  if kind=='wrong':row['age']='4'
  if kind=='missing':del row['id']
  if kind=='nullDefault':row['name']=None
  people=[row,row] if kind=='duplicate' else [row]
  data=json.dumps({'people':people,'token':'new-token'}).encode()
  self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def log_message(self,*args):pass
server=HTTPServer(('127.0.0.1',8877),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
base=Path.cwd();env=os.environ.copy();env['JAVA_HOME']=str(args.java_home.resolve());env['ANDROID_HOME']=str(args.sdk.resolve())
with (output/'build.log').open('w') as log:subprocess.run([str(args.gradle.resolve()),'-p',str(output/'android'),':app:assembleDebug','--offline','--console=plain'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
adb=[str(args.sdk.resolve()/'platform-tools/adb'),'-s',args.serial]
subprocess.run(adb+['install','-r',str(output/'android/app/build/outputs/apk/debug/app-debug.apk')],check=True)
r=subprocess.run(adb+['shell','am','instrument','-w','com.example.routes/.CollectionChecks'],capture_output=True,text=True,timeout=180)
(output/'device.log').write_text(r.stdout+r.stderr);print(r.stdout,r.stderr)
server.shutdown()
import re,hashlib
match=re.search(r'resultJson=(\{.*\})',r.stdout)
report=json.loads(match.group(1)) if match else {'passed':False,'error':r.stdout+r.stderr}
report['scope']='Separate generated collection fixture on Android ART; no Snap UI coverage.'
apk=output/'android/app/build/outputs/apk/debug/app-debug.apk'
report['apkSha256']=hashlib.sha256(apk.read_bytes()).hexdigest()
(output/'report.json').write_text(json.dumps(report,indent=2))
if not report.get('passed'):raise SystemExit(1)
