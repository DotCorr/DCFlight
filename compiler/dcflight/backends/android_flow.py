"""Compile typed shared effects into direct Kotlin methods and native IO adapters."""
from . import Artifact, HEADER
from .android_presentation import color
from ..ir import Reference, ScalarType
from ..native_operation import NATIVE_OPERATION_MAX_STRING_BYTES
from urllib.parse import urlsplit, urlunsplit
import hashlib
from .android_device import needed as device_needed


class AndroidFlow:
    def __init__(self,app,quote):
        self.app=app;self.quote=quote
        self.actions=getattr(app,'flow_actions',())
        self.types={state.name:state.initial.type for state in app.states}
        self.collections={c.name:c for c in getattr(app,'collections',())}
        self.media_states=getattr(app,'media_states',())
        self.devices=device_needed(app)

    def expression(self,value):
        if type(value).__name__=='MediaProjection':
            ref='m_'+value.value.name
            return '('+ref+' != null)' if value.operation=='hasMedia' else '('+ref+'?.'+{'mediaBytes':'bytes?.size','mediaWidth':'width','mediaHeight':'height'}[value.operation]+' ?: 0)'
        if type(value).__name__=='Projection':
            ref='s_'+value.value.name
            if value.operation=='flag':return '(if('+ref+') 1 else 0)'
            return ref+'.codePointCount(0,'+ref+'.length)' if value.operation=='length' else ref+'.toByteArray(Charsets.UTF_8).size'
        if isinstance(value,Reference):return 's_'+value.name
        if value.type==ScalarType.STRING:return self.quote(value.value)
        if value.type==ScalarType.BOOL:return str(value.value).lower()
        return str(value.value)

    def members(self):
        if not self.actions and not self.media_states and not self.devices:return ''
        result='private val effects = NativeEffects(context)\nvar initialDispatched=false\nvar effectFailure: String? by mutableStateOf(null)\noverride fun onCleared() { effects.close(); '+('media.close(); ' if self.media_states else '')+('devices.close(); ' if self.devices else '')+'navigationPorts.values.forEach { it.detach(false) }; navigationPorts.clear(); '+('timerHandler.removeCallbacksAndMessages(null); ' if getattr(self.app,'timers',()) else '')+'}\n'
        result+='private val navigationPorts=mutableMapOf<String,NativeNavigationPort>()\nfun navigationPort(id:String):NativeNavigationPort {val current=navigationPorts[id];if(current!=null&&current.alive)return current;return NativeNavigationPort().also{navigationPorts[id]=it}}\n'
        if self.media_states:result+='val media=NativeMedia(context)\n'+''.join('private var mediaVersion_'+v.name+'=0\n' for v in self.media_states)
        if self.devices:result+='val devices=NativeDevice(context)\n'
        result+=''.join('val camera_'+r.id+'=NativeCameraPort()\n' for r in getattr(self.app,'camera_resources',()))
        if getattr(self.app,'timers',()):
            result+='private val timerHandler=android.os.Handler(android.os.Looper.getMainLooper())\ninit { '+''.join('timerHandler.postDelayed(object:Runnable { override fun run(){ f_'+t.action+' {}; timerHandler.postDelayed(this,'+str(t.interval_ms)+'L) } },'+str(t.interval_ms)+'L);' for t in self.app.timers)+' }\n'
        for action in self.actions:
            cases=[]
            for case in action.cases:
                body='\n'.join(self.effect(effect) for effect in case.effects)
                cases.append(str(case.code)+' -> { '+body+' }')
            decision='0';prefix=''
            if action.function:
                signature=next(f for f in self.app.logic.functions if f.name==action.function)
                call='SharedLogic.f_'+action.function+'('+','.join(self.expression(v) for v in action.arguments)+')'
                decision='if('+call+') 1 else 0' if signature.returns.value=='bool' else call
                if action.failure:
                    prefix='val policyCode = try { '+decision+' } catch (error: SharedLogic.InputFailure) { f_'+action.failure+'(navigate); return }; '
                    decision='policyCode'
            result+='fun f_'+action.id+'(navigate: (String) -> Unit) { effectFailure=null; '+prefix+'when('+decision+') { '+'\n'.join(cases)+'\nelse -> { effectFailure="unknown_flow_result"; return } } }\n'
        return result

    def effect(self,effect):
        kind=type(effect).__name__
        if kind=='ClearCollectionEffect':return 'c_'+effect.target+' = emptyList()'
        if kind=='ClockEffect':return 'run { val seconds=System.currentTimeMillis()/1000L; if(seconds !in 0L..Int.MAX_VALUE.toLong()) { f_'+effect.failure+'(navigate); return }; s_'+effect.target+'=seconds.toInt() }'
        if kind=='ReadCollectionEffect':
            output='val selected=c_'+effect.collection+'.firstOrNull { it.v_'+self.collections[effect.collection].key+' == '+self.expression(effect.key)+' }; if(selected==null) { f_'+effect.failure+'(navigate); return }; '
            output+=';'.join('val copy'+str(i)+'=selected.v_'+o.path[0] for i,o in enumerate(effect.outputs))+'; '
            output+=';'.join('s_'+o.target+'=copy'+str(i) for i,o in enumerate(effect.outputs))+'; f_'+effect.success+'(navigate)'
            return output
        if kind=='SetEffect':return 's_'+effect.target+' = '+self.expression(effect.value)
        if kind=='NavigateEffect':return 'navigate('+self.quote(effect.action)+')'
        if kind=='InvokeEffect':return 'f_'+effect.action+'(navigate); return'
        if kind=='CancelEffect':return 'effects.cancelAll()'+('; media.cancel()' if self.media_states else '')+('; devices.cancel()' if self.devices else '')+''.join('; mediaVersion_'+v.name+'++' for v in self.media_states)
        if kind=='PermissionEffect':return 'effects.cancel(); devices.requestPermission('+self.quote(effect.capability)+') { code -> if(navigate is NativeNavigationPort && !navigate.alive)return@requestPermission; s_'+effect.status_target+'=code; if(code==1)f_'+effect.success+'(navigate) else f_'+effect.failure+'(navigate) }'
        if kind=='LocationEffect':return 'effects.cancel(); devices.locate('+str(effect.timeout_ms)+') { latitude,longitude,accuracy,result -> if(navigate is NativeNavigationPort && !navigate.alive)return@locate; if(result==0) { s_'+effect.latitude_target+'=latitude!!; s_'+effect.longitude_target+'=longitude!!; s_'+effect.accuracy_target+'=accuracy!!; f_'+effect.success+'(navigate) } else if(result==1)f_'+effect.cancel+'(navigate) else f_'+effect.failure+'(navigate) }'
        if kind=='CameraFacingEffect':return 'camera_'+effect.resource+'.facing('+self.quote(effect.facing)+') { ready -> if(ready) f_'+effect.success+'(navigate) else f_'+effect.failure+'(navigate) }'
        if kind=='CapturePhotoEffect':
            p=effect.options;options='NativePhotoOptions('+','.join(str(getattr(p,n)) for n in ('max_edge','jpeg_quality','max_input_bytes','max_output_bytes','max_decoded_pixels'))+')'
            return 'val mediaVersion=++mediaVersion_'+effect.target+'; effects.cancel(); camera_'+effect.resource+'.capture('+options+') { photo,result -> if(mediaVersion!=mediaVersion_'+effect.target+')return@capture; if(navigate is NativeNavigationPort && !navigate.alive)return@capture; if(result==0) { m_'+effect.target+'=photo; f_'+effect.success+'(navigate) } else if(result==1)f_'+effect.cancel+'(navigate) else f_'+effect.failure+'(navigate) }'
        if kind=='ClearMediaEffect':return 'mediaVersion_'+effect.target+'++; media.clear('+self.quote(effect.target)+'); m_'+effect.target+' = null'
        if kind=='PickPhotoEffect':
            p=effect.options
            options='NativePhotoOptions('+','.join(str(getattr(p,n)) for n in ('max_edge','jpeg_quality','max_input_bytes','max_output_bytes','max_decoded_pixels'))+')'
            return 'val mediaVersion=++mediaVersion_'+effect.target+'; effects.cancel(); media.pick('+self.quote(effect.target)+','+options+') { photo,result -> if(mediaVersion!=mediaVersion_'+effect.target+')return@pick; if(navigate is NativeNavigationPort && !navigate.alive) return@pick; when(result) { 0 -> { m_'+effect.target+'=photo; f_'+effect.success+'(navigate) }; 1 -> f_'+effect.cancel+'(navigate); else -> f_'+effect.failure+'(navigate) } }'
        if kind=='LogicCallEffect':
            from ..shared_logic import call_expression
            call=call_expression(self.app,effect,'android',lambda item,prefix:self.expression(item))
            return 'val logicResult = try { '+call+' } catch(error: Exception) { f_'+effect.failure+'(navigate); return }; s_'+effect.target+' = logicResult; f_'+effect.success+'(navigate); return'
        if kind=='NativeOperationEffect':
            contract=next((op for op in getattr(self.app,'native_operations',()) if op.name==effect.operation),None)
            if contract is None:raise ValueError('Unknown Android native operation: '+effect.operation)
            if len(effect.arguments)!=len(contract.parameters):raise ValueError('Android native operation argument count mismatch')
            if self.types.get(effect.target)!=contract.result:raise ValueError('Android native operation result type mismatch')
            worker=getattr(contract,'execution','main')=='worker'
            deferred=worker or getattr(contract,'suspends',False)
            snapshots='; '.join('val nativeInput'+str(i)+' = '+self.expression(v) for i,v in enumerate(effect.arguments))
            inputs=['nativeInput'+str(i) for i in range(len(effect.arguments))] if deferred else [self.expression(v) for v in effect.arguments]
            call='NativeOperation_'+contract.name+'.invoke('+','.join(inputs)+')'
            if contract.result==ScalarType.STRING:call='effects.nativeString('+call+')'
            native_type={ScalarType.STRING:'String',ScalarType.INT:'Int',ScalarType.BOOL:'Boolean'}[contract.result]
            if deferred:
                method='nativeOperation' if worker else 'nativeOperationMain'
                return 'run { effects.assertNativeMain(); '+(snapshots+'; ' if snapshots else '')+'effects.'+method+'({ '+call+' }, { nativeResult: '+native_type+' -> if(navigate !is NativeNavigationPort || navigate.alive) { s_'+effect.target+' = nativeResult; f_'+effect.success+'(navigate) } }, { if(navigate !is NativeNavigationPort || navigate.alive) f_'+effect.failure+'(navigate) }); }; return'
            return 'val nativeResult: '+native_type+' = try { '+call+' } catch(error: Exception) { f_'+effect.failure+'(navigate); return }; s_'+effect.target+' = nativeResult; f_'+effect.success+'(navigate); return'
        if kind=='SecureEffect':
            key=self.quote(effect.key)
            if effect.operation=='read':line='s_'+effect.target+' = effects.read('+key+')'
            elif effect.operation=='write':line='effects.write('+key+',s_'+effect.target+')'
            else:line='effects.delete('+key+')'
            return 'try { '+line+' } catch(error: Exception) { f_'+effect.failure+'(navigate); return }'
        if kind!='RequestEffect':raise ValueError('Unsupported Android effect: '+kind)
        media_body=type(effect.body).__name__=='MediaBody'
        body=('m_'+effect.body.source.name+' ?: throw IllegalArgumentException("media_empty")') if media_body else 'org.json.JSONObject()'+''.join('.put('+self.quote(key)+','+self.expression(value)+')' for key,value in (() if media_body else effect.body))
        bearer=self.expression(effect.bearer) if effect.bearer else 'null'
        success=[];assign=[]
        for i,output in enumerate(effect.outputs):
            path='listOf('+','.join(self.quote(part) for part in output.path)+')'
            if output.target in self.collections:
                collection=self.collections[output.target]
                fields=[]
                for field in collection.fields:
                    getter={ScalarType.STRING:'string',ScalarType.INT:'integer',ScalarType.BOOL:'boolean'}[field.type]
                    field_path='listOf('+self.quote(field.name)+')'
                    value='effects.'+getter+'(row,'+field_path+')'
                    if field.default is not None:value='if(row.isNull('+self.quote(field.name)+')) '+self.expression(field.default)+' else '+value
                    fields.append('v_'+field.name+'='+value)
                success.append('val output'+str(i)+' = effects.array(json!!,'+path+').let { array -> val keys=mutableSetOf<Any>(); List(array.length()) { index -> val row=array.get(index) as? org.json.JSONObject ?: throw IllegalArgumentException("response_row"); Record_'+collection.name+'('+','.join(fields)+').also { if(!keys.add(it.v_'+collection.key+')) throw IllegalArgumentException("response_duplicate_key") } } }')
                if getattr(output,'mode','replace')=='append':
                    success[-1]+='.let { incoming -> val priorKeys=c_'+collection.name+'.map { it.v_'+collection.key+' }.toHashSet(); if(incoming.any { it.v_'+collection.key+' in priorKeys }) throw IllegalArgumentException("response_duplicate_existing_key"); c_'+collection.name+' + incoming }'
                assign.append('c_'+output.target+' = output'+str(i))
            else:
                decoder={ScalarType.STRING:'string',ScalarType.INT:'integer',ScalarType.BOOL:'boolean'}[self.types[output.target]]
                success.append('val output'+str(i)+' = effects.'+decoder+'(json!!,'+path+')')
                assign.append('s_'+output.target+' = output'+str(i))
        status='s_'+effect.status_target+' = status\n' if effect.status_target else ''
        failure_status='s_'+effect.status_target+' = 0\n' if effect.status_target else ''
        # Response decoding is atomic: all temporaries validate before any state assignment.
        path=self.quote(effect.path) if isinstance(effect.path,str) else '+'.join(self.quote(part.value) if not isinstance(part,Reference) else 'effects.pathSegment('+self.expression(part)+'.toString())' for part in effect.path.parts)
        code='effects.request('+self.quote(effect.method)+','+path+','+body+','+bearer+') { json,status ->\nif(navigate is NativeNavigationPort && !navigate.alive) return@request;\n'+status+'if(status in 200..299) {\n'
        code+='try { '+'\n'.join(success)+'\n'+'\n'.join(assign)+' } catch(error: Exception) { '+failure_status+'f_'+effect.failure+'(navigate); return@request }\nf_'+effect.success+'(navigate)\n} else { f_'+effect.failure+'(navigate) }\n}'
        return 'try { '+code+' } catch(error: Exception) { '+failure_status+'f_'+effect.failure+'(navigate) }'

    def artifacts(self):
        if not self.actions and not self.media_states and not self.devices:return {}
        base=getattr(self.app,'transport',None)
        url=base.base_url.rstrip('/') if base else ''
        parts=urlsplit(url)
        if base and base.development and parts.hostname in ('localhost','127.0.0.1','::1'):
            url=urlunsplit((parts.scheme,'10.0.2.2'+(':'+str(parts.port) if parts.port else ''),parts.path,'',''))
        native=NATIVE.replace('__BODY_BYTES__','if(body is NativePhoto)body.bytes else (body as JSONObject).toString().toByteArray(Charsets.UTF_8)' if self.media_states else '(body as JSONObject).toString().toByteArray(Charsets.UTF_8)').replace('__BODY_TYPE__','if(body is NativePhoto)"image/jpeg" else "application/json"' if self.media_states else '"application/json"')
        source=HEADER+(native+'\n'+NATIVE_WORKER).replace('__PACKAGE__',self.app.id).replace('__BASE__',self.quote(url)).replace('__SCOPE__',hashlib.sha256(url.encode()).hexdigest())
        return {'android/app/src/main/java/'+self.app.id.replace('.','/')+'/NativeEffects.kt':Artifact(source)}


