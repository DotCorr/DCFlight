package __PACKAGE__;

import android.app.Activity;
import android.graphics.*;
import android.hardware.camera2.*;
import android.media.ImageReader;
import android.os.*;
import android.util.Size;
import android.view.*;
import java.io.*;
import java.util.*;

/** A lifecycle-owned Camera2 preview/capture, emitting normalized still JPEGs. */
final class NativeCamera implements AutoCloseable {
    interface Photo { void ready(byte[] bytes); }
    interface Failure { void message(String text); }
    interface State { void changed(boolean ready,String message); }
    private final Activity activity; private final Photo photo; private final Failure failure; private final State state;
    private final TextureView texture; private HandlerThread thread; private Handler handler;
    private CameraDevice device; private CameraCaptureSession session; private ImageReader reader;
    private volatile boolean front, closed, opening; private int orientation; private Size previewSize; private Surface previewSurface; private int generation; private String cameraId;
    NativeCamera(Activity activity,Photo photo,Failure failure,State state){this.activity=activity;this.photo=photo;this.failure=failure;this.state=state;texture=new TextureView(activity);texture.setContentDescription("Live camera preview");texture.setSurfaceTextureListener(new TextureView.SurfaceTextureListener(){public void onSurfaceTextureAvailable(SurfaceTexture s,int w,int h){start();}public void onSurfaceTextureSizeChanged(SurfaceTexture s,int w,int h){}public boolean onSurfaceTextureDestroyed(SurfaceTexture s){closeDevice();return true;}public void onSurfaceTextureUpdated(SurfaceTexture s){}});}
    TextureView view(){return texture;}
    void start(){if(closed||opening||device!=null||!texture.isAvailable()||activity.checkSelfPermission(android.Manifest.permission.CAMERA)!=android.content.pm.PackageManager.PERMISSION_GRANTED)return;state.changed(false,"Starting camera…");if(thread==null){thread=new HandlerThread("native-camera");thread.start();handler=new Handler(thread.getLooper());}try{
        CameraManager manager=(CameraManager)activity.getSystemService(Activity.CAMERA_SERVICE);cameraId=null;
        for(String id:manager.getCameraIdList()){CameraCharacteristics c=manager.getCameraCharacteristics(id);Integer facing=c.get(CameraCharacteristics.LENS_FACING);if(facing!=null&&facing==(front?CameraCharacteristics.LENS_FACING_FRONT:CameraCharacteristics.LENS_FACING_BACK)){cameraId=id;break;}}
        if(cameraId==null)throw new IOException("Requested camera is not available");CameraCharacteristics c=manager.getCameraCharacteristics(cameraId);orientation=c.get(CameraCharacteristics.SENSOR_ORIENTATION);
        Size[] sizes=c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(ImageFormat.JPEG);Size size=sizes[0];for(Size candidate:sizes)if(candidate.getWidth()<=2048&&candidate.getHeight()<=2048&&(size.getWidth()>2048||size.getHeight()>2048||candidate.getWidth()*candidate.getHeight()>size.getWidth()*size.getHeight()))size=candidate;
        reader=ImageReader.newInstance(size.getWidth(),size.getHeight(),ImageFormat.JPEG,2);reader.setOnImageAvailableListener(source->{try(android.media.Image image=source.acquireLatestImage()){if(image==null)return;java.nio.ByteBuffer buffer=image.getPlanes()[0].getBuffer();byte[] raw=new byte[buffer.remaining()];buffer.get(raw);byte[] bytes=normalize(new ByteArrayInputStream(raw));activity.runOnUiThread(()->{if(!closed)photo.ready(bytes);});}catch(Exception error){report(error);}},handler);
        previewSize=c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(SurfaceTexture.class)[0];
        for(Size candidate:c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(SurfaceTexture.class))if(candidate.getWidth()<=1920&&candidate.getHeight()<=1080){previewSize=candidate;break;}
        final int expected=++generation;opening=true;manager.openCamera(cameraId,new CameraDevice.StateCallback(){public void onOpened(CameraDevice opened){opening=false;if(closed||expected!=generation){opened.close();return;}device=opened;preview();}public void onDisconnected(CameraDevice d){opening=false;d.close();device=null;report(new IOException("Camera disconnected. Retry when it is available."));}public void onError(CameraDevice d,int error){opening=false;d.close();device=null;report(new IOException("Camera error "+error));}},handler);
    }catch(Exception error){opening=false;report(error);}}
    private void preview(){try{texture.getSurfaceTexture().setDefaultBufferSize(previewSize.getWidth(),previewSize.getHeight());Surface surface=new Surface(texture.getSurfaceTexture());previewSurface=surface;CaptureRequest.Builder request=device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);request.addTarget(surface);device.createCaptureSession(Arrays.asList(surface,reader.getSurface()),new CameraCaptureSession.StateCallback(){public void onConfigured(CameraCaptureSession configured){if(closed||device==null){configured.close();surface.release();return;}session=configured;try{session.setRepeatingRequest(request.build(),null,handler);android.util.Log.i("NativeCamera","Preview capture session ready");activity.runOnUiThread(()->{if(!closed)state.changed(true,"");});}catch(Exception error){report(error);}}public void onConfigureFailed(CameraCaptureSession failed){surface.release();report(new IOException("Camera preview could not start"));}},handler);}catch(Exception error){report(error);}}
    void capture(){if(device==null||session==null){failure.message("Camera is not ready. Check camera permission.");return;}try{CaptureRequest.Builder request=device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);request.addTarget(reader.getSurface());int rotation=activity.getWindowManager().getDefaultDisplay().getRotation()*90;request.set(CaptureRequest.JPEG_ORIENTATION,(orientation+(front?rotation:-rotation)+360)%360);session.capture(request.build(),null,handler);}catch(Exception error){report(error);}}
    void flip(){front=!front;closeDevice();start();}
    private void report(Exception error){activity.runOnUiThread(()->{if(!closed)state.changed(false,"Camera unavailable. "+error.getMessage());});}
    private void closeDevice(){generation++;opening=false;if(session!=null){session.close();session=null;}if(device!=null){device.close();device=null;}if(reader!=null){reader.close();reader=null;}if(previewSurface!=null){previewSurface.release();previewSurface=null;}}
    public void close(){closed=true;closeDevice();if(thread!=null){thread.quitSafely();thread=null;}}
    static byte[] normalize(InputStream input)throws IOException{
        ByteArrayOutputStream source=new ByteArrayOutputStream();byte[] chunk=new byte[8192];int count;while((count=input.read(chunk))!=-1){if(source.size()+count>33554432)throw new IOException("Source photo exceeds 32 MiB");source.write(chunk,0,count);}byte[] raw=source.toByteArray();
        BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(raw,0,raw.length,options);if(options.outWidth<=0||options.outHeight<=0)throw new IOException("Unsupported photo");options.inJustDecodeBounds=false;options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>4096)options.inSampleSize*=2;Bitmap bitmap=BitmapFactory.decodeByteArray(raw,0,raw.length,options);if(bitmap==null)throw new IOException("Could not decode photo");
        android.media.ExifInterface exif=new android.media.ExifInterface(new ByteArrayInputStream(raw));int direction=exif.getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION,1);Matrix matrix=new Matrix();switch(direction){case 2:matrix.setScale(-1,1);break;case 3:matrix.setRotate(180);break;case 4:matrix.setScale(1,-1);break;case 5:matrix.setRotate(90);matrix.postScale(-1,1);break;case 6:matrix.setRotate(90);break;case 7:matrix.setRotate(270);matrix.postScale(-1,1);break;case 8:matrix.setRotate(270);break;}Bitmap oriented=Bitmap.createBitmap(bitmap,0,0,bitmap.getWidth(),bitmap.getHeight(),matrix,true);if(oriented!=bitmap)bitmap.recycle();bitmap=oriented;
        double scale=Math.min(1,2048.0/Math.max(bitmap.getWidth(),bitmap.getHeight()));if(scale<1){Bitmap smaller=Bitmap.createScaledBitmap(bitmap,Math.max(1,(int)(bitmap.getWidth()*scale)),Math.max(1,(int)(bitmap.getHeight()*scale)),true);bitmap.recycle();bitmap=smaller;}ByteArrayOutputStream output=new ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.JPEG,85,output);bitmap.recycle();return output.toByteArray();
    }
}
