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

/**
 * Android implementation of DCFStackNavigationBootstrapper component
 * Handles stack-based navigation setup
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFStackNavigationBootstrapperComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating stack navigation bootstrapper component")
        
        val navigationContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Extract navigation properties
        val initialScreen = props["initialScreen"] as? String
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        val animationDuration = props["animationDuration"] as? Double
        
        Log.d(TAG, "StackNavigationBootstrapper created - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar, animationDuration: $animationDuration")
        
        // Set up initial navigation
        setupInitialNavigation(initialScreen)
        
        return navigationContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating stack navigation bootstrapper component")
        
        // Handle navigation updates
        val initialScreen = props["initialScreen"] as? String
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean
        
        Log.d(TAG, "StackNavigationBootstrapper updated - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar")
        
        return true
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "setupInitialScreen" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Setting up initial screen: $screenName")
                setupInitialNavigation(screenName)
                true
            }
            "navigateToScreen" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Navigating to screen: $screenName")
                true
            }
            "goBack" -> {
                Log.d(TAG, "Going back in navigation stack")
                true
            }
            else -> null
        }
    }
    
    private fun setupInitialNavigation(initialScreen: String?) {
        if (initialScreen != null) {
            Log.d(TAG, "Setting up initial navigation for screen: $initialScreen")
            // TODO: Implement actual navigation setup
        }
    }
}
