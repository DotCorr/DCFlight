#!/usr/bin/env python3
"""Separate native media adapter fixture; never injects picker/UI input."""
import argparse,sys,subprocess,os,json,threading,re,hashlib
from pathlib import Path
from dataclasses import replace
from http.server import BaseHTTPRequestHandler,HTTPServer
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT),str(ROOT/'tests')]
from test_android_media import fixture
from dcflight.backends.android_routed import AndroidRouted
from dcflight.flow_ir import Transport
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--sdk',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--gradle',type=Path,required=True);p.add_argument('--serial',required=True);args=p.parse_args()
app=replace(fixture(),transport=Transport('http://localhost:8878',True));out=args.work.resolve();out.mkdir(parents=True,exist_ok=True)
for name,artifact in AndroidRouted().generate(app,None).items():
 target=out/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(artifact.content)
manifest=out/'android/app/src/main/AndroidManifest.xml';manifest.write_text(manifest.read_text().replace('</manifest>','<instrumentation android:name="com.example.routes.MediaChecks" android:targetPackage="com.example.routes"/></manifest>'))
source=r'''package com.example.routes
import android.app.Instrumentation
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.Color
import java.io.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
class MediaChecks:Instrumentation(){
 var count=0
 fun check(value:Boolean){count++;if(!value)throw AssertionError("check $count")}
 fun reject(block:()->Unit){var rejected=false;try{block()}catch(error:Exception){rejected=true};check(rejected)}
 override fun onCreate(args:Bundle?){super.onCreate(args);start()}
 override fun onStart(){val report=org.json.JSONObject();var passed=false
 try{
 val input=Bitmap.createBitmap(1200,800,Bitmap.Config.ARGB_8888);input.eraseColor(Color.RED)
 val bytes=ByteArrayOutputStream();input.compress(Bitmap.CompressFormat.JPEG,95,bytes);input.recycle();val raw=bytes.toByteArray()
 val options=NativePhotoOptions(256,85,33554432,8388608,20000000)
 val photo=NativeMedia.normalize(ByteArrayInputStream(raw),options)
 check(photo.width==256);check(photo.height==170);check(photo.bytes.isNotEmpty())
 reject{NativeMedia.normalize(ByteArrayInputStream(raw),options.copy(maxInputBytes=10))}
 reject{NativeMedia.normalize(ByteArrayInputStream(raw),options.copy(maxDecodedPixels=100))}
 reject{NativeMedia.normalize(ByteArrayInputStream(raw),options.copy(maxOutputBytes=10))}
 reject{NativeMedia.normalize(ByteArrayInputStream(byteArrayOf(1,2,3)),options)}
 val file=File(targetContext.cacheDir,"native-media-test.jpg")
 for(direction in 1..8){file.writeBytes(raw);val exif=android.media.ExifInterface(file);exif.setAttribute(android.media.ExifInterface.TAG_ORIENTATION,direction.toString());exif.saveAttributes();val oriented=file.inputStream().use{NativeMedia.normalize(it,options)};check(if(direction>=5)oriented.height==256&&oriented.width==170 else oriented.width==256&&oriented.height==170)}
 val transparent=Bitmap.createBitmap(20,20,Bitmap.Config.ARGB_8888);val png=ByteArrayOutputStream();transparent.compress(Bitmap.CompressFormat.PNG,100,png);transparent.recycle();val opaque=NativeMedia.normalize(ByteArrayInputStream(png.toByteArray()),options);val decoded=android.graphics.BitmapFactory.decodeByteArray(opaque.bytes,0,opaque.bytes.size);check(Color.red(decoded.getPixel(0,0))>245);decoded.recycle()
 val effects=NativeEffects(targetContext)
 check(effects.string(org.json.JSONObject().put("text","😀"),listOf("text"))=="😀")
 reject{effects.string(org.json.JSONObject().put("text","\uD800"),listOf("text"))}
 runOnMainSync{
 val first=NativeNavigationPort();val received=mutableListOf<String>();first.attach{received.add("first:"+it)};first("one");first.detach(true);first("two");check(received==listOf("first:one"));first.attach{received.add("reattached:"+it)};check(received.last()=="reattached:two");first.detach(false);first("three");first.attach{received.add("wrong:"+it)};check(!first.alive);check(received.size==2)
 val model=AuthoredState(targetContext);val old=model.navigationPort("owner");old.detach(false);val fresh=model.navigationPort("owner");check(fresh!==old);check(!old.alive);model.m_photo=photo;model.f_clear{};check(model.m_photo==null)
 }
 val upload=CountDownLatch(1);var uploadGood=false
 runOnMainSync {effects.request("POST","/upload",photo,null){json,status->uploadGood=status==200&&json?.getInt("bytes")==photo.bytes.size&&json?.getString("type")=="image/jpeg";upload.countDown()}}
 check(upload.await(30,TimeUnit.SECONDS));check(uploadGood)
 val acquire=CountDownLatch(1);var acquired=false;lateinit var media:NativeMedia
 file.writeBytes(raw)
 runOnMainSync{media=NativeMedia(targetContext);media.pick("photo",options){value,result->acquired=result==0&&value?.width==256;acquire.countDown()};check(media.markLaunched(media.launchRequest!!));media.selected(android.net.Uri.fromFile(file))}
 check(acquire.await(30,TimeUnit.SECONDS));check(acquired)
 runOnMainSync{var called=false;media.pick("photo",options){_,_->called=true};val token=media.launchRequest!!;check(media.markLaunched(token));media.clear("photo");media.selected(null);check(!called);media.close()}
 file.delete();effects.close();passed=true
 }catch(error:Throwable){report.put("failure",android.util.Log.getStackTraceString(error))}
 report.put("passed",passed).put("checks",count).put("sdk",android.os.Build.VERSION.SDK_INT)
 val result=Bundle();result.putString("resultJson",report.toString());finish(if(passed)-1 else 0,result)
 }
}
'''
(out/'android/app/src/main/java/com/example/routes/MediaChecks.kt').write_text(source)
class Handler(BaseHTTPRequestHandler):
 def do_POST(self):
  data=self.rfile.read(int(self.headers.get('Content-Length','0')));response=json.dumps({'bytes':len(data),'type':self.headers.get('Content-Type')}).encode();self.send_response(200);self.send_header('Content-Length',str(len(response)));self.end_headers();self.wfile.write(response)
 def log_message(self,*args):pass
