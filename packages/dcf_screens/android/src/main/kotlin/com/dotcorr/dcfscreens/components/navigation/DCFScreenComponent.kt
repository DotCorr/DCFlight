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
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.navigation.NavHostController
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry
import com.dotcorr.dcfscreens.components.navigation.utils.LifecycleEventHelper

/**
 * Main screen component for DCF_Screens navigation
 * Returns a FrameLayout container that can hold traditional Android Views
 * 
 * CRITICAL: We CANNOT return ComposeView because DCFlight's bridge will try
 * to attach View children to it, which is not allowed.
 */
class DCFScreenComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScreenComponent"
        var navController: NavHostController? = null
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val route = props["route"] as? String
        val presentationStyle = props["presentationStyle"] as? String ?: "push"
        
        if (route == null) {
            Log.e(TAG, "❌ Missing required prop 'route'")
            return FrameLayout(context) // Return ViewGroup, not ComposeView
        }
        
        Log.d(TAG, "🔧 Creating screen for route '$route'")
        
        // Check if already registered
        val existingContainer = DCFScreenRegistry.getScreen(route)
        if (existingContainer != null) {
            Log.d(TAG, "♻️ Reusing existing container for route '$route'")
            configureScreen(existingContainer, props)
            return existingContainer.frameLayout ?: FrameLayout(context)
        }
        
        // Create new screen container with a FrameLayout (ViewGroup)
        val viewId = props["viewId"] as? String ?: "screen_$route"
        val frameLayout = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        val screenContainer = ScreenContainer(
            route = route,
            presentationStyle = presentationStyle,
            content = {
                // This will be filled by DCFlight's VDOM
                ScreenContentPlaceholder(route = route)
            },
            viewId = viewId,
            frameLayout = frameLayout
        )
        
        // Configure and register
        configureScreen(screenContainer, props)
        DCFScreenRegistry.registerScreen(route, screenContainer)
        
        Log.d(TAG, "✅ Registered screen: $route")
        
        // Return the FrameLayout (ViewGroup that can accept View children)
        return frameLayout
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "🔵 updateView called with props: $props")
        
        // Like iOS: Try to find existing screen container from view first
        val screenContainer = findScreenContainerForView(view) 
            ?: run {
                // If not found, route must be in props (initial creation case)
                val route = props["route"] as? String
                if (route == null) {
                    Log.w(TAG, "⚠️ No route in props and view not in registry")
                    return false
                }
                
                Log.d(TAG, "🔵 Looking up container for route: $route")
                DCFScreenRegistry.getScreen(route)
            }
        
        if (screenContainer == null) {
            Log.w(TAG, "⚠️ Screen container not found")
            return false
        }
        
        val route = screenContainer.route
        Log.d(TAG, "✅ Updating screen for route: $route")
        
        configureScreen(screenContainer, props)
        
        // Process navigation commands sent via props
        val navCommand = props["routeNavigationCommand"] as? Map<*, *>
        Log.d(TAG, "📍 updateView - route: $route, hasNavCommand: ${navCommand != null}")
        if (navCommand != null) {
            Log.d(TAG, "🔍 Navigation command: $navCommand")
            processNavigationCommand(navCommand)
        }
        
        Log.d(TAG, "✅ Updated screen: $route")
        return true
    }
    
    /**
     * Find which screen container this view belongs to
     * Like iOS findScreenContainer(for: view)
     */
    private fun findScreenContainerForView(view: View): ScreenContainer? {
        // Check all registered screens to see if this view matches
        for ((route, container) in DCFScreenRegistry.getAllScreens()) {
            if (container.frameLayout == view) {
                Log.d(TAG, "📍 Found container for view: route=$route")
                return container
            }
        }
        return null
    }
    
    /**
     * Process navigation commands sent via props from Flutter
     */
    private fun processNavigationCommand(navCommand: Map<*, *>) {
        // Handle navigateToRoute
        navCommand["navigateToRoute"]?.let { route ->
            if (route is String) {
                val animated = navCommand["animated"] as? Boolean ?: true
                navigateToRoute(route, null)
                return
            }
        }
        
        // Handle presentModalRoute
        navCommand["presentModalRoute"]?.let { modalCommand ->
            if (modalCommand is Map<*, *>) {
                val route = modalCommand["route"] as? String
                val animated = modalCommand["animated"] as? Boolean ?: true
                if (route != null) {
                    presentModal(route, null)
                    return
                }
            }
        }
        
        // Handle popToRoute
        navCommand["popToRoute"]?.let { route ->
            if (route is String) {
                popToRoute(route)
                return
            }
        }
        
        // Handle replaceRoute
        navCommand["replaceRoute"]?.let { route ->
            if (route is String) {
                replaceCurrentRoute(route, null)
                return
            }
        }
        
        Log.w(TAG, "⚠️ Unknown navigation command: $navCommand")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "navigateToRoute" -> {
                val route = arguments["route"] as? String
                val params = arguments["params"] as? Map<String, Any?>
                if (route != null) navigateToRoute(route, params)
                null
            }
            "popCurrentRoute" -> { popCurrentRoute(); null }
            "popToRoute" -> {
                val route = arguments["route"] as? String
                if (route != null) popToRoute(route)
                null
            }
            "popToRoot" -> { popToRoot(); null }
            "replaceCurrentRoute" -> {
                val route = arguments["route"] as? String
                val params = arguments["params"] as? Map<String, Any?>
                if (route != null) replaceCurrentRoute(route, params)
                null
            }
            "presentModal" -> {
                val route = arguments["route"] as? String
                val params = arguments["params"] as? Map<String, Any?>
                if (route != null) presentModal(route, params)
                null
            }
            "dismissModal" -> { dismissModal(); null }
            else -> super.handleTunnelMethod(method, arguments)
        }
    }
    
    // MARK: - Configuration
    
    private fun configureScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        screenContainer.pushConfig = extractPushConfig(props)
        screenContainer.modalConfig = extractModalConfig(props)
        screenContainer.onAppear = props["onAppear"] as? ((Map<String, Any?>) -> Unit)
        screenContainer.onDisappear = props["onDisappear"] as? ((Map<String, Any?>) -> Unit)
        screenContainer.onActivate = props["onActivate"] as? ((Map<String, Any?>) -> Unit)
        screenContainer.onDeactivate = props["onDeactivate"] as? ((Map<String, Any?>) -> Unit)
        screenContainer.onReceiveParams = props["onReceiveParams"] as? ((Map<String, Any?>) -> Unit)
    }
    
    private fun extractPushConfig(props: Map<String, Any?>): Map<String, Any?>? {
        val pushConfig = props["pushConfig"] as? Map<*, *> ?: return null
        return mapOf(
            "title" to (pushConfig["title"] as? String),
            "hideBackButton" to (pushConfig["hideBackButton"] as? Boolean ?: false),
            "prefixActions" to (pushConfig["prefixActions"] as? List<*> ?: emptyList<Any>()),
            "suffixActions" to (pushConfig["suffixActions"] as? List<*> ?: emptyList<Any>())
        )
    }
    
    private fun extractModalConfig(props: Map<String, Any?>): Map<String, Any?>? {
        val modalConfig = props["modalConfig"] as? Map<*, *> ?: return null
        return mapOf(
            "presentationStyle" to (modalConfig["presentationStyle"] as? String ?: "fullScreen")
        )
    }
    
    // MARK: - Navigation Methods
    
    private fun navigateToRoute(route: String, params: Map<String, Any?>?) {
        Log.d(TAG, "🧭 Navigate to: $route")
        val screenContainer = DCFScreenRegistry.getScreen(route)
        if (screenContainer == null) {
            Log.e(TAG, "❌ Screen '$route' not found")
            return
        }
        
        if (params != null) {
            LifecycleEventHelper.fireOnReceiveParams(screenContainer, params)
        }
        
        navController?.navigate(route)
        DCFScreenRegistry.pushRoute(route)
        
        // CRITICAL: iOS-like navigation - hide all screens EXCEPT the target
        Handler(Looper.getMainLooper()).post {
            // Hide all screens except the target
            for ((screenRoute, container) in DCFScreenRegistry.getAllScreens()) {
                if (screenRoute != route) {
                    container.frameLayout?.visibility = View.GONE
                    Log.d(TAG, "🙈 Hidden screen: $screenRoute")
                }
            }
            
            // Show only the target screen
            screenContainer.frameLayout?.let { frameLayout ->
                frameLayout.visibility = View.VISIBLE
                frameLayout.bringToFront()
                frameLayout.requestLayout()
                Log.d(TAG, "👁️ Showing screen '$route'")
            }
        }
        
        LifecycleEventHelper.fireOnAppear(screenContainer)
    }
    
    private fun popCurrentRoute() {
        Log.d(TAG, "⬅️ Pop current route")
        val currentRoute = DCFScreenRegistry.getCurrentRoute()
        if (currentRoute != null) {
            val screenContainer = DCFScreenRegistry.getScreen(currentRoute)
            if (screenContainer != null) {
                LifecycleEventHelper.fireOnDisappear(screenContainer)
            }
        }
        
        navController?.popBackStack()
        DCFScreenRegistry.popRoute()
    }
    
    private fun popToRoute(route: String) {
        Log.d(TAG, "🔙 Pop to route: $route")
        val currentStack = DCFScreenRegistry.getNavigationStack()
        val targetIndex = currentStack.indexOf(route)
        
        if (targetIndex >= 0) {
            for (i in targetIndex + 1 until currentStack.size) {
                val poppedRoute = currentStack[i]
                val screenContainer = DCFScreenRegistry.getScreen(poppedRoute)
                if (screenContainer != null) {
                    LifecycleEventHelper.fireOnDisappear(screenContainer)
                }
            }
        }
        
        navController?.popBackStack(route, inclusive = false)
        DCFScreenRegistry.popToRoute(route)
    }
    
    private fun popToRoot() {
        Log.d(TAG, "🏠 Pop to root")
        val currentStack = DCFScreenRegistry.getNavigationStack()
        for (i in 1 until currentStack.size) {
            val route = currentStack[i]
            val screenContainer = DCFScreenRegistry.getScreen(route)
            if (screenContainer != null) {
                LifecycleEventHelper.fireOnDisappear(screenContainer)
            }
        }
        
        val rootRoute = currentStack.firstOrNull()
        if (rootRoute != null) {
            navController?.popBackStack(rootRoute, inclusive = false)
        }
        DCFScreenRegistry.popToRoot()
    }
    
    private fun replaceCurrentRoute(route: String, params: Map<String, Any?>?) {
        Log.d(TAG, "🔄 Replace with: $route")
        val currentRoute = DCFScreenRegistry.getCurrentRoute()
        if (currentRoute != null) {
            val currentContainer = DCFScreenRegistry.getScreen(currentRoute)
            if (currentContainer != null) {
                LifecycleEventHelper.fireOnDisappear(currentContainer)
            }
        }
        
        navController?.navigate(route) {
            if (currentRoute != null) {
                popUpTo(currentRoute) { inclusive = true }
            }
        }
        
        DCFScreenRegistry.replaceTopRoute(route)
        
        val newContainer = DCFScreenRegistry.getScreen(route)
        if (newContainer != null) {
            if (params != null) {
                LifecycleEventHelper.fireOnReceiveParams(newContainer, params)
            }
            LifecycleEventHelper.fireOnAppear(newContainer)
        }
    }
    
    private fun presentModal(route: String, params: Map<String, Any?>?) {
        Log.d(TAG, "📱 Present modal: $route")
        // TODO: Implement proper Dialog/BottomSheet
        // For now, use regular navigation
        navigateToRoute(route, params)
    }
    
    private fun dismissModal() {
        Log.d(TAG, "❌ Dismiss modal")
        // TODO: Implement proper modal dismissal
        popCurrentRoute()
    }
}

@Composable
private fun ScreenContentPlaceholder(route: String) {
    // Placeholder - actual content rendered by DCFlight VDOM
}
