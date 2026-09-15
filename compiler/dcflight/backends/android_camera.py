"""Native Camera2 resource implementation, mounted by authored preview nodes."""
from . import Artifact,HEADER

def artifacts(app):
 if not getattr(app,'camera_resources',()):return {}
 return {'android/app/src/main/java/'+app.id.replace('.','/')+'/NativeCamera.kt':Artifact(HEADER+NATIVE.replace('__PACKAGE__',app.id))}

NATIVE=r'''package __PACKAGE__
import android.content.Context
import android.graphics.*
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.*
import android.util.Size
import android.view.*
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.*
import java.io.ByteArrayInputStream

class NativeCameraPort {
    private var camera:NativeCamera?=null
    fun attach(value:NativeCamera){camera?.close();camera=value}
    fun detach(value:NativeCamera){if(camera===value){camera=null;value.close()}}
    fun capture(options:NativePhotoOptions,done:(NativePhoto?,Int)->Unit){val value=camera;if(value==null)done(null,2)else value.capture(options,done)}
    fun facing(value:String,done:(Boolean)->Unit){val current=camera;if(current==null)done(false)else current.facing(value,done)}
}
class NativeCamera(private val texture:TextureView,private val fit:String,private val state:(Boolean,Boolean)->Unit):AutoCloseable {
    private val context=texture.context.applicationContext
    private val main=Handler(Looper.getMainLooper())
    private val thread=HandlerThread("native-camera").also{it.start()}
    private val worker=Handler(thread.looper)
    private val generation=java.util.concurrent.atomic.AtomicInteger()
    private var device:CameraDevice?=null
    private var session:CameraCaptureSession?=null
    private var reader:ImageReader?=null
    private var surface:Surface?=null
    private var pending:((NativePhoto?,Int)->Unit)?=null
    private var captureOptions:NativePhotoOptions?=null
    private var lens="back"
    private var captureId=0
    private var captureGeneration=0
    private var expectedTimestamp=0L
    private var bufferedTimestamp=0L
    private var bufferedPhoto:ByteArray?=null
    private var sensor=0
    private var autofocus=CaptureRequest.CONTROL_AF_MODE_OFF
    private var previewSize=Size(640,480)
    @Volatile private var enabled=false
    @Volatile private var closed=false
    private var opening=false
    private val displays=context.getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
    private val displayListener=object:android.hardware.display.DisplayManager.DisplayListener {override fun onDisplayAdded(id:Int){};override fun onDisplayRemoved(id:Int){};override fun onDisplayChanged(id:Int){if(texture.display?.displayId==id)transform()}}
    init {displays.registerDisplayListener(displayListener,main);texture.surfaceTextureListener=object:TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(value:SurfaceTexture,width:Int,height:Int){start()}
        override fun onSurfaceTextureSizeChanged(value:SurfaceTexture,width:Int,height:Int){transform()}
        override fun onSurfaceTextureDestroyed(value:SurfaceTexture):Boolean{stop();return true}
        override fun onSurfaceTextureUpdated(value:SurfaceTexture){}
    }}
    fun active(value:Boolean){enabled=value;if(value)start()else stop()}
    private fun update(token:Int,ready:Boolean,failed:Boolean){main.post{if(!closed&&token==generation.get())state(ready,failed)}}
    private fun start(){if(!enabled||closed||!texture.isAvailable)return;val token=generation.get();val displayRotation=(texture.display?.rotation?:0)*90
        worker.post {if(closed||!enabled||token!=generation.get()||device!=null||opening)return@post
            update(token,false,false)
            try {
                if(context.checkSelfPermission(android.Manifest.permission.CAMERA)!=android.content.pm.PackageManager.PERMISSION_GRANTED)throw IllegalStateException("camera_permission")
                val manager=context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val selected=manager.cameraIdList.firstOrNull {manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING)==if(lens=="front")CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK}?:throw IllegalStateException("camera_unavailable")
                val info=manager.getCameraCharacteristics(selected);sensor=info.get(CameraCharacteristics.SENSOR_ORIENTATION)?:0
                val focusModes=info.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)?:intArrayOf()
                autofocus=if(focusModes.contains(CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE))CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE else CaptureRequest.CONTROL_AF_MODE_OFF
                val config=info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?:throw IllegalStateException("camera_configuration")
                val sizes=config.getOutputSizes(ImageFormat.JPEG).filter{it.width.toLong()*it.height<=20000000}
                val size=sizes.filter{kotlin.math.max(it.width,it.height)<=4096}.maxByOrNull{it.width.toLong()*it.height}?:sizes.minByOrNull{it.width.toLong()*it.height}?:throw IllegalStateException("camera_size")
                val previews=config.getOutputSizes(SurfaceTexture::class.java)
                previewSize=previews.filter{it.width<=1920&&it.height<=1080}.minByOrNull{kotlin.math.abs(it.width.toDouble()/it.height-size.width.toDouble()/size.height)}?:previews.minByOrNull{it.width.toLong()*it.height}?:throw IllegalStateException("camera_preview_size")
                reader=ImageReader.newInstance(size.width,size.height,ImageFormat.JPEG,2).also{output->output.setOnImageAvailableListener({source->
                    try {source.acquireLatestImage()?.use {image->if(token!=generation.get()||pending==null)return@use;val buffer=image.planes[0].buffer;val options=captureOptions?:return@use;if(buffer.remaining()>options.maxInputBytes){complete(null,2);return@use};val raw=ByteArray(buffer.remaining());buffer.get(raw);bufferedTimestamp=image.timestamp;bufferedPhoto=raw;consumePhoto()}}catch(error:Exception){complete(null,2)}
                },worker)}
                opening=true
                manager.openCamera(selected,object:CameraDevice.StateCallback(){
                    override fun onOpened(value:CameraDevice){if(closed||token!=generation.get()){value.close();return};opening=false;device=value;configure(token)}
                    override fun onDisconnected(value:CameraDevice){value.close();if(token==generation.get()){opening=false;device=null;complete(null,2);update(token,false,true)}}
                    override fun onError(value:CameraDevice,error:Int){onDisconnected(value)}
                },worker)
                main.post{if(token==generation.get())transform()}
            }catch(error:Exception){opening=false;release();update(token,false,true)}
        }
    }
    private fun configure(token:Int){try{
        val device=device?:return;val source=texture.surfaceTexture?:throw IllegalStateException("camera_surface")
        source.setDefaultBufferSize(previewSize.width,previewSize.height);val preview=Surface(source);surface=preview
        val request=device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).also{it.addTarget(preview);it.set(CaptureRequest.CONTROL_AF_MODE,autofocus)}
        device.createCaptureSession(listOf(preview,reader!!.surface),object:CameraCaptureSession.StateCallback(){
            override fun onConfigured(value:CameraCaptureSession){if(closed||token!=generation.get()){value.close();return};session=value;try{value.setRepeatingRequest(request.build(),null,worker);update(token,true,false)}catch(error:Exception){release();update(token,false,true)}}
            override fun onConfigureFailed(value:CameraCaptureSession){value.close();if(token==generation.get()){release();update(token,false,true)}}
        },worker)
    }catch(error:Exception){release();update(token,false,true)}}
    private fun transform(){if(!texture.isAvailable||texture.width==0||texture.height==0)return
        val rotation=(texture.display?.rotation?:0)*90
        val degrees=(sensor+(if(lens=="front")rotation else -rotation)+360)%360
        val w=texture.width.toFloat();val h=texture.height.toFloat();val swap=degrees%180!=0
        val bw=(if(swap)previewSize.height else previewSize.width).toFloat();val bh=(if(swap)previewSize.width else previewSize.height).toFloat()
        val scale=if(fit=="fill")kotlin.math.max(w/bw,h/bh)else kotlin.math.min(w/bw,h/bh)
        val cx=previewSize.width/2f;val cy=previewSize.height/2f;val matrix=Matrix();matrix.setScale(previewSize.width/w,previewSize.height/h);matrix.postRotate(degrees.toFloat(),cx,cy);matrix.postScale(scale,scale,cx,cy);matrix.postTranslate(w/2-cx,h/2-cy);if(lens=="front")matrix.postScale(-1f,1f,w/2,h/2);texture.setTransform(matrix)
    }
    fun capture(options:NativePhotoOptions,done:(NativePhoto?,Int)->Unit){val rotation=(texture.display?.rotation?:0)*90
        worker.post{val camera=device;val capture=session;if(closed||!enabled||camera==null||capture==null||pending!=null){main.post{done(null,2)};return@post};pending=done;captureOptions=options;captureGeneration=generation.get();expectedTimestamp=0L;bufferedPhoto=null;val attempt=++captureId
            try{val request=camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);request.addTarget(reader!!.surface);request.set(CaptureRequest.JPEG_ORIENTATION,(sensor+(if(lens=="front")rotation else -rotation)+360)%360);capture.capture(request.build(),object:CameraCaptureSession.CaptureCallback(){override fun onCaptureStarted(session:CameraCaptureSession,request:CaptureRequest,timestamp:Long,frameNumber:Long){if(attempt==captureId){expectedTimestamp=timestamp;consumePhoto()}};override fun onCaptureFailed(session:CameraCaptureSession,request:CaptureRequest,failure:CaptureFailure){if(attempt==captureId)complete(null,2)}},worker);worker.postDelayed({if(attempt==captureId)complete(null,2)},15000)}catch(error:Exception){complete(null,2)}
        }
    }
    private fun consumePhoto(){if(expectedTimestamp==0L||bufferedPhoto==null)return;val raw=bufferedPhoto;bufferedPhoto=null;if(bufferedTimestamp!=expectedTimestamp)return;try{complete(NativeMedia.normalize(ByteArrayInputStream(raw!!),captureOptions?:return),0)}catch(error:Exception){complete(null,2)}}
    private fun complete(photo:NativePhoto?,result:Int){val callback=pending?:return;pending=null;captureOptions=null;bufferedPhoto=null;val code=if(captureGeneration!=generation.get())1 else result;main.post{callback(if(code==0)photo else null,code)}}
    fun facing(value:String,done:(Boolean)->Unit){try{val manager=context.getSystemService(Context.CAMERA_SERVICE) as CameraManager;val available=manager.cameraIdList.any{manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING)==if(value=="front")CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK};if(!available){done(false);return};lens=value;stop();start();done(true)}catch(error:Exception){done(false)}}
    fun stop(){val token=generation.incrementAndGet();state(false,false);worker.post{release();opening=false}}
    private fun release(){complete(null,1);session?.close();session=null;device?.close();device=null;reader?.close();reader=null;surface?.release();surface=null}
    override fun close(){if(closed)return;closed=true;enabled=false;generation.incrementAndGet();displays.unregisterDisplayListener(displayListener);texture.surfaceTextureListener=null;worker.post{release();thread.quitSafely()};main.removeCallbacksAndMessages(null)}
}

@androidx.compose.runtime.Composable fun NativeCameraPreview(port:NativeCameraPort,active:Boolean,fit:String,label:String,modifier:androidx.compose.ui.Modifier,readyChanged:(Boolean)->Unit,loading:@androidx.compose.runtime.Composable ()->Unit,failure:@androidx.compose.runtime.Composable ()->Unit){
    val context=androidx.compose.ui.platform.LocalContext.current
    val owner=androidx.lifecycle.compose.LocalLifecycleOwner.current
    var ready by androidx.compose.runtime.remember{androidx.compose.runtime.mutableStateOf(false)}
    var failed by androidx.compose.runtime.remember{androidx.compose.runtime.mutableStateOf(false)}
    val update by androidx.compose.runtime.rememberUpdatedState(readyChanged)
    val enabled by androidx.compose.runtime.rememberUpdatedState(active)
    val texture=androidx.compose.runtime.remember(context){TextureView(context).also{it.contentDescription=label}}
    val camera=androidx.compose.runtime.remember(texture,fit){NativeCamera(texture,fit){value,error->ready=value;failed=error;update(value)}}
    androidx.compose.runtime.DisposableEffect(camera,port,owner){port.attach(camera);val observer=androidx.lifecycle.LifecycleEventObserver{_,event->if(event==androidx.lifecycle.Lifecycle.Event.ON_RESUME)camera.active(enabled)else if(event==androidx.lifecycle.Lifecycle.Event.ON_PAUSE)camera.active(false)};owner.lifecycle.addObserver(observer);camera.active(active&&owner.lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED));onDispose{owner.lifecycle.removeObserver(observer);port.detach(camera);update(false)}}
    androidx.compose.runtime.LaunchedEffect(active){camera.active(active&&owner.lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED))}
    androidx.compose.foundation.layout.Box(modifier,contentAlignment=androidx.compose.ui.Alignment.CenterStart){if(active)androidx.compose.ui.viewinterop.AndroidView(factory={texture},modifier=androidx.compose.ui.Modifier.matchParentSize());if(!ready){if(failed)failure()else loading()}}
}
'''
