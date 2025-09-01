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
import com.dotcorr.dcflight.bridge.DCMauiBridgeMethodChannel
import com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler
import com.dotcorr.dcflight.bridge.DCMauiLayoutMethodHandler
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

        // Initialize method channels - call the static initialize methods
        MethodChannel(flutterPluginBinding.binaryMessenger, "com.dcmaui.bridge")
            .setMethodCallHandler(DCMauiBridgeMethodChannel())

        MethodChannel(flutterPluginBinding.binaryMessenger, "com.dcmaui.events")
            .setMethodCallHandler(DCMauiEventMethodHandler())

        MethodChannel(flutterPluginBinding.binaryMessenger, "com.dcmaui.layout")
            .setMethodCallHandler(DCMauiLayoutMethodHandler.shared)

        Log.d(TAG, "DCFlight plugin initialized with method channels")
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
        
        YogaShadowTree.shared.cleanup()
        DCFLayoutManager.shared.cleanup()
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

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        this.activity = null
        
        YogaShadowTree.shared.cleanup()
        DCFLayoutManager.shared.cleanup()
    }
}