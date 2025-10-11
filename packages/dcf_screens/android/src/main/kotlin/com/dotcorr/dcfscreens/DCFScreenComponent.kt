package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent

/**
 * DCFScreenComponent for Android using Jetpack Compose Navigation
 * This follows the same pattern as iOS but uses Android's native navigation
 */
class DCFScreenComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScreenComponent"
        private val screenRegistry = mutableMapOf<String, DCFScreenContainer>()
        
        fun registerScreen(route: String, container: DCFScreenContainer) {
            screenRegistry[route] = container
            Log.d(TAG, "Registered screen: $route")
        }
        
        fun getScreenContainer(route: String): DCFScreenContainer? {
            return screenRegistry[route]
        }
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating screen component")
        
        val route = props["route"] as? String ?: "unknown"
        val presentationStyle = props["presentationStyle"] as? String ?: "push"
        
        val screenContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(android.graphics.Color.WHITE)
        }
        
        // Extract header configuration from props (like iOS does)
        val headerConfig = extractHeaderConfig(props)
        
        // Register the screen container with header config
        val container = DCFScreenContainer(route, screenContainer, presentationStyle, headerConfig)
        registerScreen(route, container)
        
        Log.d(TAG, "Screen created - route: $route, style: $presentationStyle")
        
        // Process any navigation commands immediately
        handleRouteNavigationCommand(props)
        
        return screenContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Handle navigation commands like iOS does
        handleRouteNavigationCommand(props)
        
        // Update header configuration if it changed
        val route = props["route"] as? String
        if (route != null) {
            val container = getScreenContainer(route)
            if (container != null) {
                val newHeaderConfig = extractHeaderConfig(props)
                container.updateHeaderConfig(newHeaderConfig)
            }
        }
        
        return false
    }
    
    private fun handleRouteNavigationCommand(props: Map<String, Any?>) {
        val commandData = props["routeNavigationCommand"] as? Map<String, Any?> ?: return
        
        Log.d(TAG, "🚀 DCFScreenComponent: Processing route navigation command: $commandData")
        
        // Handle navigateToRoute command
        val targetRoute = commandData["navigateToRoute"] as? String
        if (targetRoute != null) {
            val animated = commandData["animated"] as? Boolean ?: true
            val params = commandData["params"] as? Map<String, Any?>
            navigateToRoute(targetRoute, animated, params)
        }
        
        // Handle pop command
        val popCommand = commandData["pop"] as? Map<String, Any?>
        if (popCommand != null) {
            val animated = popCommand["animated"] as? Boolean ?: true
            val result = popCommand["result"] as? Map<String, Any?>
            popCurrentRoute(animated, result)
        }
        
        // Handle popToRoot command
        val popToRootCommand = commandData["popToRoot"] as? Map<String, Any?>
        if (popToRootCommand != null) {
            val animated = popToRootCommand["animated"] as? Boolean ?: true
            popToRootRoute(animated)
        }
        
        // Handle popToRoute command
        val popToRoute = commandData["popToRoute"] as? String
        if (popToRoute != null) {
            val animated = commandData["animated"] as? Boolean ?: true
            popToRoute(popToRoute, animated)
        }
        
        // Handle replaceWithRoute command
        val replaceCommand = commandData["replaceWithRoute"] as? Map<String, Any?>
        if (replaceCommand != null) {
            val targetRoute = replaceCommand["route"] as? String
            val animated = replaceCommand["animated"] as? Boolean ?: true
            val params = replaceCommand["params"] as? Map<String, Any?>
            if (targetRoute != null) {
                replaceWithRoute(targetRoute, animated, params)
            }
        }
        
        // Handle presentModalRoute command
        val modalCommand = commandData["presentModalRoute"] as? Map<String, Any?>
        if (modalCommand != null) {
            val targetRoute = modalCommand["route"] as? String
            val animated = modalCommand["animated"] as? Boolean ?: true
            val params = modalCommand["params"] as? Map<String, Any?>
            if (targetRoute != null) {
                presentModalRoute(targetRoute, animated, params)
            }
        }
    }
    
    private fun navigateToRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {
        Log.d(TAG, "🧭 DCFScreenComponent: Navigating to route '$route' (animated: $animated)")
        DCFAndroidNavigationController.shared.pushScreen(route)
    }
    
    private fun popCurrentRoute(animated: Boolean, result: Map<String, Any?>?) {
        Log.d(TAG, "⬅️ DCFScreenComponent: Popping current route (animated: $animated)")
        DCFAndroidNavigationController.shared.popScreen()
    }
    
    private fun popToRootRoute(animated: Boolean) {
        Log.d(TAG, "🏠 DCFScreenComponent: Popping to root route (animated: $animated)")
        // For now, just pop all screens
        while (DCFAndroidNavigationController.shared.popScreen()) {
            // Keep popping until we can't pop anymore
        }
    }
    
    private fun popToRoute(route: String, animated: Boolean) {
        Log.d(TAG, "🎯 DCFScreenComponent: Popping to route '$route' (animated: $animated)")
        // This is more complex - would need to track navigation stack
        // For now, just navigate to the route
        DCFAndroidNavigationController.shared.pushScreen(route)
    }
    
    private fun replaceWithRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {
        Log.d(TAG, "🔄 DCFScreenComponent: Replacing with route '$route' (animated: $animated)")
        // Pop current and navigate to new route
        DCFAndroidNavigationController.shared.popScreen()
        DCFAndroidNavigationController.shared.pushScreen(route)
    }
    
    private fun presentModalRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {
        Log.d(TAG, "📱 DCFScreenComponent: Presenting modal route '$route' (animated: $animated)")
        // For now, just navigate to the route
        DCFAndroidNavigationController.shared.pushScreen(route)
    }
    
    private fun extractHeaderConfig(props: Map<String, Any?>): Map<String, Any?> {
        val headerConfig = mutableMapOf<String, Any?>()
        
        // Extract title
        props["title"]?.let { headerConfig["title"] = it }
        
        // Extract pushConfig if present
        val pushConfig = props["pushConfig"] as? Map<String, Any?>
        if (pushConfig != null) {
            pushConfig["title"]?.let { headerConfig["title"] = it }
            pushConfig["prefixActions"]?.let { headerConfig["prefixActions"] = it }
            pushConfig["suffixActions"]?.let { headerConfig["suffixActions"] = it }
            pushConfig["hideNavigationBar"]?.let { headerConfig["hideNavigationBar"] = it }
            pushConfig["hideBackButton"]?.let { headerConfig["hideBackButton"] = it }
        }
        
        // Extract direct header properties
        props["prefixActions"]?.let { headerConfig["prefixActions"] = it }
        props["suffixActions"]?.let { headerConfig["suffixActions"] = it }
        props["hideNavigationBar"]?.let { headerConfig["hideNavigationBar"] = it }
        props["hideBackButton"]?.let { headerConfig["hideBackButton"] = it }
        
        Log.d(TAG, "📱 DCFScreenComponent: Extracted header config: $headerConfig")
        return headerConfig
    }
}

/**
 * Container for screen content with header configuration
 */
class DCFScreenContainer(
    val route: String,
    val view: View,
    val presentationStyle: String,
    var headerConfig: Map<String, Any?> = emptyMap()
) {
    fun updateHeaderConfig(config: Map<String, Any?>) {
        headerConfig = config
        Log.d("DCFScreenContainer", "Updated header config for '$route': $config")
    }
}
