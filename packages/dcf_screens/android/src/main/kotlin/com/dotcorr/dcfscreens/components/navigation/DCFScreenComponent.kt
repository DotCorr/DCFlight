/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation

import android.content.Context
import android.util.Log
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.navigation.NavHostController
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry
import com.dotcorr.dcfscreens.components.navigation.utils.LifecycleEventHelper

/**
 * Main screen component for DCF_Screens navigation
 * Uses Jetpack Compose Navigation with ComposeView
 * 
 * ComposeView IS an Android View, so it integrates perfectly with DCFlight!
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
            return ComposeView(context)
        }
        
        Log.d(TAG, "🔧 Creating screen for route '$route'")
        
        // Check if already registered
        val existingContainer = DCFScreenRegistry.getScreen(route)
        if (existingContainer != null) {
            Log.d(TAG, "♻️ Reusing existing container for route '$route'")
            configureScreen(existingContainer, props)
            return existingContainer.composeView ?: ComposeView(context)
        }
        
        // Create new screen container
        val viewId = props["viewId"] as? String ?: "screen_$route"
        val screenContainer = ScreenContainer(
            route = route,
            presentationStyle = presentationStyle,
            content = {
                // This will be filled by DCFlight's VDOM
                ScreenContentPlaceholder(route = route)
            },
            viewId = viewId
        )
        
        // Configure and register
        configureScreen(screenContainer, props)
        DCFScreenRegistry.registerScreen(route, screenContainer)
        
        Log.d(TAG, "✅ Registered screen: $route")
        
        // Return a ComposeView (which IS an Android View)
        return ComposeView(context).apply {
            screenContainer.composeView = this
            // Content will be set by the NavigationHost
        }
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val route = props["route"] as? String ?: return false
        val screenContainer = DCFScreenRegistry.getScreen(route) ?: return false
        
        configureScreen(screenContainer, props)
        Log.d(TAG, "✅ Updated screen: $route")
        return true
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