NATIVE=r'''package __PACKAGE__

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64

/** Ordinary app-owned native execution; no graph, registry or application flow is interpreted. */
class NativeEffects(private val context: Context) {
    private val worker=Executors.newSingleThreadExecutor()
    private val main=android.os.Handler(android.os.Looper.getMainLooper())
    private val operationMain=android.os.Handler(android.os.Looper.getMainLooper())
    private val operationWorker=NativeOperationWorker({ callback -> operationMain.post { callback() }; Unit }, { check(android.os.Looper.myLooper()==android.os.Looper.getMainLooper()) })
    fun assertNativeMain() { check(android.os.Looper.myLooper()==android.os.Looper.getMainLooper()) }
    fun <T> nativeOperationMain(operation:()->T,success:(T)->Unit,failure:()->Unit) { operationWorker.submitMain(operation,success,failure) }
    fun <T> nativeOperation(operation:()->T,success:(T)->Unit,failure:()->Unit) { operationWorker.submit(operation,success,failure) }
    private val generation=AtomicInteger()
    @Volatile private var closed=false
    @Volatile private var active: HttpURLConnection?=null
    fun cancelAll() { operationWorker.cancel();cancel() }
    fun cancel() { generation.incrementAndGet(); active?.disconnect(); active=null;main.removeCallbacksAndMessages(null) }
    fun close() { closed=true;cancel();operationWorker.close();operationMain.removeCallbacksAndMessages(null);worker.shutdownNow();main.removeCallbacksAndMessages(null) }
    fun request(method:String,path:String,body:Any,bearer:String?,completion:(JSONObject?,Int)->Unit) {
        if(closed)return
        cancel();val token=generation.get()
        val delivered=java.util.concurrent.atomic.AtomicBoolean(false)
        val timeout=Runnable { if(!closed&&token==generation.get()&&delivered.compareAndSet(false,true)){active?.disconnect();completion(null,0)} }
        main.postDelayed(timeout,25000)
        try { worker.execute {
            if(closed||token!=generation.get())return@execute
            var connection:HttpURLConnection?=null;var json:JSONObject?=null;var status=0
            try {
                connection=URL(__BASE__+path).openConnection() as HttpURLConnection
                active=connection
                if(closed||token!=generation.get())return@execute
                connection.connectTimeout=25000;connection.readTimeout=25000;connection.instanceFollowRedirects=false;connection.requestMethod=method
                if(bearer!=null)connection.setRequestProperty("Authorization","Bearer "+bearer)
                if(method!="GET"&&method!="HEAD") {
                    val bytes=__BODY_BYTES__
                    connection.setRequestProperty("Content-Type",__BODY_TYPE__);connection.doOutput=true;connection.setFixedLengthStreamingMode(bytes.size)
                    connection.outputStream.use { it.write(bytes) }
                }
                status=connection.responseCode
                val stream=if(status>=400)connection.errorStream else connection.inputStream
                val output=java.io.ByteArrayOutputStream()
                stream?.use { input -> val buffer=ByteArray(8192);while(true){val count=input.read(buffer);if(count<0)break;if(output.size()+count>8388608)throw java.io.IOException("response_limit");output.write(buffer,0,count)} }
                if(status in 200..299)json=if(output.size()==0)JSONObject() else JSONObject(Charsets.UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT).decode(java.nio.ByteBuffer.wrap(output.toByteArray())).toString())
            }catch(error:Exception){status=0}
            finally{connection?.disconnect();if(active===connection)active=null}
            val result=json;val code=status
            if(!closed&&token==generation.get())main.post { main.removeCallbacks(timeout);if(!closed&&token==generation.get()&&delivered.compareAndSet(false,true))completion(result,code) }
        } } catch(error:java.util.concurrent.RejectedExecutionException) { main.removeCallbacks(timeout);if(!closed&&token==generation.get())main.post { if(!closed&&token==generation.get())completion(null,0) } }
    }
    private fun value(json:JSONObject,path:List<String>):Any {var result:Any=json;for(part in path)result=(result as? JSONObject)?.get(part)?:throw IllegalArgumentException("response_path");return result}
    fun nativeString(value:String?):String {val text=value?:throw IllegalArgumentException("native_result_null");if(text.length>__NATIVE_OPERATION_MAX_STRING_BYTES__)throw IllegalArgumentException("native_result_limit");val encoded=Charsets.UTF_8.newEncoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT).encode(java.nio.CharBuffer.wrap(text));if(encoded.remaining()>__NATIVE_OPERATION_MAX_STRING_BYTES__)throw IllegalArgumentException("native_result_limit");return text}
    fun string(json:JSONObject,path:List<String>):String {val text=value(json,path) as? String?:throw IllegalArgumentException("response_string");Charsets.UTF_8.newEncoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT).encode(java.nio.CharBuffer.wrap(text));return text}
    fun boolean(json:JSONObject,path:List<String>):Boolean=value(json,path) as? Boolean?:throw IllegalArgumentException("response_boolean")
    fun integer(json:JSONObject,path:List<String>):Int {val v=value(json,path);if(v is Int)return v;if(v is Long&&v in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong())return v.toInt();throw IllegalArgumentException("response_integer")}
    fun array(json:JSONObject,path:List<String>):org.json.JSONArray=value(json,path) as? org.json.JSONArray?:throw IllegalArgumentException("response_array")
    fun pathSegment(value:String):String {
        val bytes=Charsets.UTF_8.newEncoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT).encode(java.nio.CharBuffer.wrap(value))
        val hex="0123456789ABCDEF";val out=StringBuilder()
        while(bytes.hasRemaining()){val b=bytes.get().toInt() and 255;if(b in 65..90||b in 97..122||b in 48..57||b==45||b==46||b==95||b==126)out.append(b.toChar()) else {out.append('%');out.append(hex[b ushr 4]);out.append(hex[b and 15])}}
        return out.toString()
    }
    private fun key():SecretKey {
        val alias=context.packageName+".secure.effects.__SCOPE__";val store=java.security.KeyStore.getInstance("AndroidKeyStore");store.load(null)
        if(!store.containsAlias(alias)){val generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");generator.init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());generator.generateKey()}
        return store.getKey(alias,null) as SecretKey
    }
    fun write(name:String,value:String) {
        val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key())
        val encrypted=Base64.encodeToString(cipher.iv,Base64.NO_WRAP)+":"+Base64.encodeToString(cipher.doFinal(value.toByteArray(Charsets.UTF_8)),Base64.NO_WRAP)
        if(!context.getSharedPreferences("secure_effects___SCOPE__",Context.MODE_PRIVATE).edit().putString(name,encrypted).commit())throw java.io.IOException("secure_write")
    }
    fun read(name:String):String {
        val raw=context.getSharedPreferences("secure_effects___SCOPE__",Context.MODE_PRIVATE).getString(name,null)?:return ""
        val parts=raw.split(":",limit=2);val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,Base64.decode(parts[0],Base64.NO_WRAP)))
        return Charsets.UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT).decode(java.nio.ByteBuffer.wrap(cipher.doFinal(Base64.decode(parts[1],Base64.NO_WRAP)))).toString()
    }
    fun delete(name:String) {if(!context.getSharedPreferences("secure_effects___SCOPE__",Context.MODE_PRIVATE).edit().remove(name).commit())throw java.io.IOException("secure_delete")}
}
'''

