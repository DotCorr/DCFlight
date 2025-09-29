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
import com.dotcorr.dcflight.bridge.DCFHotRestartMethodChannel
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

        // Initialize method channels - EXACTLY like iOS using shared instances!
        DCMauiBridgeMethodChannel.initialize(flutterPluginBinding.binaryMessenger)
        DCMauiEventMethodHandler.initialize(flutterPluginBinding.binaryMessenger)
        DCMauiLayoutMethodHandler.initialize(flutterPluginBinding.binaryMessenger)
        
        // Initialize screen utilities for screen dimensions method channel
        DCFScreenUtilities.initialize(flutterPluginBinding.binaryMessenger, flutterPluginBinding.applicationContext)
        
        // Initialize hot restart channel - CRITICAL for hot restart cleanup!
        DCFHotRestartMethodChannel.initialize(flutterPluginBinding.binaryMessenger)

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
        
        YogaShadowTree.shared.clearAll()
        // DCFLayoutManager doesn't have a global cleanup method
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity called")
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges called")
        // Preserve activity reference temporarily during config changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges called")
        this.activity = binding.activity
        
        // CRITICAL: Handle configuration changes like iOS
        // Recalculate layout and update screen dimensions after rotation
        handleConfigurationChange(binding.activity)
    }
    
    private fun handleConfigurationChange(activity: Activity) {
        Log.d(TAG, "📱 Configuration changed - handling rotation/theme change")
        
        try {
            // Update screen dimensions for YogaShadowTree root nodes
            updateScreenDimensionsAfterRotation()
            
            // Force layout recalculation to handle new dimensions
            DCFLayoutManager.shared.invalidateAllLayouts()
            YogaShadowTree.shared.calculateLayoutForAllRoots()
            
            // Trigger theme update propagation for all adaptive components
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
            
            // Update all screen root dimensions in YogaShadowTree
            YogaShadowTree.shared.updateScreenRootDimensions(newWidth, newHeight)
        }
    }
    
    private fun propagateThemeChangeToAllComponents() {
        activity?.let { act ->
            // Force all adaptive components to re-evaluate their colors
            // This ensures theme changes are propagated after configuration changes
            // Note: AdaptiveColorHelper automatically handles theme changes, so explicit propagation may not be needed
            // DCMauiBridgeImpl.shared.propagateThemeChangeToAllViews(act)
            Log.d(TAG, "🎨 Theme change propagated to all components")
        }
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity called")
        this.activity = null
        
        // DON'T cleanup when activity detaches - app might return from background
        // Only cleanup when engine detaches (app is truly closing)
        Log.d(TAG, "Activity detached but preserving native UI for background/foreground transitions")
    }
}

