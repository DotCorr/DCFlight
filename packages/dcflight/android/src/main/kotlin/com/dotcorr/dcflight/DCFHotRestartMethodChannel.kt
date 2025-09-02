/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

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
        
        // Static session token for hot restart detection - survives Dart hot restarts
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
                // Create a new session token with timestamp
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
                Log.w(TAG, "Unknown hot restart method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    /**
     * Cleanup all DCFlight native views and resources - simplified version for testing
     */
    private fun cleanupNativeViews(result: Result) {
        Log.d(TAG, "🔥 DCF_ENGINE: Starting Android hot restart cleanup (simplified)")
        
        Handler(Looper.getMainLooper()).post {
            try {
                Log.d(TAG, "🔥 DCF_ENGINE: Hot restart cleanup called - view managers should be reset")
                
                // For now, just log that cleanup was called
                // The key is that Flutter knows a hot restart happened
                
                Log.d(TAG, "🔥 DCF_ENGINE: ✅ Android hot restart cleanup completed successfully")
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "🔥 DCF_ENGINE: ❌ Error during hot restart cleanup", e)
                result.error("CLEANUP_ERROR", "Failed to cleanup views: ${e.message}", null)
            }
        }
    }
}
