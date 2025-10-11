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
        
        // Extract navigation properties
        val initialScreen = props["initialScreen"] as? String
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        val animationDuration = props["animationDuration"] as? Double
        
        Log.d(TAG, "StackNavigationBootstrapper created - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar, animationDuration: $animationDuration")
        
        // Create a hidden placeholder view (like iOS)
        val placeholderView = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            visibility = View.GONE
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        
        // Set up the navigation system (like iOS creates UINavigationController)
        setupNavigationSystem(context, initialScreen, hideNavigationBar)
        
        return placeholderView
    }
    
    private fun setupNavigationSystem(context: Context, initialScreen: String?, hideNavigationBar: Boolean) {
        Log.d(TAG, "Setting up navigation system")
        
        // Try to get Activity from context first
        var activity = when (context) {
            is android.app.Activity -> context
            is android.content.ContextWrapper -> {
                var ctx = context.baseContext
                while (ctx is android.content.ContextWrapper && ctx !is android.app.Activity) {
                    ctx = ctx.baseContext
                }
                ctx as? android.app.Activity
            }
            else -> null
        }
        
        // If we couldn't get Activity from context, try to get it from Flutter engine
        if (activity == null) {
            Log.d(TAG, "Could not find Activity from context, trying Flutter engine...")
            activity = getActivityFromFlutterEngine()
        }
        
        // If we still couldn't get Activity, try to get it from the plugin
        if (activity == null) {
            Log.d(TAG, "Could not find Activity from Flutter engine, trying plugin...")
            activity = com.dotcorr.dcfscreens.DcfScreensPlugin.getActivity()
            if (activity != null) {
                Log.d(TAG, "✅ Found Activity from plugin: ${activity!!.javaClass.simpleName}")
            }
        }
        
        if (activity != null) {
            // Initialize the navigation controller with the Activity
            DCFAndroidNavigationController.shared.initialize(activity)
            Log.d(TAG, "Android Navigation Controller initialized with activity: ${activity.javaClass.simpleName}")
            
            // 🎯 CRITICAL: Replace the root of the Activity with our navigation controller
            // This is the Android equivalent of iOS replaceRoot(controller: navigationController)
            replaceActivityRoot(activity, initialScreen)
            
            Log.d(TAG, "Activity root replaced with navigation controller")
        } else {
            Log.w(TAG, "Could not find Activity from any source")
            // Initialize with context anyway - DCFScreenComponent will handle Activity initialization
            DCFAndroidNavigationController.shared.initialize(context)
            Log.w(TAG, "Navigation controller initialized with context, will be upgraded to Activity later")
            
            // Set up a delayed retry mechanism to try to get the Activity later
            setupDelayedActivityInitialization(initialScreen)
        }
        
        Log.d(TAG, "Navigation system setup complete")
    }
    
    /**
     * Try to get Activity from Flutter engine using multiple strategies
     */
    private fun getActivityFromFlutterEngine(): android.app.Activity? {
        // Strategy 1: Try to get Activity from Flutter engine using reflection
        try {
            val flutterEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's context using reflection
                val contextField = engine.javaClass.getDeclaredField("context")
                contextField.isAccessible = true
                val engineContext = contextField.get(engine) as? Context
                if (engineContext is android.app.Activity) {
                    Log.d(TAG, "Found Activity from Flutter engine context: ${engineContext.javaClass.simpleName}")
                    return engineContext
                }
                
                // Try to unwrap the context
                if (engineContext is android.content.ContextWrapper) {
                    var ctx = engineContext.baseContext
                    while (ctx is android.content.ContextWrapper && ctx !is android.app.Activity) {
                        ctx = ctx.baseContext
                    }
                    if (ctx is android.app.Activity) {
                        Log.d(TAG, "Found Activity from Flutter engine unwrapped context: ${ctx.javaClass.simpleName}")
                        return ctx
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine context: ${e.message}")
        }
        
        // Strategy 2: Try to get Activity from Flutter engine using activity field
        try {
            val flutterEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's activity field
                val activityField = engine.javaClass.getDeclaredField("activity")
                activityField.isAccessible = true
                val engineActivity = activityField.get(engine) as? android.app.Activity
                if (engineActivity != null) {
                    Log.d(TAG, "Found Activity from Flutter engine activity: ${engineActivity.javaClass.simpleName}")
                    return engineActivity
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine activity: ${e.message}")
        }
        
        // Strategy 3: Try to get Activity from Flutter engine's activity registry
        try {
            val flutterEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's activity registry
                val activityRegistryField = engine.javaClass.getDeclaredField("activityRegistry")
                activityRegistryField.isAccessible = true
                val activityRegistry = activityRegistryField.get(engine)
                
                // Try to get the current activity from the registry
                if (activityRegistry != null) {
                    val getCurrentActivityMethod = activityRegistry.javaClass.getDeclaredMethod("getCurrentActivity")
                    getCurrentActivityMethod.isAccessible = true
                    val currentActivity = getCurrentActivityMethod.invoke(activityRegistry) as? android.app.Activity
                    if (currentActivity != null) {
                        Log.d(TAG, "Found Activity from Flutter engine activity registry: ${currentActivity.javaClass.simpleName}")
                        return currentActivity
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine activity registry: ${e.message}")
        }
        
        // Strategy 4: Try to get Activity from Flutter engine's plugin registry
        try {
            val flutterEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's plugin registry
                val pluginRegistryField = engine.javaClass.getDeclaredField("pluginRegistry")
                pluginRegistryField.isAccessible = true
                val pluginRegistry = pluginRegistryField.get(engine)
                
                // Try to get the activity from the plugin registry
                if (pluginRegistry != null) {
                    val getActivityMethod = pluginRegistry.javaClass.getDeclaredMethod("getActivity")
                    getActivityMethod.isAccessible = true
                    val activity = getActivityMethod.invoke(pluginRegistry) as? android.app.Activity
                    if (activity != null) {
                        Log.d(TAG, "Found Activity from Flutter engine plugin registry: ${activity.javaClass.simpleName}")
                        return activity
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine plugin registry: ${e.message}")
        }
        
        Log.w(TAG, "Could not get Activity from Flutter engine")
        return null
    }
    
    /**
     * Android equivalent of iOS replaceRoot(controller: navigationController)
     * This replaces the Activity's root view with our navigation controller
     */
    private fun replaceActivityRoot(activity: android.app.Activity, initialScreen: String?) {
        try {
            Log.d(TAG, "Replacing Activity root with navigation controller")
            
            // Get the navigation controller's root view
            val navigationController = DCFAndroidNavigationController.shared
            val rootView = navigationController.getRootView()
            
            if (rootView != null) {
                // Set the navigation controller as the root view of the Activity
                activity.setContentView(rootView)
                Log.d(TAG, "✅ Activity root successfully replaced with navigation controller")
                
                // Set up initial screen if provided
                if (initialScreen != null) {
                    navigationController.pushScreen(initialScreen)
                    Log.d(TAG, "Initial screen '$initialScreen' pushed to navigation stack")
                }
            } else {
                Log.e(TAG, "❌ Navigation controller root view is null")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to replace Activity root: ${e.message}")
        }
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
        val title = command["title"] as? String
        val hideNavigationBar = command["hideNavigationBar"] as? Boolean ?: false
        val prefixActions = command["prefixActions"] as? List<Map<String, Any?>>
        val suffixActions = command["suffixActions"] as? List<Map<String, Any?>>
        
        Log.d(TAG, "Handling navigation command: $action -> $targetRoute")
        
        when (action) {
            "navigateToRoute" -> {
                DCFAndroidNavigationController.shared.pushScreen(
                    route = targetRoute ?: "",
                    title = title,
                    hideNavigationBar = hideNavigationBar,
                    prefixActions = prefixActions,
                    suffixActions = suffixActions
                )
            }
            "push" -> {
                DCFAndroidNavigationController.shared.pushScreen(
                    route = targetRoute ?: "",
                    title = title,
                    hideNavigationBar = hideNavigationBar,
                    prefixActions = prefixActions,
                    suffixActions = suffixActions
                )
            }
            "pop" -> {
                DCFAndroidNavigationController.shared.popScreen()
            }
            "replace" -> {
                DCFAndroidNavigationController.shared.replaceScreen(
                    route = targetRoute ?: "",
                    title = title,
                    hideNavigationBar = hideNavigationBar,
                    prefixActions = prefixActions,
                    suffixActions = suffixActions
                )
            }
            "popToRoot" -> {
                DCFAndroidNavigationController.shared.popToRoot()
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
        
        // Use the navigation controller to set up the initial screen
        DCFAndroidNavigationController.shared.pushScreen(
            route = screenContainer.route,
            title = screenContainer.route,
            hideNavigationBar = false
        )
        
        Log.d(TAG, "Initial screen '${screenContainer.route}' ready")
    }
    
    private fun navigateToScreen(screenName: String?) {
        if (screenName == null) return
        
        Log.d(TAG, "Navigating to screen: $screenName")
        
        // Use the navigation controller for proper navigation
        DCFAndroidNavigationController.shared.pushScreen(
            route = screenName,
            title = screenName,
            hideNavigationBar = false
        )
    }
    
    private fun goBack() {
        Log.d(TAG, "Going back in navigation stack")
        DCFAndroidNavigationController.shared.goBack()
    }
    
    /**
     * Set up delayed Activity initialization with retry mechanism
     */
    private fun setupDelayedActivityInitialization(initialScreen: String?) {
        Log.d(TAG, "Setting up delayed Activity initialization")
        
        // Retry every 100ms for up to 5 seconds (50 attempts)
        var attemptCount = 0
        val maxAttempts = 50
        val retryDelay = 100L
        
        val retryRunnable = object : Runnable {
            override fun run() {
                attemptCount++
                Log.d(TAG, "Delayed Activity initialization attempt $attemptCount/$maxAttempts")
                
                // Try to get Activity from Flutter engine again
                var activity = getActivityFromFlutterEngine()
                
                // If not found from Flutter engine, try the plugin
                if (activity == null) {
                    activity = com.dotcorr.dcfscreens.DcfScreensPlugin.getActivity()
                }
                
                if (activity != null) {
                    Log.d(TAG, "✅ Found Activity on delayed attempt $attemptCount: ${activity.javaClass.simpleName}")
                    
                    // Initialize the navigation controller with the Activity
                    DCFAndroidNavigationController.shared.initialize(activity)
                    
                    // Replace the root of the Activity with our navigation controller
                    replaceActivityRoot(activity, initialScreen)
                    
                    Log.d(TAG, "✅ Delayed Activity initialization successful")
                } else if (attemptCount < maxAttempts) {
                    // Schedule next retry
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(this, retryDelay)
                } else {
                    Log.e(TAG, "❌ Failed to find Activity after $maxAttempts attempts")
                }
            }
        }
        
        // Start the retry mechanism
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(retryRunnable, retryDelay)
    }
}
