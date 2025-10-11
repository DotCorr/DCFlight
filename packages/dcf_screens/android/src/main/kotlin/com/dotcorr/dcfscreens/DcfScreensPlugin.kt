package com.dotcorr.dcfscreens

import android.app.Activity
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log

class DcfScreensPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    companion object {
        private const val TAG = "DcfScreensPlugin"
        private var instance: DcfScreensPlugin? = null
        
        fun getInstance(): DcfScreensPlugin? = instance
        fun getActivity(): Activity? = instance?.activity
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine called")
        
        // Store the instance
        instance = this
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dcf_screens")
        channel.setMethodCallHandler(this)
        
        // Register dcf_screens components
        registerComponents()
        
        Log.d(TAG, "DCFScreens plugin initialized")
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        instance = null
        activity = null
    }
    
    // ActivityAware implementation
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity called")
        activity = binding.activity
        Log.d(TAG, "✅ Activity attached: ${activity!!.javaClass.simpleName}")
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges called")
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges called")
        activity = binding.activity
        Log.d(TAG, "✅ Activity reattached: ${activity!!.javaClass.simpleName}")
    }
    
    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        activity = null
    }
    
    private fun registerComponents() {
        try {
            // Register dcf_screens specific components
            DCFScreensComponentsReg.registerComponents()
            Log.d(TAG, "DCFScreens components registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register DCFScreens components", e)
        }
    }
}
