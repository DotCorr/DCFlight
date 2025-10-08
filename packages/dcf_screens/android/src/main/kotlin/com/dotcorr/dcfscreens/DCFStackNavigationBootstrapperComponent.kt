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
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent

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
        
        // Create a proper ViewGroup container that can hold child views
        val navigationContainer = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Ensure it's a proper ViewGroup
            id = View.generateViewId()
        }
        
        // Extract navigation properties
        val initialScreen = props["initialScreen"] as? String
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        val animationDuration = props["animationDuration"] as? Double
        
        Log.d(TAG, "StackNavigationBootstrapper created - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar, animationDuration: $animationDuration")
        
        // Set up initial navigation with retry mechanism
        setupInitialNavigationWithRetry(initialScreen, retryCount = 0, maxRetries = 10)
        
        return navigationContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating stack navigation bootstrapper component")
        
        // Handle navigation updates
        val initialScreen = props["initialScreen"] as? String
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean
        
        // Check for navigation commands
        val routeNavigationCommand = props["routeNavigationCommand"] as? Map<String, Any?>
        if (routeNavigationCommand != null) {
            Log.d(TAG, "Received navigation command: $routeNavigationCommand")
            handleNavigationCommand(routeNavigationCommand)
        }
        
        Log.d(TAG, "StackNavigationBootstrapper updated - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar")
        
        return true
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "setupInitialScreen" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Setting up initial screen: $screenName")
                setupInitialNavigationWithRetry(screenName, retryCount = 0, maxRetries = 10)
                true
            }
            "navigateToScreen" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Navigating to screen: $screenName")
                navigateToScreen(screenName)
                true
            }
            "goBack" -> {
                Log.d(TAG, "Going back in navigation stack")
                goBack()
                true
            }
            "handleNavigationCommand" -> {
                val command = arguments["command"] as? Map<String, Any?>
                if (command != null) {
                    handleNavigationCommand(command)
                }
                true
            }
            else -> null
        }
    }
    
    private fun handleNavigationCommand(command: Map<String, Any?>) {
        val action = command["action"] as? String
        val targetRoute = command["targetRoute"] as? String
        
        Log.d(TAG, "Handling navigation command: $action -> $targetRoute")
        
        when (action) {
            "navigateToRoute" -> {
                navigateToScreen(targetRoute)
            }
            "push" -> {
                navigateToScreen(targetRoute)
            }
            "pop" -> {
                goBack()
            }
            "replace" -> {
                navigateToScreen(targetRoute)
            }
            "popToRoot" -> {
                navigateToScreen("home")
            }
            else -> {
                Log.w(TAG, "Unknown navigation action: $action")
            }
        }
    }
    
    private fun setupInitialNavigationWithRetry(initialScreen: String?, retryCount: Int, maxRetries: Int) {
        if (initialScreen == null) {
            Log.e(TAG, "No initial screen provided")
            return
        }
        
        // Check if screen is available
        val screenContainer = DCFScreenComponent.getScreenContainer(initialScreen)
        if (screenContainer != null) {
            Log.d(TAG, "Found initial screen '$initialScreen' on attempt ${retryCount + 1}")
            setupInitialScreen(screenContainer)
            return
        }
        
        // Screen not found yet, retry with exponential backoff
        if (retryCount < maxRetries) {
            val delayMs = minOf(50 * (retryCount + 1), 500) // Exponential backoff: 50ms, 100ms, 150ms... max 500ms
            Log.d(TAG, "Initial screen '$initialScreen' not found, retrying in ${delayMs}ms (attempt ${retryCount + 1}/${maxRetries + 1})")
            
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                setupInitialNavigationWithRetry(initialScreen, retryCount + 1, maxRetries)
            }, delayMs.toLong())
        } else {
            Log.e(TAG, "Failed to find initial screen '$initialScreen' after ${maxRetries + 1} attempts")
        }
    }
    
    private fun setupInitialScreen(screenContainer: DCFScreenContainer) {
        Log.d(TAG, "Setting up initial screen '${screenContainer.route}'")
        
        // Hide all other screens first
        DCFScreenComponent.getAllScreenContainers().forEach { (route, container) ->
            if (route != screenContainer.route) {
                container.view.visibility = View.GONE
                Log.d(TAG, "Hiding screen: $route")
            }
        }
        
        // Make the initial screen visible
        screenContainer.view.visibility = View.VISIBLE
        screenContainer.view.alpha = 1.0f
        
        // Ensure the screen is properly sized
        screenContainer.view.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        
        // Fire initial lifecycle events
        propagateEvent(
            view = screenContainer.view,
            eventName = "onAppear",
            data = mapOf("route" to screenContainer.route, "isInitial" to true)
        )
        
        propagateEvent(
            view = screenContainer.view,
            eventName = "onActivate",
            data = mapOf("route" to screenContainer.route, "isInitial" to true)
        )
        
        Log.d(TAG, "Initial screen '${screenContainer.route}' ready")
    }
    
    private fun navigateToScreen(screenName: String?) {
        if (screenName == null) return
        
        Log.d(TAG, "Navigating to screen: $screenName")
        
        // Hide all screens first
        val allScreens = DCFScreenComponent.getAllScreenContainers()
        allScreens.forEach { (route, container) ->
            if (route != screenName) {
                container.view.visibility = View.GONE
                Log.d(TAG, "Hiding screen: $route")
            }
        }
        
        // Show the target screen
        val screenContainer = DCFScreenComponent.getScreenContainer(screenName)
        if (screenContainer != null) {
            screenContainer.view.visibility = View.VISIBLE
            screenContainer.view.alpha = 1.0f
            
            // Ensure the screen is properly sized
            screenContainer.view.layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            
            // Fire navigation events
            propagateEvent(
                view = screenContainer.view,
                eventName = "onAppear",
                data = mapOf("route" to screenName)
            )
            
            propagateEvent(
                view = screenContainer.view,
                eventName = "onActivate",
                data = mapOf("route" to screenName)
            )
            
            Log.d(TAG, "Successfully navigated to screen: $screenName")
        } else {
            Log.e(TAG, "Screen '$screenName' not found for navigation")
        }
    }
    
    private fun goBack() {
        Log.d(TAG, "Going back in navigation stack")
        // TODO: Implement actual back navigation logic
    }
}
