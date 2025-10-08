/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log

class DcfScreensPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    companion object {
        private const val TAG = "DcfScreensPlugin"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine called")
        
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
