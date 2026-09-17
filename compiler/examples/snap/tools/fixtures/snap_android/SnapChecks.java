package com.dotcorr.snap;

import android.app.Instrumentation;
import android.app.Activity;
import android.os.Bundle;
import org.json.*;
import java.util.concurrent.*;
import android.hardware.camera2.*;
import android.media.ImageReader;

/** Separate instrumentation fixture. This class is never packaged in the application. */
public final class SnapChecks extends Instrumentation {
    private final JSONArray checks=new JSONArray();
    private final java.util.List<ApiClient> clients=new java.util.ArrayList<>();
    private JSONObject result=new JSONObject();
    private ApiClient alice,bob,stranger; private String password;
    private void check(String name,boolean condition)throws Exception{if(!condition)throw new AssertionError(name);checks.put(name);}
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    private static final class Reply {JSONObject json;byte[] bytes;String error;int status;}
    private JSONObject obj(Object... values)throws Exception{JSONObject o=new JSONObject();for(int i=0;i<values.length;i+=2)o.put((String)values[i],values[i+1]);return o;}
    private Reply call(ApiClient client,String method,String path,JSONObject body,byte[] upload,boolean binary)throws Exception{
        CountDownLatch complete=new CountDownLatch(1);Reply r=new Reply();client.request(method,path,body,upload,binary,(json,bytes,error,status)->{r.json=json;r.bytes=bytes;r.error=error;r.status=status;complete.countDown();});
        if(!complete.await(25,TimeUnit.SECONDS))throw new AssertionError("Request timeout: "+method+" "+path);return r;
    }
    private JSONObject ok(ApiClient client,String method,String path,JSONObject body)throws Exception{Reply r=call(client,method,path,body,null,false);if(r.status<200||r.status>=300)throw new AssertionError(method+" "+path+" -> "+r.status+" "+r.error);return r.json;}
    private ApiClient client(){ApiClient client=new ApiClient();clients.add(client);return client;}
    private JSONObject register(ApiClient client,String username)throws Exception{JSONObject r=ok(client,"POST","/auth/register",obj("username",username,"password",password,"display_name","Native integration check"));client.token=r.getString("token");return r;}
    private byte[] cameraPhoto()throws Exception{
        android.hardware.camera2.CameraManager manager=(android.hardware.camera2.CameraManager)getTargetContext().getSystemService(android.content.Context.CAMERA_SERVICE);
        String[] ids=manager.getCameraIdList();check("Android Camera2 enumerates software camera",ids.length>0);
        android.os.HandlerThread thread=new android.os.HandlerThread("test-camera");thread.start();android.os.Handler handler=new android.os.Handler(thread.getLooper());
        CameraDevice[] camera={null};CameraCaptureSession[] capture={null};Throwable[] failure={null};byte[][] photo={null};CountDownLatch ready=new CountDownLatch(1);
        CameraCharacteristics characteristics=manager.getCameraCharacteristics(ids[0]);android.util.Size[] sizes=characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(android.graphics.ImageFormat.JPEG);android.util.Size size=sizes[sizes.length-1];for(android.util.Size candidate:sizes)if(candidate.getWidth()<=2048&&candidate.getHeight()<=2048&&candidate.getWidth()*candidate.getHeight()>size.getWidth()*size.getHeight())size=candidate;
        ImageReader reader=ImageReader.newInstance(size.getWidth(),size.getHeight(),android.graphics.ImageFormat.JPEG,2);
        reader.setOnImageAvailableListener(source->{try(android.media.Image image=source.acquireLatestImage()){if(image==null)return;java.nio.ByteBuffer buffer=image.getPlanes()[0].getBuffer();byte[] raw=new byte[buffer.remaining()];buffer.get(raw);photo[0]=NativeCamera.normalize(new java.io.ByteArrayInputStream(raw));}catch(Throwable error){failure[0]=error;}finally{ready.countDown();}},handler);
        try{
            manager.openCamera(ids[0],new CameraDevice.StateCallback(){public void onOpened(CameraDevice device){camera[0]=device;try{device.createCaptureSession(java.util.Collections.singletonList(reader.getSurface()),new CameraCaptureSession.StateCallback(){public void onConfigured(CameraCaptureSession session){capture[0]=session;try{CaptureRequest.Builder request=device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);request.addTarget(reader.getSurface());session.capture(request.build(),new CameraCaptureSession.CaptureCallback(){@Override public void onCaptureFailed(CameraCaptureSession s,CaptureRequest r,CaptureFailure error){failure[0]=new AssertionError("Capture failure "+error.getReason());ready.countDown();}},handler);}catch(Throwable error){failure[0]=error;ready.countDown();}}public void onConfigureFailed(CameraCaptureSession session){failure[0]=new AssertionError("Camera configuration failed");ready.countDown();}},handler);}catch(Throwable error){failure[0]=error;ready.countDown();}}public void onDisconnected(CameraDevice device){failure[0]=new AssertionError("Camera disconnected");ready.countDown();}public void onError(CameraDevice device,int error){failure[0]=new AssertionError("Camera error "+error);ready.countDown();}},handler);
            if(!ready.await(30,TimeUnit.SECONDS))throw new AssertionError("Camera capture timed out");if(failure[0]!=null)throw new AssertionError(failure[0]);return photo[0];
        }finally{if(capture[0]!=null)capture[0].close();if(camera[0]!=null)camera[0].close();reader.close();thread.quitSafely();thread.join(3000);}
    }
    @Override public void onStart(){boolean passed=false;Bundle output=new Bundle();long started=android.os.SystemClock.elapsedRealtime();
        android.content.Context isolated=new android.content.ContextWrapper(getTargetContext()){
            @Override public String getPackageName(){return super.getPackageName()+".nativeqa";}
            @Override public android.content.SharedPreferences getSharedPreferences(String name,int mode){return getBaseContext().getSharedPreferences("nativeqa_"+name,mode);}
        };
        SessionStore store=new SessionStore(isolated);
        try{
            result.put("pid",android.os.Process.myPid());result.put("sdk",android.os.Build.VERSION.SDK_INT);result.put("vm",System.getProperty("java.vm.name"));
            check("JNI empty text rejected",SharedLogic.f_canSendMessage(0,0)==0);
            check("JNI photo message accepted",SharedLogic.f_canSendMessage(0,1)==1);
            check("JNI 2000 codepoints accepted",SharedLogic.f_canSendMessage(2000,0)==1);
            check("JNI 2001 codepoints rejected",SharedLogic.f_canSendMessage(2001,1)==0);
            check("JNI zero byte photo rejected",SharedLogic.f_canUploadPhoto(0)==0);
            check("JNI 8MiB photo accepted",SharedLogic.f_canUploadPhoto(8388608)==1);
            check("JNI over 8MiB photo rejected",SharedLogic.f_canUploadPhoto(8388609)==0);
            check("JNI new story lifetime",SharedLogic.f_remainingStorySeconds(0)==86400);
            check("JNI last story second",SharedLogic.f_remainingStorySeconds(86399)==1);
            check("JNI expired story hidden",SharedLogic.f_remainingStorySeconds(86400)==0);
            check("JNI no consent rejects location",SharedLogic.f_shouldPublishLocation(0,1)==0);
            check("JNI no permission rejects location",SharedLogic.f_shouldPublishLocation(1,0)==0);
            check("JNI consent plus permission permits location",SharedLogic.f_shouldPublishLocation(1,1)==1);
            boolean rejected=false;try{SharedLogic.f_canUploadPhoto(-1);}catch(IllegalArgumentException expected){rejected=true;}check("JNI negative unsigned input rejected",rejected);
            String suffix=java.util.UUID.randomUUID().toString().replace("-","").substring(0,10);password="Native-QA-"+java.util.UUID.randomUUID();alice=client();bob=client();stranger=client();
            JSONObject a=register(alice,"nqa_a_"+suffix),b=register(bob,"nqa_b_"+suffix);register(stranger,"nqa_c_"+suffix);check("Generated client registers three accounts",a.has("token")&&b.has("user"));
            String aid=a.getJSONObject("user").getString("id"),bid=b.getJSONObject("user").getString("id");
            store.save(a);JSONObject restored=store.load();check("Keystore encrypted session round trip",restored!=null&&restored.getString("token").equals(alice.token));String encrypted=isolated.getSharedPreferences("session",0).getString("encrypted","");check("Persisted session excludes bearer plaintext",!encrypted.contains(alice.token)&&encrypted.contains(":"));store.clear();check("Isolated session clear",store.load()==null);
            ApiClient login=client();JSONObject signed=ok(login,"POST","/auth/login",obj("username","nqa_a_"+suffix,"password",password));login.token=signed.getString("token");check("Generated client login",ok(login,"GET","/me",null).getString("id").equals(aid));
            JSONObject request=ok(alice,"POST","/friend-requests",obj("user_id",bid));check("Friend request pending",request.getString("status").equals("pending"));ok(bob,"POST","/friend-requests/"+request.getString("id")+"/accept",obj());check("Accepted friendship visible",ok(alice,"GET","/friends",null).getJSONArray("friends").length()==1);
            String conversation=ok(alice,"POST","/conversations",obj("user_id",bid)).getString("id");String text="Native Android → friend 📷";ok(alice,"POST","/conversations/"+conversation+"/messages",obj("text",text));JSONArray messages=ok(bob,"GET","/conversations/"+conversation+"/messages?after=0",null).getJSONArray("messages");check("Text delivered through generated native client",messages.length()==1&&messages.getJSONObject(0).getString("text").equals(text));
            byte[] photo=cameraPhoto();check("Actual Camera2 still captured and normalized",photo!=null&&photo.length>0&&SharedLogic.f_canUploadPhoto(photo.length)==1);android.graphics.BitmapFactory.Options info=new android.graphics.BitmapFactory.Options();info.inJustDecodeBounds=true;android.graphics.BitmapFactory.decodeByteArray(photo,0,photo.length,info);check("Generated normalization bounds camera photo",Math.max(info.outWidth,info.outHeight)<=2048&&info.outWidth>0);result.put("cameraPhotoBytes",photo.length);result.put("cameraPhotoWidth",info.outWidth);result.put("cameraPhotoHeight",info.outHeight);
            Reply upload=call(alice,"POST","/media",null,photo,false);check("Native camera photo upload",upload.status==201);String media=upload.json.getString("id");Reply denied=call(stranger,"GET","/media/"+media,null,null,true);check("Unshared private media denied",denied.status==404||denied.status==403);
            ok(alice,"POST","/conversations/"+conversation+"/messages",obj("media_id",media,"text","Captured using Android Camera2"));Reply downloaded=call(bob,"GET","/media/"+media,null,null,true);check("Friend receives authorized conversation photo",downloaded.status==200&&downloaded.bytes.length>0);check("Delivered photo decodes",android.graphics.BitmapFactory.decodeByteArray(downloaded.bytes,0,downloaded.bytes.length)!=null);
            JSONObject story=ok(alice,"POST","/stories",obj("media_id",media,"caption","Native camera integration"));check("Story carries exact 24h expiry",story.getLong("expires_at")-story.getLong("created_at")==86400);check("Friend sees story",ok(bob,"GET","/stories",null).getJSONArray("stories").length()==1);check("Stranger cannot see story",ok(stranger,"GET","/stories",null).getJSONArray("stories").length()==0);
            ok(alice,"PUT","/location",obj("enabled",true,"latitude_e6",52370000,"longitude_e6",4890000));check("Consenting test account location visible to friend",ok(bob,"GET","/map",null).getJSONArray("locations").length()==1);check("Location hidden from nonfriend",ok(stranger,"GET","/map",null).getJSONArray("locations").length()==0);ok(alice,"PUT","/location",obj("enabled",false));check("Disabled location removed",ok(bob,"GET","/map",null).getJSONArray("locations").length()==0);
            ok(alice,"DELETE","/stories/"+story.getString("id"),null);check("Deleted story disappears",ok(bob,"GET","/stories",null).getJSONArray("stories").length()==0);
            ok(login,"POST","/auth/logout",null);check("Revoked session denied",call(login,"GET","/me",null,null,false).status==401);
            passed=true;
        }catch(Throwable error){try{result.put("failure",android.util.Log.getStackTraceString(error));}catch(Exception ignored){}}
        finally{
            JSONArray cleanup=new JSONArray();for(ApiClient client:new ApiClient[]{alice,bob,stranger})if(client!=null&&!client.token.isEmpty())try{Reply deleted=call(client,"DELETE","/me",obj("password",password),null,false);cleanup.put(deleted.status);if(deleted.status!=204)passed=false;}catch(Exception error){cleanup.put(error.toString());passed=false;}
            store.clear();for(ApiClient client:clients)client.close();try{result.put("passed",passed);result.put("checks",checks);result.put("checkCount",checks.length());result.put("cleanup",cleanup);result.put("elapsedMs",android.os.SystemClock.elapsedRealtime()-started);result.put("scope","Android ART/JNI + generated HTTP/Keystore/image code + real Camera2 still + local backend; no UI interaction");}catch(Exception ignored){}
            output.putString("resultJson",result.toString());finish(passed?Activity.RESULT_OK:Activity.RESULT_CANCELED,output);
        }
    }
}
