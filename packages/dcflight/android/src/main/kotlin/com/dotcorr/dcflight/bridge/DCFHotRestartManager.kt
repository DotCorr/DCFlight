/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Hot restart manager for DCFlight.
 * Called directly via JNI from Dart (no MethodChannel).
 */
class DCFHotRestartManager {

    companion object {
        private const val TAG = "DCFHotRestartManager"
        
        @JvmField
        val shared = DCFHotRestartManager()
        
        @JvmStatic
        private var sessionToken: String? = null
        
        @JvmStatic
        fun getSessionToken(): String? {
            return sessionToken
        }
        
        @JvmStatic
        fun createSessionToken(): String {
            val token = "dcf_session_${System.currentTimeMillis()}"
            sessionToken = token
            Log.d(TAG, "Created session token: $token")
            return token
        }
        
        @JvmStatic
        fun clearSessionToken() {
            Log.d(TAG, "Clearing session token")
            sessionToken = null
        }
        
        @JvmStatic
        fun cleanupViews() {
            Log.d(TAG, "Starting hot restart cleanup")
            
            Handler(Looper.getMainLooper()).post {
                try {
                    com.dotcorr.dcflight.layout.DCFLayoutManager.shared.prepareForHotRestart()
                    Log.d(TAG, "Layout manager prepared for hot restart")
                    
                    com.dotcorr.dcflight.layout.YogaShadowTree.shared.clearAll()
                    Log.d(TAG, "YogaShadowTree cleared")
                    
                    com.dotcorr.dcflight.layout.ViewRegistry.shared.clearAllExceptRoot()
                    Log.d(TAG, "ViewRegistry cleared (except root)")
                    
                    Log.d(TAG, "Hot restart cleanup completed successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error during hot restart cleanup", e)
                }
            }
        }
    }
}

