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
 * ROOT navigation component - it REPLACES the entire Activity content
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
        
        // CRITICAL: Clear any existing navigation stack (for hot restarts)
        DCFScreenRegistry.clearStack()
        Log.d(TAG, "🧹 Cleared existing navigation stack")
        
        // CRITICAL: Get the existing "root" view from the registry
        // This is the DCFFrameLayout that was created by DCDivergerUtil
        val existingRoot = com.dotcorr.dcflight.layout.ViewRegistry.shared.getView("root") as? FrameLayout
        
        if (existingRoot != null) {
            Log.d(TAG, "✅ Found existing root view, will use it as navigation container")
            
            // DON'T remove children - the screen FrameLayouts are already attached!
            // Just set up visibility management
            
            // Set up initial screen with retry logic
            setupInitialScreenWithRetry(
                navigationContainer = existingRoot,
                initialScreen = initialScreen,
                retryCount = 0
            )
            
            Log.d(TAG, "✅ Bootstrapped navigation using existing root view")
        } else {
            Log.e(TAG, "❌ No root view found in registry!")
        }
        
        // Return a placeholder that will be GONE and stay hidden
        // CRITICAL FIX: Use GONE (completely removed from layout) and add viewTreeObserver
        //to force it back to GONE if Android tries to make it visible
        return View(context).apply {
            layoutParams = FrameLayout.LayoutParams(0, 0)
            visibility = View.GONE
            
            // Add listener to force GONE if visibility changes
            viewTreeObserver.addOnGlobalLayoutListener {
                if (visibility != View.GONE) {
                    visibility = View.GONE
                    Log.d(TAG, "🔒 Forced bootstrapper back to GONE")
                }
            }
        }
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL: Force bootstrapper to stay INVISIBLE (prevent Android from making it visible)
        if (view.visibility != View.INVISIBLE) {
            view.visibility = View.INVISIBLE
            view.alpha = 0f
            view.isClickable = false
            view.isFocusable = false
            Log.d(TAG, "🔒 Forced bootstrapper back to INVISIBLE (was ${view.visibility})")
        }
        return true
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
            
            // CRITICAL: Hide all screens EXCEPT the initial screen (iOS pattern - only top screen visible)
            for ((route, container) in DCFScreenRegistry.getAllScreens()) {
                if (route != initialScreen) {
                    container.frameLayout?.visibility = View.GONE
                    Log.d(TAG, "🙈 Initially hiding screen: $route")
                }
            }
            
            // Show only the initial screen
            val screenFrameLayout = screenContainer.frameLayout!!
            screenFrameLayout.visibility = View.VISIBLE
            screenFrameLayout.bringToFront()
            screenFrameLayout.requestLayout()
            screenFrameLayout.invalidate() // Force immediate redraw
            
            Log.d(TAG, "✅ Initial screen '$initialScreen' set as visible")
            Log.d(TAG, "✅ Bootstrapped navigation using existing root view")
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