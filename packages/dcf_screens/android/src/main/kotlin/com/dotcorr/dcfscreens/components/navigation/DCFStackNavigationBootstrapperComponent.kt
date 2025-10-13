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
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.rememberNavController
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry

/**
 * Root navigation bootstrapper component
 * Creates the NavHostController and sets up initial screen
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
            return ComposeView(context)
        }
        
        Log.d(TAG, "🚀 Setting up navigation with initial screen: $initialScreen")
        
        // Create ComposeView (which IS an Android View!)
        val composeView = ComposeView(context)
        
        // Set Compose content
        composeView.setContent {
            val navController = rememberNavController()
            
            // Store navController globally for navigation commands
            LaunchedEffect(navController) {
                DCFScreenComponent.navController = navController
                Log.d(TAG, "✅ NavController initialized")
            }
            
            // NavigationHost will be added here
            // For now, just a placeholder
            Text(
                text = "DCF Navigation Ready: $initialScreen",
                modifier = Modifier.padding(16.dp)
            )
        }
        
        // Setup initial screen with retry logic
        setupInitialScreenWithRetry(initialScreen, retryCount = 0, maxRetries = MAX_RETRIES)
        
        Log.d(TAG, "✅ Navigation bootstrapper created")
        return composeView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Navigation root doesn't need updates
        return true
    }
    
    private fun setupInitialScreenWithRetry(initialScreen: String, retryCount: Int, maxRetries: Int) {
        if (DCFScreenRegistry.hasScreen(initialScreen)) {
            Log.d(TAG, "✅ Initial screen '$initialScreen' found!")
            DCFScreenRegistry.pushRoute(initialScreen)
            
            // Navigate to initial screen
            DCFScreenComponent.navController?.navigate(initialScreen)
            return
        }
        
        if (retryCount < maxRetries) {
            val delayMs = minOf(INITIAL_DELAY_MS * (retryCount + 1), 500)
            Log.d(TAG, "⏳ Screen '$initialScreen' not ready, retry ${retryCount + 1}/$maxRetries in ${delayMs}ms")
            
            Handler(Looper.getMainLooper()).postDelayed({
                setupInitialScreenWithRetry(initialScreen, retryCount + 1, maxRetries)
            }, delayMs)
        } else {
            Log.e(TAG, "❌ Failed to find initial screen '$initialScreen' after $maxRetries attempts")
            Log.e(TAG, "Available routes: ${DCFScreenRegistry.getAllRoutes()}")
        }
    }
}