server=HTTPServer(('127.0.0.1',8878),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
env=os.environ.copy();env.update(JAVA_HOME=str(args.java_home.resolve()),ANDROID_HOME=str(args.sdk.resolve()))
with (out/'build.log').open('w') as log:subprocess.run([str(args.gradle.resolve()),'-p',str(out/'android'),':app:assembleDebug','--offline','--console=plain'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
adb=[str(args.sdk.resolve()/'platform-tools/adb'),'-s',args.serial];apk=out/'android/app/build/outputs/apk/debug/app-debug.apk'
subprocess.run(adb+['install','-r',str(apk)],check=True)
r=subprocess.run(adb+['shell','am','instrument','-w','com.example.routes/.MediaChecks'],capture_output=True,text=True,timeout=180);(out/'device.log').write_text(r.stdout+r.stderr);print(r.stdout,r.stderr);server.shutdown()
match=re.search(r'resultJson=(\{.*\})',r.stdout);report=json.loads(match.group(1)) if match else {'passed':False,'error':r.stdout+r.stderr};report['apkSha256']=hashlib.sha256(apk.read_bytes()).hexdigest();report['scope']='Generated native media helper, HTTP and origin-host callback checks; no photo-picker UI automation or Snap UI coverage.';(out/'report.json').write_text(json.dumps(report,indent=2))
if not report.get('passed'):raise SystemExit(1)
