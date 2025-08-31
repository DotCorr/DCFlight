/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.dotcorr.dcflight.layout.YogaShadowTree

/**
 * CRITICAL FIX: Handles layout method channel interactions between Flutter and native Android
 * Now matches iOS DCMauiLayoutMethodHandler exactly
 */
class DCMauiLayoutMethodHandler private constructor() : MethodCallHandler {

    companion object {
        private const val TAG = "DCMauiLayoutMethodHandler"
        // CRITICAL FIX: Use EXACT iOS channel name
        private const val CHANNEL_NAME = "com.dcmaui.layout"

        @JvmStatic
        val shared = DCMauiLayoutMethodHandler()
    }

    private var methodChannel: MethodChannel? = null

    /**
     * Initialize with Flutter binary messenger - EXACT iOS pattern
     */
    fun initialize(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Initializing DCMauiLayoutMethodHandler")

        // Create method channel
        methodChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)

        // Set up method handler
        methodChannel?.setMethodCallHandler(this)

        Log.d(TAG, "DCMauiLayoutMethodHandler initialized successfully")
    }

    /**
     * Handle method calls from Flutter - matches iOS methods exactly
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Layout method call: ${call.method}")

        // Handle methods - layout channel supports both incoming and outgoing messages like iOS
        when (call.method) {
            "getScreenDimensions" -> {
                handleGetScreenDimensions(result)
            }

            "setUseWebDefaults" -> {
                handleSetUseWebDefaults(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Get screen dimensions - EXACT iOS implementation
     */
    private fun handleGetScreenDimensions(result: Result) {
        val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
        val dimensions = mapOf(
            "width" to displayMetrics.widthPixels.toDouble(),
            "height" to displayMetrics.heightPixels.toDouble(), 
            "scale" to displayMetrics.density.toDouble(),
            "statusBarHeight" to getStatusBarHeight().toDouble()
        )

        result.success(dimensions)
    }

    /**
     * Handle setUseWebDefaults method call - EXACT iOS implementation
     */
    private fun handleSetUseWebDefaults(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any>
        val enabled = args?.get("enabled") as? Boolean

        if (enabled == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "setUseWebDefaults requires 'enabled' boolean parameter",
                null
            )
            return
        }

        // Call YogaShadowTree to set web defaults like iOS
        YogaShadowTree.shared.setUseWebDefaults(enabled)
        result.success(true)
    }

    /**
     * Get status bar height for Android
     */
    private fun getStatusBarHeight(): Int {
        val resources = android.content.res.Resources.getSystem()
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiLayoutMethodHandler")
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        Log.d(TAG, "DCMauiLayoutMethodHandler cleanup complete")
    }
}

