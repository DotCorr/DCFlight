/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.app.Activity
import android.content.Context
import android.util.Log
import com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler
import com.dotcorr.dcflight.components.FrameworkComponentsReg
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.utils.DCFScreenUtilities

class DcflightPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    companion object {
        private const val TAG = "DcflightPlugin"

        @JvmStatic
        lateinit var instance: DcflightPlugin
            private set
            
        @JvmStatic
        fun getPluginBinding(): FlutterPlugin.FlutterPluginBinding? {
            return if (::instance.isInitialized) {
                instance.flutterPluginBinding
            } else {
                null
            }
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine called")
        instance = this
        this.flutterPluginBinding = flutterPluginBinding
        this.context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dcflight")
        channel.setMethodCallHandler(this)

        DCFScreenUtilities.initialize(null, flutterPluginBinding.applicationContext)

        Log.d(TAG, "DCFlight plugin initialized - using JNI/FFI only")
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "divergeToFlight" -> {
                activity?.let { act ->
                    DCDivergerUtil.divergeToFlight(act, flutterPluginBinding)
                    result.success(true)
                } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        YogaShadowTree.shared.clearAll()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity called")
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges called")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges called")
        this.activity = binding.activity
    }
    
    private fun handleConfigurationChange(activity: Activity) {
        Log.d(TAG, "📱 Configuration changed - handling rotation/theme change")
        
        try {
            updateScreenDimensionsAfterRotation()
            
            DCFLayoutManager.shared.invalidateAllLayouts()
            YogaShadowTree.shared.calculateLayoutForAllRoots()
            
            propagateThemeChangeToAllComponents()
            
            Log.d(TAG, "✅ Configuration change handled successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to handle configuration change", e)
        }
    }
    
    private fun updateScreenDimensionsAfterRotation() {
        activity?.let { act ->
            val displayMetrics = act.resources.displayMetrics
            val newWidth = displayMetrics.widthPixels.toFloat()
            val newHeight = displayMetrics.heightPixels.toFloat()
            
            Log.d(TAG, "📐 Screen dimensions updated: ${newWidth}x${newHeight}")
            
            YogaShadowTree.shared.updateScreenRootDimensions(newWidth, newHeight)
        }
    }
    
    private fun propagateThemeChangeToAllComponents() {
        activity?.let { act ->
            Log.d(TAG, "🎨 Theme change propagated to all components")
        }
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        this.activity = null
        
        Log.d(TAG, "Activity detached but preserving native UI for background/foreground transitions")
    }
}

