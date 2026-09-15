"""Direct native permission/location operations; no application policy or UI copy."""
from . import Artifact,HEADER

def needed(app):return bool(getattr(app,'camera_resources',()) or getattr(app,'permission_descriptions',()) or getattr(app,'map_config',None))
def artifacts(app):
 if not needed(app):return {}
 return {'android/app/src/main/java/'+app.id.replace('.','/')+'/NativeDevice.kt':Artifact(HEADER+NATIVE.replace('__PACKAGE__',app.id))}

NATIVE=r'''package __PACKAGE__
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.compose.runtime.*

class NativeDevice(private val context:Context) {
    private val main=android.os.Handler(Looper.getMainLooper())
    var permissionRequest:String? by mutableStateOf(null);private set
    private var permissionCallback:((Int)->Unit)?=null
    private var permissionGeneration=0
    private var launchedPermission:Int?=null
    private var locationListener:LocationListener?=null
    private var locationGeneration=0
    private var closed=false
    private val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    companion object {fun roundAway(value:Double):Int {require(value.isFinite()&&value>=Int.MIN_VALUE.toDouble()&&value<=Int.MAX_VALUE.toDouble());return (if(value>=0)kotlin.math.floor(value+0.5)else kotlin.math.ceil(value-0.5)).toInt()}}
    private fun granted(name:String)=context.checkSelfPermission(name)==PackageManager.PERMISSION_GRANTED
    fun permissions(capability:String):Array<String> = if(capability=="camera")arrayOf(android.Manifest.permission.CAMERA)else arrayOf(android.Manifest.permission.ACCESS_COARSE_LOCATION,android.Manifest.permission.ACCESS_FINE_LOCATION)
    fun requestPermission(capability:String,done:(Int)->Unit){
        permissionGeneration++;permissionCallback=null;permissionRequest=null
        if(closed)return
        val restrictions=context.getSystemService(Context.USER_SERVICE) as android.os.UserManager
        if((capability=="camera" && (context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager).getCameraDisabled(null)) || (capability=="location" && restrictions.hasUserRestriction(android.os.UserManager.DISALLOW_SHARE_LOCATION))){done(3);return}
        if(capability=="camera"&&!context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)){done(4);return}
        if(capability=="location" && !(if(android.os.Build.VERSION.SDK_INT>=28)manager.isLocationEnabled else manager.isProviderEnabled(LocationManager.GPS_PROVIDER)||manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))){done(4);return}
        if(permissions(capability).any{granted(it)}){done(1);return}
        if(launchedPermission!=null){done(4);return}
        permissionCallback=done;permissionRequest=capability
    }
    fun permissionLaunched():Boolean{if(permissionRequest==null||closed)return false;launchedPermission=permissionGeneration;permissionRequest=null;return true}
    fun permissionResult(results:Map<String,Boolean>){val token=launchedPermission;launchedPermission=null;if(token!=permissionGeneration||closed)return;val callback=permissionCallback;permissionCallback=null;callback?.invoke(if(results.values.any{it})1 else 2)}
    fun permissionFailed(){val token=launchedPermission;launchedPermission=null;if(token!=permissionGeneration||closed)return;val callback=permissionCallback;permissionCallback=null;callback?.invoke(4)}
    fun locate(timeoutMs:Int,done:(Int?,Int?,Int?,Int)->Unit){
        cancelLocation();if(closed)return
        if(!granted(android.Manifest.permission.ACCESS_COARSE_LOCATION)&&!granted(android.Manifest.permission.ACCESS_FINE_LOCATION)){done(null,null,null,2);return}
        val provider=when{granted(android.Manifest.permission.ACCESS_FINE_LOCATION)&&manager.isProviderEnabled(LocationManager.GPS_PROVIDER)->LocationManager.GPS_PROVIDER;manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)->LocationManager.NETWORK_PROVIDER;else->null}
        if(provider==null){done(null,null,null,2);return}
        val token=locationGeneration
        val started=android.os.SystemClock.elapsedRealtimeNanos()
        fun complete(location:Location?){if(closed||token!=locationGeneration)return;cancelLocation();if(location==null||location.elapsedRealtimeNanos<started||!location.latitude.isFinite()||!location.longitude.isFinite()||location.latitude !in -90.0..90.0||location.longitude !in -180.0..180.0||!location.hasAccuracy()||!location.accuracy.isFinite()||location.accuracy<0||location.accuracy.toDouble()>Int.MAX_VALUE.toDouble()){done(null,null,null,2);return};done(roundAway(location.latitude*1000000),roundAway(location.longitude*1000000),kotlin.math.ceil(location.accuracy.toDouble()).toInt(),0)}
        val listener=object:LocationListener{override fun onLocationChanged(location:Location){complete(location)};override fun onProviderEnabled(provider:String){};override fun onProviderDisabled(provider:String){complete(null)};override fun onStatusChanged(provider:String,status:Int,extras:Bundle?) {}}
        locationListener=listener
        try{manager.requestSingleUpdate(provider,listener,Looper.getMainLooper());main.postDelayed({complete(null)},timeoutMs.toLong())}catch(error:Exception){complete(null)}
    }
    private fun cancelLocation(){locationGeneration++;locationListener?.let{try{manager.removeUpdates(it)}catch(error:Exception){}};locationListener=null;main.removeCallbacksAndMessages(null)}
    fun cancel(){permissionGeneration++;permissionCallback=null;permissionRequest=null;cancelLocation()}
    fun close(){closed=true;cancel()}
}
'''
