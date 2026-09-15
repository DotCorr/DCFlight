"""Native bounded photo resources; no product flow or screen composition."""
from . import Artifact,HEADER
from urllib.parse import urlsplit,urlunsplit
import json


def artifacts(app):
    if not getattr(app,'media_states',()) and not any(n.capability=='remoteImage' for n in app.nodes()):return {}
    base=getattr(app,'transport',None);url=base.base_url.rstrip('/') if base else '';parts=urlsplit(url)
    if base and base.development and parts.hostname in ('localhost','127.0.0.1','::1'):url=urlunsplit((parts.scheme,'10.0.2.2'+(':'+str(parts.port) if parts.port else ''),parts.path,'',''))
    return {'android/app/src/main/java/'+app.id.replace('.','/')+'/NativeMedia.kt':Artifact(HEADER+NATIVE.replace('__PACKAGE__',app.id).replace('__BASE__',json.dumps(url).replace('$','\\$')))}


NATIVE=r'''package __PACKAGE__

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import androidx.compose.runtime.*
import java.io.*
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import androidx.compose.foundation.Image
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale

class NativePhoto internal constructor(internal val bytes:ByteArray,val width:Int,val height:Int)
data class NativePhotoOptions(val maxEdge:Int,val jpegQuality:Int,val maxInputBytes:Int,val maxOutputBytes:Int,val maxDecodedPixels:Int)
class NativeMedia(private val context:Context) {
    private val worker=Executors.newSingleThreadExecutor()
    private val main=android.os.Handler(android.os.Looper.getMainLooper())
    private val generation=AtomicInteger()
    @Volatile private var closed=false
    var launchRequest:Int? by mutableStateOf(null);private set
    private var pending:((NativePhoto?,Int)->Unit)?=null
    private var options:NativePhotoOptions?=null
    private var target:String?=null
    private var launched:Int?=null
    private val activeInput=java.util.concurrent.atomic.AtomicReference<InputStream?>()
    fun pick(name:String,value:NativePhotoOptions,done:(NativePhoto?,Int)->Unit) {
        cancel();if(closed)return
        // ActivityResult may still deliver an older picker result; never assign it to a new request.
        if(launched!=null){done(null,2);return}
        target=name;options=value;pending=done;launchRequest=generation.get()
    }
    fun markLaunched(token:Int):Boolean {if(token!=launchRequest||closed)return false;launchRequest=null;launched=token;return true}
    fun launchFailed(){launched=null;complete(generation.get(),null,2)}
    fun selected(uri:Uri?) {
        val token=launched?:return;launched=null
        if(closed||token!=generation.get())return
        if(uri==null){complete(token,null,1);return}
        val configured=options?:return
        val timeout=Runnable{if(token==generation.get()){try{activeInput.getAndSet(null)?.close()}catch(error:Exception){};complete(token,null,2)}}
        main.postDelayed(timeout,25000)
        try{worker.execute {
            var photo:NativePhoto?=null
            try{context.contentResolver.openInputStream(uri)?.use { activeInput.set(it);if(token==generation.get())photo=normalize(it,configured) }}catch(error:Exception){}
            activeInput.set(null);val result=photo;main.post{main.removeCallbacks(timeout);complete(token,result,if(result==null)2 else 0)}
        }}catch(error:java.util.concurrent.RejectedExecutionException){complete(token,null,2)}
    }
    private fun complete(token:Int,photo:NativePhoto?,result:Int){if(closed||token!=generation.get())return;val callback=pending;pending=null;target=null;options=null;launchRequest=null;callback?.invoke(photo,result)}
    fun clear(name:String){if(target==name)cancel()}
    fun cancel(){generation.incrementAndGet();try{activeInput.getAndSet(null)?.close()}catch(error:Exception){};pending=null;target=null;options=null;launchRequest=null;main.removeCallbacksAndMessages(null)}
    fun close(){closed=true;cancel();worker.shutdownNow()}
    companion object {
        fun readBounded(input:InputStream,maximum:Int):ByteArray {val output=ByteArrayOutputStream();val buffer=ByteArray(8192);while(true){if(Thread.currentThread().isInterrupted)throw IOException("media_cancelled");val n=input.read(buffer);if(n<0)break;if(output.size().toLong()+n>maximum)throw IOException("media_input_limit");output.write(buffer,0,n)};return output.toByteArray()}
        fun normalize(input:InputStream,p:NativePhotoOptions):NativePhoto {
            require(p.maxEdge>0&&p.jpegQuality in 1..100&&p.maxInputBytes>0&&p.maxOutputBytes>0&&p.maxDecodedPixels>0)
            val bytes=readBounded(input,p.maxInputBytes)
            val bounds=BitmapFactory.Options().also{it.inJustDecodeBounds=true};BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
            if(bounds.outWidth<=0||bounds.outHeight<=0)throw IOException("media_invalid_image")
            // Reject source pixel bombs before allocating a decoded bitmap.
            if(bounds.outWidth.toLong()*bounds.outHeight>p.maxDecodedPixels)throw IOException("media_pixel_limit")
            val decode=BitmapFactory.Options().also{it.inSampleSize=1};while(kotlin.math.max(bounds.outWidth,bounds.outHeight).toLong()/decode.inSampleSize>p.maxEdge.toLong()*2)decode.inSampleSize*=2
            var bitmap:Bitmap?=null
            try {
                bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size,decode)?:throw IOException("media_decode")
                val orientation=ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL)
                val matrix=Matrix();when(orientation){2->matrix.setScale(-1f,1f);3->matrix.setRotate(180f);4->matrix.setScale(1f,-1f);5->{matrix.setRotate(90f);matrix.postScale(-1f,1f)};6->matrix.setRotate(90f);7->{matrix.setRotate(270f);matrix.postScale(-1f,1f)};8->matrix.setRotate(270f)}
                val oriented=Bitmap.createBitmap(bitmap,0,0,bitmap.width,bitmap.height,matrix,true);if(oriented!==bitmap){bitmap.recycle();bitmap=oriented}
                val factor=kotlin.math.min(1.0,p.maxEdge.toDouble()/kotlin.math.max(bitmap.width,bitmap.height))
                if(factor<1){val scaled=Bitmap.createScaledBitmap(bitmap,kotlin.math.max(1,(bitmap.width*factor).toInt()),kotlin.math.max(1,(bitmap.height*factor).toInt()),true);if(scaled!==bitmap){bitmap.recycle();bitmap=scaled}}
                // JPEG has no alpha; shared normalization defines a white matte.
                if(bitmap.hasAlpha()){val opaque=Bitmap.createBitmap(bitmap.width,bitmap.height,Bitmap.Config.ARGB_8888);val canvas=android.graphics.Canvas(opaque);canvas.drawColor(android.graphics.Color.WHITE);canvas.drawBitmap(bitmap,0f,0f,null);bitmap.recycle();bitmap=opaque}
                val output=object:ByteArrayOutputStream(){override fun write(b:Int){if(count>=p.maxOutputBytes)throw IOException("media_output_limit");super.write(b)};override fun write(b:ByteArray,off:Int,len:Int){if(count.toLong()+len>p.maxOutputBytes)throw IOException("media_output_limit");super.write(b,off,len)}}
                if(!bitmap.compress(Bitmap.CompressFormat.JPEG,p.jpegQuality,output))throw IOException("media_encode")
                if(output.size()==0||output.size()>p.maxOutputBytes)throw IOException("media_output_limit")
                return NativePhoto(output.toByteArray(),bitmap.width,bitmap.height)
            }finally{bitmap?.recycle()}
        }
    }
}

private object NativeImageWorkers { val pool=java.util.concurrent.ThreadPoolExecutor(2,2,30,java.util.concurrent.TimeUnit.SECONDS,java.util.concurrent.ArrayBlockingQueue<Runnable>(128)) }
@Composable fun NativeRemoteImage(path:String,bearer:String,maxBytes:Int,maxPixels:Int,maxEdge:Int,modifier:Modifier,fit:ContentScale,label:String,loading:@Composable ()->Unit,failure:@Composable ()->Unit) {
    var bitmap by remember(path,bearer){mutableStateOf<Bitmap?>(null)}
    var failed by remember(path,bearer){mutableStateOf(false)}
    DisposableEffect(path,bearer,maxBytes,maxPixels,maxEdge) {
        val live=java.util.concurrent.atomic.AtomicBoolean(true)
        val active=java.util.concurrent.atomic.AtomicReference<java.net.HttpURLConnection?>()
        val main=android.os.Handler(android.os.Looper.getMainLooper())
        val delivered=java.util.concurrent.atomic.AtomicBoolean(false)
        val timeout=Runnable{if(live.get()&&delivered.compareAndSet(false,true)){active.get()?.disconnect();failed=true}}
        main.postDelayed(timeout,25000)
        var future:java.util.concurrent.Future<*>?=null
        try{future=NativeImageWorkers.pool.submit {
            var decoded:Bitmap?=null
            try {
                val connection=java.net.URL(__BASE__+path).openConnection() as java.net.HttpURLConnection;active.set(connection)
                if(!live.get())return@submit
                connection.instanceFollowRedirects=false;connection.connectTimeout=25000;connection.readTimeout=25000
                connection.setRequestProperty("Authorization","Bearer "+bearer)
                if(connection.responseCode !in 200..299)throw IOException("image_http")
                val raw=connection.inputStream.use {NativeMedia.readBounded(it,maxBytes)}
                val bounds=BitmapFactory.Options().also{it.inJustDecodeBounds=true};BitmapFactory.decodeByteArray(raw,0,raw.size,bounds)
                if(bounds.outWidth<=0||bounds.outHeight<=0||bounds.outWidth.toLong()*bounds.outHeight>maxPixels)throw IOException("image_dimensions")
                val options=BitmapFactory.Options().also{it.inSampleSize=1};while(kotlin.math.max(bounds.outWidth,bounds.outHeight)/options.inSampleSize>maxEdge.toLong()*2)options.inSampleSize*=2
                var prepared=BitmapFactory.decodeByteArray(raw,0,raw.size,options)?:throw IOException("image_decode")
                decoded=prepared
                val direction=ExifInterface(ByteArrayInputStream(raw)).getAttributeInt(ExifInterface.TAG_ORIENTATION,1)
                val transform=Matrix();when(direction){2->transform.setScale(-1f,1f);3->transform.setRotate(180f);4->transform.setScale(1f,-1f);5->{transform.setRotate(90f);transform.postScale(-1f,1f)};6->transform.setRotate(90f);7->{transform.setRotate(270f);transform.postScale(-1f,1f)};8->transform.setRotate(270f)}
                val oriented=Bitmap.createBitmap(prepared,0,0,prepared.width,prepared.height,transform,true);if(oriented!==prepared){prepared.recycle();prepared=oriented;decoded=prepared}
                val scale=kotlin.math.min(1.0,maxEdge.toDouble()/kotlin.math.max(prepared.width,prepared.height))
                if(scale<1){val scaled=Bitmap.createScaledBitmap(prepared,kotlin.math.max(1,(prepared.width*scale).toInt()),kotlin.math.max(1,(prepared.height*scale).toInt()),true);if(scaled!==prepared){prepared.recycle();decoded=scaled}}
            }catch(error:Exception){decoded?.recycle();decoded=null}finally{active.getAndSet(null)?.disconnect()}
            val result=decoded
            main.post{main.removeCallbacks(timeout);if(live.get()&&delivered.compareAndSet(false,true)){bitmap=result;failed=result==null}else result?.recycle()}
        }}catch(error:java.util.concurrent.RejectedExecutionException){main.removeCallbacks(timeout);failed=true}
        onDispose{live.set(false);main.removeCallbacksAndMessages(null);active.getAndSet(null)?.disconnect();future?.cancel(true);NativeImageWorkers.pool.purge();bitmap=null}
    }
    val value=bitmap
    if(value!=null)Image(value.asImageBitmap(),contentDescription=label,modifier=modifier,contentScale=fit)else if(failed)failure()else loading()
}

object NativePath {
    fun segment(value:String):String {val bytes=Charsets.UTF_8.newEncoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).encode(java.nio.CharBuffer.wrap(value));val hex="0123456789ABCDEF";val out=StringBuilder();while(bytes.hasRemaining()){val b=bytes.get().toInt() and 255;if(b in 65..90||b in 97..122||b in 48..57||b==45||b==46||b==95||b==126)out.append(b.toChar())else{out.append('%');out.append(hex[b ushr 4]);out.append(hex[b and 15])}};return out.toString()}
}
'''
