/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent

/**
 * Android implementation of DCFScreen component
 * Handles screen presentation and navigation
 */
class DCFScreenComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScreenComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating screen component")
        
        val screenContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Store screen properties
        val route = props["route"] as? String
        val presentationStyle = props["presentationStyle"] as? String
        
        Log.d(TAG, "Screen created - route: $route, style: $presentationStyle")
        
        return screenContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating screen component")
        
        // Handle screen updates
        val route = props["route"] as? String
        val presentationStyle = props["presentationStyle"] as? String
        
        Log.d(TAG, "Screen updated - route: $route, style: $presentationStyle")
        
        return true
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "configureScreenForPush" -> {
                Log.d(TAG, "Configuring screen for push presentation")
                true
            }
            "configureScreenForModal" -> {
                Log.d(TAG, "Configuring screen for modal presentation")
                true
            }
            else -> null
        }
    }
}
