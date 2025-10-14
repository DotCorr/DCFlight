/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry

/**
 * Stack navigation bootstrapper - EXACTLY like iOS UINavigationController pattern
 * 
 * iOS: Creates UINavigationController, sets initial screen, calls replaceRoot()
 * Android: Creates FrameLayout container, sets initial screen, replaces Activity content view
 * 
 * This is the ROOT navigation component - it REPLACES the entire Activity content
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFStackBootstrapper"
        private const val MAX_RETRIES = 10
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val initialScreen = props["initialScreen"] as? String
        
        if (initialScreen == null) {
            Log.e(TAG, "❌ Missing required prop 'initialScreen'")
            return FrameLayout(context)
        }
        
        Log.d(TAG, "🚀 Setting up stack navigation with initial screen: $initialScreen")
        
        // Create the navigation container - this will become the Activity's content view
        // Just like iOS creates UINavigationController
        val navigationContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            id = View.generateViewId() // Give it a proper ID
        }
        
        // CRITICAL: Clear any existing navigation stack (for hot restarts)
        DCFScreenRegistry.clearStack()
        Log.d(TAG, "🧹 Cleared existing navigation stack")
        
        // Set up initial screen with retry logic (same as iOS)
        setupInitialScreenWithRetry(
            navigationContainer = navigationContainer,
            initialScreen = initialScreen,
            retryCount = 0
        )
        
        // CRITICAL: Replace the Activity's root content view (like iOS replaceRoot)
        // This makes our navigation container the ENTIRE screen
        Handler(Looper.getMainLooper()).post {
            replaceActivityContentView(context, navigationContainer)
        }
        
        // Return a hidden placeholder (same as iOS)
        // The actual navigation container is set as Activity content view
        return View(context).apply {
            layoutParams = FrameLayout.LayoutParams(0, 0)
            visibility = View.GONE
        }
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // No updates needed for root navigation component
        return true
    }
    
    /**
     * Replace the Activity's content view with our navigation container
     * EXACTLY like iOS: replaceRoot(controller: navigationController)
     */
    private fun replaceActivityContentView(context: Context, navigationContainer: FrameLayout) {
        val activity = context as? Activity
        if (activity == null) {
            Log.e(TAG, "❌ Context is not an Activity, cannot replace root view")
            return
        }
        
        Log.d(TAG, "🔄 Replacing Activity content view with navigation container")
        activity.setContentView(navigationContainer)
        Log.d(TAG, "✅ Navigation container is now the Activity's root view")
    }
    
    /**
     * Set up initial screen with retry logic (same as iOS)
     */
    private fun setupInitialScreenWithRetry(
        navigationContainer: FrameLayout,
        initialScreen: String,
        retryCount: Int
    ) {
        val screenContainer = DCFScreenRegistry.getScreen(initialScreen)
        
        if (screenContainer != null && screenContainer.frameLayout != null) {
            Log.d(TAG, "✅ Found initial screen '$initialScreen' on attempt ${retryCount + 1}")
            
            // Push to navigation stack
            DCFScreenRegistry.pushRoute(initialScreen)
            
            // Add the screen's FrameLayout to our navigation container
            val screenFrameLayout = screenContainer.frameLayout!!
            
            // Remove from any existing parent first
            (screenFrameLayout.parent as? android.view.ViewGroup)?.removeView(screenFrameLayout)
            
            // Add to navigation container
            navigationContainer.addView(screenFrameLayout, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
            
            screenFrameLayout.visibility = View.VISIBLE
            screenFrameLayout.requestLayout()
            
            Log.d(TAG, "✅ Initial screen '$initialScreen' added to navigation container")
            return
        }
        
        // Retry if not found yet
        if (retryCount < MAX_RETRIES) {
            val delayMs = minOf(50L * (retryCount + 1), 500L)
            Log.d(TAG, "⏳ Initial screen '$initialScreen' not ready, retry ${retryCount + 1}/$MAX_RETRIES in ${delayMs}ms")
            
            Handler(Looper.getMainLooper()).postDelayed({
                setupInitialScreenWithRetry(navigationContainer, initialScreen, retryCount + 1)
            }, delayMs)
        } else {
            Log.e(TAG, "❌ Failed to find initial screen '$initialScreen' after $MAX_RETRIES attempts")
            Log.e(TAG, "Available routes: ${DCFScreenRegistry.getAllRoutes()}")
        }
    }
}