NATIVE=NATIVE.replace('__NATIVE_OPERATION_MAX_STRING_BYTES__',str(NATIVE_OPERATION_MAX_STRING_BYTES))

NAVIGATION=r'''
/** A retained request refers to its original host identity, never an Activity/controller. */
class NativeNavigationPort : (String)->Unit {
    private var destination:((String)->Unit)?=null
    private val pending=java.util.ArrayDeque<String>()
    private val main=android.os.Handler(android.os.Looper.getMainLooper())
    var alive=true;private set
    fun attach(callback:(String)->Unit){if(!alive)return;main.removeCallbacksAndMessages(null);alive=true;destination=callback;while(pending.isNotEmpty())callback(pending.removeFirst())}
    fun detach(configurationChange:Boolean){destination=null;if(configurationChange){main.postDelayed({alive=false;pending.clear()},5000)}else{alive=false;pending.clear();main.removeCallbacksAndMessages(null)}}
    override fun invoke(action:String){if(!alive)return;val callback=destination;if(callback!=null)callback(action)else if(pending.size<16)pending.addLast(action)else{alive=false;pending.clear()}}
}
'''


NATIVE_WORKER=r'''/** Latest invocation wins; only immutable scalar snapshots enter this executor. */
class NativeOperationWorker(private val publish: (()->Unit)->Unit, private val assertMain: ()->Unit) {
    private val generation=java.util.concurrent.atomic.AtomicLong()
    private val active=java.util.concurrent.atomic.AtomicReference<Thread?>()
    private val executor=java.util.concurrent.ThreadPoolExecutor(1,1,0L,java.util.concurrent.TimeUnit.MILLISECONDS,java.util.concurrent.ArrayBlockingQueue<Runnable>(1))
    @Volatile private var closed=false
    private var pendingMain:(()->Unit)?=null
    private var mainScheduled=false
    fun cancel() { assertMain(); pendingMain=null;generation.incrementAndGet(); executor.queue.clear(); active.get()?.interrupt() }
    fun close() { assertMain(); closed=true;cancel();executor.shutdownNow() }
    fun <T> submitMain(operation:()->T,success:(T)->Unit,failure:()->Unit) {
        assertMain();if(closed)return
        cancel();val token=generation.get()
        pendingMain=action@{
            assertMain();if(closed||token!=generation.get())return@action
            val result:T
            try { result=operation() }
            catch(error:Exception) { if(!closed&&token==generation.get())failure();return@action }
            if(!closed&&token==generation.get())success(result)
        }
        if(!mainScheduled) {
            mainScheduled=true
            publish { assertMain();mainScheduled=false;val next=pendingMain;pendingMain=null;next?.invoke() }
        }
    }
    fun <T> submit(operation:()->T,success:(T)->Unit,failure:()->Unit) {
        assertMain();if(closed)return
        cancel();val token=generation.get()
        val task=Runnable {
            Thread.interrupted()
            active.set(Thread.currentThread())
            try {
                if(closed||token!=generation.get())return@Runnable
                val result: T
                try { result=operation() }
                catch(error:Exception) {
                    publish { assertMain();if(!closed&&token==generation.get())failure() }
                    return@Runnable
                }
                publish { assertMain();if(!closed&&token==generation.get())success(result) }
            } finally { active.compareAndSet(Thread.currentThread(),null) }
        }
        try { executor.execute(task) }
        catch(error:java.util.concurrent.RejectedExecutionException) { if(!closed&&token==generation.get())failure() }
    }
}
'''
