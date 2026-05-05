/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.app.Activity
import android.content.Context
import android.util.Log
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.utils.DCFScreenUtilities

class DcflightPlugin : FlutterPlugin, ActivityAware {

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

        DCFScreenUtilities.initialize(null, flutterPluginBinding.applicationContext)

        Log.d(TAG, "DCFlight plugin initialized - JNI bridge active")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        YogaShadowTree.shared.clearAll()
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        this.activity = null
        
        Log.d(TAG, "Activity detached but preserving native UI for background/foreground transitions")
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
}

