package com.dotcorr.devicechecks;
import android.app.Instrumentation;
import android.os.*;
import android.opengl.*;
import android.graphics.SurfaceTexture;
import android.view.TextureView;
import java.lang.reflect.*;
import java.util.concurrent.*;

/** Native API conformance fixture. No UI inputs or application-account mutations. */
public class DeviceChecks extends Instrumentation {
 int checks=0; ClassLoader loader; Object unit; Object camera; TextureView view; SurfaceTexture surface; HandlerThread render; Handler gl;
 Object fn(java.util.function.Consumer<Object[]> callback)throws Exception {return Proxy.newProxyInstance(loader,new Class[]{Class.forName("kotlin.jvm.functions.Function2",true,loader)},(p,m,a)->{if(m.getName().equals("invoke"))callback.accept(a);return unit;});}
 void check(boolean value){checks++;if(!value)throw new AssertionError("check "+checks);}
 void main(Runnable r){runOnMainSync(r);}
 Class<?> cls(String name)throws Exception{return Class.forName("com.dotcorr.snapshared."+name,true,loader);}
 Object call(String name,Class<?>[] types,Object...args)throws Exception{return camera.getClass().getMethod(name,types).invoke(camera,args);}
 @Override public void onCreate(Bundle b){super.onCreate(b);start();}
 @Override public void onStart(){org.json.JSONObject report=new org.json.JSONObject();boolean passed=false;try{
 loader=getTargetContext().getClassLoader();unit=Class.forName("kotlin.Unit",true,loader).getField("INSTANCE").get(null);
 Object companion=cls("NativeDevice").getField("Companion").get(null);Method round=companion.getClass().getMethod("roundAway",double.class);
 check((int)round.invoke(companion,0.5)==1);check((int)round.invoke(companion,-0.5)==-1);check((int)round.invoke(companion,1.5)==2);check((int)round.invoke(companion,-1.5)==-2);
 render=new HandlerThread("camera-test-consumer");render.start();gl=new Handler(render.getLooper());CountDownLatch eglReady=new CountDownLatch(1);
 gl.post(()->{EGLDisplay display=EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);int[] version=new int[2];EGL14.eglInitialize(display,version,0,version,1);EGLConfig[] configs=new EGLConfig[1];int[] count=new int[1];EGL14.eglChooseConfig(display,new int[]{EGL14.EGL_RENDERABLE_TYPE,EGL14.EGL_OPENGL_ES2_BIT,EGL14.EGL_SURFACE_TYPE,EGL14.EGL_PBUFFER_BIT,EGL14.EGL_NONE},0,configs,0,1,count,0);EGLContext context=EGL14.eglCreateContext(display,configs[0],EGL14.EGL_NO_CONTEXT,new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,2,EGL14.EGL_NONE},0);EGLSurface pbuffer=EGL14.eglCreatePbufferSurface(display,configs[0],new int[]{EGL14.EGL_WIDTH,16,EGL14.EGL_HEIGHT,16,EGL14.EGL_NONE},0);EGL14.eglMakeCurrent(display,pbuffer,pbuffer,context);int[] texture=new int[1];GLES20.glGenTextures(1,texture,0);surface=new SurfaceTexture(texture[0]);surface.setOnFrameAvailableListener(value->{try{value.updateTexImage();}catch(Exception e){}},gl);eglReady.countDown();});
 check(eglReady.await(10,TimeUnit.SECONDS));CountDownLatch ready=new CountDownLatch(1);boolean[] good={false};Object state=fn(values->{if((boolean)values[0]||(boolean)values[1]){good[0]=(boolean)values[0];ready.countDown();}});
 main(()->{try{view=new TextureView(getTargetContext());view.setSurfaceTexture(surface);view.layout(0,0,320,240);camera=cls("NativeCamera").getConstructors()[0].newInstance(view,"fit",state);call("active",new Class[]{boolean.class},true);}catch(Exception e){throw new RuntimeException(e);}});
 check(ready.await(25,TimeUnit.SECONDS));check(good[0]);
 Class<?> optionType=cls("NativePhotoOptions");Object options=optionType.getConstructor(int.class,int.class,int.class,int.class,int.class).newInstance(256,85,33554432,8388608,20000000);
 for(int attempt=0;attempt<2;attempt++){CountDownLatch captured=new CountDownLatch(1);Object[] result={null,null};Object done=fn(values->{result[0]=values[0];result[1]=values[1];captured.countDown();});main(()->{try{call("capture",new Class[]{optionType,done.getClass().getInterfaces()[0]},options,done);}catch(Exception e){throw new RuntimeException(e);}});check(captured.await(25,TimeUnit.SECONDS));check(result[1].equals(0));check(result[0]!=null);int width=(int)result[0].getClass().getMethod("getWidth").invoke(result[0]);int height=(int)result[0].getClass().getMethod("getHeight").invoke(result[0]);check(Math.max(width,height)<=256&&width>0&&height>0);}
 main(()->{try{Field sensor=camera.getClass().getDeclaredField("sensor");sensor.setAccessible(true);Field lens=camera.getClass().getDeclaredField("lens");lens.setAccessible(true);Method transform=camera.getClass().getDeclaredMethod("transform");transform.setAccessible(true);for(int angle:new int[]{0,90,180,270}){sensor.setInt(camera,angle);lens.set(camera,"back");transform.invoke(camera);android.graphics.Matrix back=view.getTransform(null);float[] corner={0,0};back.mapPoints(corner);android.graphics.RectF bounds=new android.graphics.RectF(0,0,320,240);back.mapRect(bounds);check(Math.abs(bounds.centerX()-160)<0.01f&&Math.abs(bounds.centerY()-120)<0.01f);check(bounds.left>=-0.01f&&bounds.top>=-0.01f&&bounds.right<=320.01f&&bounds.bottom<=240.01f);lens.set(camera,"front");transform.invoke(camera);float[] mirrored={0,0};view.getTransform(null).mapPoints(mirrored);check(Math.abs(mirrored[0]-(320-corner[0]))<0.01f);check(Math.abs(mirrored[1]-corner[1])<0.01f);}}catch(Exception e){throw new RuntimeException(e);}});
 main(()->{try{call("active",new Class[]{boolean.class},false);}catch(Exception e){throw new RuntimeException(e);}});
 CountDownLatch stopped=new CountDownLatch(1);int[] code={-1};Object done=fn(values->{code[0]=(int)values[1];stopped.countDown();});main(()->{try{call("capture",new Class[]{optionType,done.getClass().getInterfaces()[0]},options,done);}catch(Exception e){throw new RuntimeException(e);}});check(stopped.await(10,TimeUnit.SECONDS));check(code[0]==2);passed=true;
 }catch(Throwable error){try{report.put("failure",android.util.Log.getStackTraceString(error));}catch(Exception ignored){}}finally{if(camera!=null)main(()->{try{call("close",new Class[]{});}catch(Exception ignored){}});if(gl!=null)gl.post(()->{if(surface!=null)surface.release();render.quitSafely();});}
 try{report.put("passed",passed).put("checks",checks).put("sdk",Build.VERSION.SDK_INT).put("scope","Actual generated Camera2 offscreen preview and JPEG capture; no picker or UI actions");}catch(Exception ignored){}Bundle result=new Bundle();result.putString("resultJson",report.toString());finish(passed?-1:0,result);
 }
}
