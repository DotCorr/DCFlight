/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Hot restart detection and cleanup method channel handler
 * Matches iOS implementation exactly
 */
class DCFHotRestartMethodChannel : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "DCFHotRestartMethodChannel"
        private const val CHANNEL_NAME = "dcflight/hot_restart"
        
        @JvmField
        val shared = DCFHotRestartMethodChannel()
        
        @JvmStatic
        private var sessionToken: String? = null
        
        fun initialize(binaryMessenger: BinaryMessenger) {
            val channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(shared)
            Log.d(TAG, "🔥 DCF_ENGINE: Hot restart channel initialized")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "🔥 DCF_ENGINE: Hot restart method called: ${call.method}")
        
        when (call.method) {
            "getSessionToken" -> {
                Log.d(TAG, "🔥 DCF_ENGINE: Getting session token: $sessionToken")
                result.success(sessionToken)
            }

            "createSessionToken" -> {
                val token = "dcf_session_${System.currentTimeMillis()}"
                sessionToken = token
                Log.d(TAG, "🔥 DCF_ENGINE: Created session token: $token")
                result.success(token)
            }

            "cleanupViews" -> {
                Log.d(TAG, "🔥 DCF_ENGINE: Starting hot restart cleanup")
                cleanupNativeViews(result)
            }

            "clearSessionToken" -> {
                Log.d(TAG, "🔥 DCF_ENGINE: Clearing session token")
                sessionToken = null
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Cleanup all DCFlight native views and resources - simple but effective
     */
    private fun cleanupNativeViews(result: Result) {
        Log.d(TAG, "🔥 DCF_ENGINE: Starting Android hot restart cleanup with flash prevention")
        
        Handler(Looper.getMainLooper()).post {
            try {
                com.dotcorr.dcflight.layout.DCFLayoutManager.shared.prepareForHotRestart()
                Log.d(TAG, "🔥 DCF_ENGINE: Layout manager prepared for hot restart")
                
                Log.d(TAG, "🔥 DCF_ENGINE: Clearing shadow tree and view registry")
                
                com.dotcorr.dcflight.layout.YogaShadowTree.shared.clearAll()
                Log.d(TAG, "🔥 DCF_ENGINE: YogaShadowTree cleared")
                
                com.dotcorr.dcflight.layout.ViewRegistry.shared.clearAllExceptRoot()
                Log.d(TAG, "🔥 DCF_ENGINE: ViewRegistry cleared (except root)")
                
                Log.d(TAG, "🔥 DCF_ENGINE: ✅ Android hot restart cleanup completed successfully")
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "🔥 DCF_ENGINE: ❌ Error during hot restart cleanup", e)
                result.error("CLEANUP_ERROR", "Failed to cleanup views: ${e.message}", null)
            }
        }
    }
}
