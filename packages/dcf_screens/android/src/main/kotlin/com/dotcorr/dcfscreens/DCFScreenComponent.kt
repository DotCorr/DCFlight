/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent

/**
 * Android implementation of DCFScreen component
 * Handles screen presentation and navigation
 */
class DCFScreenComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScreenComponent"
        
        // Registry to store screen containers by route
        private val screenRegistry = mutableMapOf<String, DCFScreenContainer>()
        
        fun getScreenContainer(route: String): DCFScreenContainer? {
            return screenRegistry[route]
        }
        
        fun getAllScreenContainers(): Map<String, DCFScreenContainer> {
            return screenRegistry.toMap()
        }
        
        fun registerScreen(route: String, container: DCFScreenContainer) {
            screenRegistry[route] = container
            Log.d(TAG, "Registered screen: $route")
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
        
        // Register the screen container
        val container = DCFScreenContainer(route, screenContainer, presentationStyle)
        registerScreen(route, container)
        
        // Initialize navigation controller if this is the first screen
        if (context is Activity) {
            DCFAndroidNavigationController.shared.initialize(context)
            Log.d(TAG, "Navigation controller initialized from DCFScreenComponent with Activity: ${context.javaClass.simpleName}")
            
            // Try to set up the navigation system if it wasn't already set up
            try {
                val navigationController = DCFAndroidNavigationController.shared
                val rootView = navigationController.getRootView()
                if (rootView != null) {
                    // Replace the Activity's root view with the navigation controller
                    context.setContentView(rootView)
                    Log.d(TAG, "✅ Activity root replaced with navigation controller from DCFScreenComponent")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not replace Activity root from DCFScreenComponent: ${e.message}")
            }
        } else {
            Log.d(TAG, "DCFScreenComponent received non-Activity context: ${context.javaClass.simpleName}")
        }
        
        Log.d(TAG, "Screen created - route: $route, style: $presentationStyle")
        
        return screenContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating screen component")
        
        // Handle screen updates
        val route = props["route"] as? String
        val presentationStyle = props["presentationStyle"] as? String
        
        // Handle navigation bar configuration - check both direct props and pushConfig
        var prefixActions = props["prefixActions"] as? List<Map<String, Any?>>
        var suffixActions = props["suffixActions"] as? List<Map<String, Any?>>
        var title = props["title"] as? String
        var hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        
        // Check if navigation config is in pushConfig (like iOS)
        val pushConfig = props["pushConfig"] as? Map<String, Any?>
        if (pushConfig != null) {
            Log.d(TAG, "Found pushConfig: ${pushConfig.keys}")
            prefixActions = pushConfig["prefixActions"] as? List<Map<String, Any?>>
            suffixActions = pushConfig["suffixActions"] as? List<Map<String, Any?>>
            title = pushConfig["title"] as? String ?: title
            hideNavigationBar = pushConfig["hideNavigationBar"] as? Boolean ?: hideNavigationBar
        }
        
                if (prefixActions != null || suffixActions != null || title != null) {
                    Log.d(TAG, "Screen has navigation bar configuration - prefixActions: ${prefixActions?.size}, suffixActions: ${suffixActions?.size}, title: $title")
                    
                    // Configure navigation bar through the navigation controller
                    val currentRoute = route ?: "unknown"
                    DCFAndroidNavigationController.shared.pushScreen(
                        route = currentRoute,
                        title = title,
                        hideNavigationBar = hideNavigationBar,
                        prefixActions = prefixActions,
                        suffixActions = suffixActions
                    )
                }
        
        // Handle navigation commands
        val routeNavigationCommand = props["routeNavigationCommand"] as? Map<String, Any?>
        if (routeNavigationCommand != null) {
            Log.d(TAG, "Received navigation command: $routeNavigationCommand")
            handleNavigationCommand(routeNavigationCommand)
        }
        
        Log.d(TAG, "Screen updated - route: $route, style: $presentationStyle")
        
        return true
    }
    
    private fun handleNavigationCommand(command: Map<String, Any?>) {
        Log.d(TAG, "Processing navigation command: $command")
        
        // Handle navigateToRoute command (like iOS)
        val navigateToRoute = command["navigateToRoute"] as? String
        if (navigateToRoute != null) {
            val animated = command["animated"] as? Boolean ?: true
            val params = command["params"] as? Map<String, Any?>
            Log.d(TAG, "Navigating to route: $navigateToRoute, animated: $animated, params: $params")
            DCFAndroidNavigationController.shared.pushScreen(route = navigateToRoute)
        }
        
        // Handle pop command (like iOS)
        val popCommand = command["pop"] as? Map<String, Any?>
        if (popCommand != null) {
            val animated = popCommand["animated"] as? Boolean ?: true
            val result = popCommand["result"] as? Map<String, Any?>
            Log.d(TAG, "Pop command - animated: $animated, result: $result")
            DCFAndroidNavigationController.shared.popScreen()
        }
        
        // Handle popToRoot command (like iOS)
        val popToRootCommand = command["popToRoot"] as? Map<String, Any?>
        if (popToRootCommand != null) {
            val animated = popToRootCommand["animated"] as? Boolean ?: true
            Log.d(TAG, "Pop to root command - animated: $animated")
            DCFAndroidNavigationController.shared.popToRoot()
        }
        
        // Handle replaceWithRoute command (like iOS)
        val replaceCommand = command["replaceWithRoute"] as? Map<String, Any?>
        if (replaceCommand != null) {
            val targetRoute = replaceCommand["route"] as? String
            if (targetRoute != null) {
                val animated = replaceCommand["animated"] as? Boolean ?: true
                val params = replaceCommand["params"] as? Map<String, Any?>
                Log.d(TAG, "Replace with route: $targetRoute, animated: $animated, params: $params")
                DCFAndroidNavigationController.shared.replaceScreen(route = targetRoute)
            }
        }
        
        // Handle presentModalRoute command (like iOS)
        val modalCommand = command["presentModalRoute"] as? Map<String, Any?>
        if (modalCommand != null) {
            val targetRoute = modalCommand["route"] as? String
            if (targetRoute != null) {
                val animated = modalCommand["animated"] as? Boolean ?: true
                val params = modalCommand["params"] as? Map<String, Any?>
                val presentationStyle = modalCommand["presentationStyle"] as? String
                Log.d(TAG, "Present modal route: $targetRoute, animated: $animated, params: $params, style: $presentationStyle")
                navigateToScreen(targetRoute)
            }
        }
        
        // Handle dismissModal command (like iOS)
        val dismissModalCommand = command["dismissModal"] as? Map<String, Any?>
        if (dismissModalCommand != null) {
            val animated = dismissModalCommand["animated"] as? Boolean ?: true
            val result = dismissModalCommand["result"] as? Map<String, Any?>
            Log.d(TAG, "Dismiss modal command - animated: $animated, result: $result")
            // TODO: Implement actual modal dismissal
        }
    }
    
    private fun navigateToScreen(screenName: String?) {
        if (screenName == null) {
            Log.w(TAG, "Cannot navigate to null screen name")
            return
        }
        
        Log.d(TAG, "Navigating to screen: $screenName")
        
        // Use the new navigation controller for proper navigation
        DCFAndroidNavigationController.shared.pushScreen(
            route = screenName,
            title = screenName,
            hideNavigationBar = false
        )
    }

}
