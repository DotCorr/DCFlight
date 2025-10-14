/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry

/**
 * Root navigation bootstrapper component
 * Creates a FrameLayout container that holds the initial screen
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFStackBootstrapper"
        private const val INITIAL_DELAY_MS = 50L
        private const val MAX_RETRIES = 10
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val initialScreen = props["initialScreen"] as? String
        
        if (initialScreen == null) {
            Log.e(TAG, "❌ Missing required prop 'initialScreen'")
            return FrameLayout(context)
        }
        
        Log.d(TAG, "🚀 Setting up navigation with initial screen: $initialScreen")
        
        // Create a simple FrameLayout that will hold the initial screen
        // This is just a container - the actual screen FrameLayout will be attached by DCFlight's bridge
        val containerLayout = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Set up initial screen with retry logic
        setupInitialScreenWithRetry(
            initialScreen = initialScreen,
            container = containerLayout,
            retryCount = 0,
            maxRetries = MAX_RETRIES
        )
        
        Log.d(TAG, "✅ Navigation bootstrapper created")
        return containerLayout
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Navigation root doesn't need updates
        return true
    }
    
    private fun setupInitialScreenWithRetry(
        initialScreen: String,
        container: FrameLayout,
        retryCount: Int,
        maxRetries: Int
    ) {
        val screenContainer = DCFScreenRegistry.getScreen(initialScreen)
        if (screenContainer != null && screenContainer.frameLayout != null) {
            Log.d(TAG, "✅ Initial screen '$initialScreen' found!")
            DCFScreenRegistry.pushRoute(initialScreen)
            
            // CRITICAL: Don't manually add the screen to our container!
            // The bridge will attach all screens to root as siblings.
            // Instead, bring the initial screen to the front to make it visible!
            val screenFrameLayout = screenContainer.frameLayout!!
            
            // Bring to front makes it the topmost child in its parent (root)
            // This makes it visible above other screens
            Handler(Looper.getMainLooper()).post {
                screenFrameLayout.bringToFront()
                screenFrameLayout.requestLayout()
                Log.d(TAG, "🎯 Initial screen brought to front and displayed!")
            }
            
            return
        }
        
        if (retryCount < maxRetries) {
            val delayMs = minOf(INITIAL_DELAY_MS * (retryCount + 1), 500)
            Log.d(TAG, "⏳ Screen '$initialScreen' not ready, retry ${retryCount + 1}/$maxRetries in ${delayMs}ms")
            
            Handler(Looper.getMainLooper()).postDelayed({
                setupInitialScreenWithRetry(initialScreen, container, retryCount + 1, maxRetries)
            }, delayMs)
        } else {
            Log.e(TAG, "❌ Failed to find initial screen '$initialScreen' after $maxRetries attempts")
            Log.e(TAG, "Available routes: ${DCFScreenRegistry.getAllRoutes()}")
        }
    }
}