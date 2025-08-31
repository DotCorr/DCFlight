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

/** DcflightPlugin */
class DcflightPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    companion object {
        private const val TAG = "DcflightPlugin"

        @JvmStatic
        lateinit var instance: DcflightPlugin
            private set
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine called")
        instance = this
        this.flutterPluginBinding = flutterPluginBinding
        this.context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dcflight")
        channel.setMethodCallHandler(this)

        // Initialize method channels for bridge and events
        DCMauiBridgeMethodChannel.shared.initialize(flutterPluginBinding.binaryMessenger)
        DCMauiEventMethodHandler.shared.initialize(flutterPluginBinding.binaryMessenger)
        DCMauiLayoutMethodHandler.shared.initialize(flutterPluginBinding.binaryMessenger)

        Log.d(TAG, "DCFlight plugin initialized with method channels")
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initialize" -> {
                Log.d(TAG, "Initialize called from Dart")
                initializeDCFlight()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine called")
        channel.setMethodCallHandler(null)

        // Cleanup
        DCMauiBridgeMethodChannel.shared.cleanup()
        DCMauiEventMethodHandler.shared.cleanup()
        DCMauiLayoutMethodHandler.shared.cleanup()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity called")
        activity = binding.activity

        // Initialize DCFlight when activity is available
        activity?.let {
            DCDivergerUtil.divergeToFlight(it, flutterPluginBinding)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges called")
        // Handle configuration changes if needed
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges called")
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        activity = null
    }

    private fun initializeDCFlight() {
        Log.d(TAG, "Initializing DCFlight framework")

        // Register internal modules
        FrameworkComponentsReg.registerComponents()

        // Initialize core systems
        YogaShadowTree.shared.initialize()
        DCFLayoutManager.shared.initialize()
        DCFScreenUtilities.shared.initialize(flutterPluginBinding?.binaryMessenger)

        Log.d(TAG, "DCFlight framework initialized successfully")
    }
}
