package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent

/**
 * DCFStackNavigationBootstrapperComponent for Android - matches iOS pattern exactly
 * This is the navigation shell that manages the entire navigation stack
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFStackNavigationBootstrapperComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating stack navigation bootstrapper component")
        
        val initialScreen = props["initialScreen"] as? String ?: "home"
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        val animationDuration = props["animationDuration"] as? Int
        
        Log.d(TAG, "StackNavigationBootstrapper created - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar, animationDuration: $animationDuration")
        
        // Return a hidden placeholder view (like iOS does)
        // The actual navigation will be handled by the DCFlight framework
        val placeholderView = android.widget.FrameLayout(context).apply {
            visibility = View.GONE // Hidden like iOS
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        
        Log.d(TAG, "✅ Returning hidden placeholder - DCFlight framework will handle navigation")
        return placeholderView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Handle navigation commands through props updates
        // This is where we'll process routeNavigationCommand like iOS does
        Log.d(TAG, "🔄 DCFStackNavigationBootstrapperComponent: updateView called with props: $props")
        
        val commandData = props["routeNavigationCommand"] as? Map<String, Any?>
        if (commandData != null) {
            Log.d(TAG, "🚀 DCFStackNavigationBootstrapperComponent: Processing route navigation command: $commandData")
            handleRouteNavigationCommand(commandData)
        }
        
        return false
    }
    
    private fun handleRouteNavigationCommand(commandData: Map<String, Any?>) {
        Log.d(TAG, "🚀 DCFStackNavigationBootstrapperComponent: Processing route navigation command: $commandData")
        
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
        Log.d(TAG, "🧭 DCFStackNavigationBootstrapperComponent: Navigating to route '$route' (animated: $animated)")
        
        // Find the registered screen container for this route
        val screenContainer = DCFScreenComponent.getScreenContainer(route)
        if (screenContainer != null) {
            Log.d(TAG, "✅ Found registered container for route: $route")
            
            // Actually navigate to the registered container (like iOS does)
            // This is where we implement the actual navigation logic
            Log.d(TAG, "🎯 DCFStackNavigationBootstrapperComponent: Navigating to container for route: $route")
            
            // Actually navigate to the registered screen container
            // This should replace the current Flutter view with the native screen
            try {
                // Get the current activity and replace the Flutter view with the native screen
                val activity = getCurrentActivity()
                if (activity != null) {
                    // Replace the Flutter view with the native screen container
                    replaceFlutterViewWithNativeScreen(activity, screenContainer, route, animated)
                    Log.d(TAG, "✅ DCFStackNavigationBootstrapperComponent: Successfully navigated to route: $route")
                } else {
                    Log.e(TAG, "❌ No current activity found for navigation")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error navigating to route '$route': ${e.message}")
            }
        } else {
            Log.e(TAG, "❌ No registered container found for route: $route")
            Log.d(TAG, "📋 Available routes: ${DCFScreenComponent.getAllRoutes()}")
        }
    }
    
    private fun popCurrentRoute(animated: Boolean, result: Map<String, Any?>?) {
        Log.d(TAG, "⬅️ DCFStackNavigationBootstrapperComponent: Popping current route (animated: $animated)")
        
        try {
            val activity = getCurrentActivity()
            if (activity != null) {
                // Get the root view and check if we can pop
                val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                if (rootView != null && rootView.childCount > 0) {
                    // Remove the last view (pop)
                    rootView.removeViewAt(rootView.childCount - 1)
                    Log.d(TAG, "✅ Successfully popped current route")
                } else {
                    Log.w(TAG, "⚠️ No views to pop")
                }
            } else {
                Log.e(TAG, "❌ No current activity found for pop")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to pop current route: ${e.message}")
        }
    }
    
    private fun popToRootRoute(animated: Boolean) {
        Log.d(TAG, "🏠 DCFStackNavigationBootstrapperComponent: Popping to root route (animated: $animated)")
        
        try {
            val activity = getCurrentActivity()
            if (activity != null) {
                // Get the root view and remove all views except the first one
                val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                if (rootView != null && rootView.childCount > 1) {
                    // Keep only the first view (root)
                    while (rootView.childCount > 1) {
                        rootView.removeViewAt(rootView.childCount - 1)
                    }
                    Log.d(TAG, "✅ Successfully popped to root route")
                } else {
                    Log.w(TAG, "⚠️ Already at root or no views to pop")
                }
            } else {
                Log.e(TAG, "❌ No current activity found for pop to root")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to pop to root route: ${e.message}")
        }
    }
    
    private fun popToRoute(route: String, animated: Boolean) {
        Log.d(TAG, "🔄 DCFStackNavigationBootstrapperComponent: Popping to route '$route' (animated: $animated)")
        
        try {
            val activity = getCurrentActivity()
            if (activity != null) {
                // Get the root view and find the target route
                val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                if (rootView != null) {
                    // Find the target route view and remove all views after it
                    val targetView = findViewForRoute(rootView, route)
                    if (targetView != null) {
                        val targetIndex = rootView.indexOfChild(targetView)
                        if (targetIndex >= 0) {
                            // Remove all views after the target
                            while (rootView.childCount > targetIndex + 1) {
                                rootView.removeViewAt(rootView.childCount - 1)
                            }
                            Log.d(TAG, "✅ Successfully popped to route: $route")
                        } else {
                            Log.w(TAG, "⚠️ Target route not found in view hierarchy")
                        }
                    } else {
                        Log.w(TAG, "⚠️ Target route view not found: $route")
                    }
                }
            } else {
                Log.e(TAG, "❌ No current activity found for pop to route")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to pop to route '$route': ${e.message}")
        }
    }
    
    private fun replaceWithRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {
        Log.d(TAG, "🔄 DCFStackNavigationBootstrapperComponent: Replacing with route '$route' (animated: $animated)")
        
        // Find the registered screen container for this route
        val screenContainer = DCFScreenComponent.getScreenContainer(route)
        if (screenContainer != null) {
            Log.d(TAG, "✅ Found registered container for route: $route")
            
            try {
                val activity = getCurrentActivity()
                if (activity != null) {
                    val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                    if (rootView != null && rootView.childCount > 0) {
                        // Replace the last view with the new route
                        rootView.removeViewAt(rootView.childCount - 1)
                        rootView.addView(screenContainer.view)
                        
                        // Set up the screen container
                        screenContainer.view.layoutParams = android.view.ViewGroup.LayoutParams(
                            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                            android.view.ViewGroup.LayoutParams.MATCH_PARENT
                        )
                        
                        Log.d(TAG, "✅ Successfully replaced with route: $route")
                    } else {
                        Log.w(TAG, "⚠️ No views to replace")
                    }
                } else {
                    Log.e(TAG, "❌ No current activity found for replace")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to replace with route '$route': ${e.message}")
            }
        } else {
            Log.e(TAG, "❌ No registered container found for route: $route")
        }
    }
    
    private fun presentModalRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {
        Log.d(TAG, "📱 DCFStackNavigationBootstrapperComponent: Presenting modal route '$route' (animated: $animated)")
        
        // Find the registered screen container for this route
        val screenContainer = DCFScreenComponent.getScreenContainer(route)
        if (screenContainer != null) {
            Log.d(TAG, "✅ Found registered container for route: $route")
            
            try {
                val activity = getCurrentActivity()
                if (activity != null) {
                    // For modal presentation, we'll add the view on top of existing views
                    val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
                    if (rootView != null) {
                        rootView.addView(screenContainer.view)
                        
                        // Set up the screen container for modal
                        screenContainer.view.layoutParams = android.view.ViewGroup.LayoutParams(
                            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                            android.view.ViewGroup.LayoutParams.MATCH_PARENT
                        )
                        
                        Log.d(TAG, "✅ Successfully presented modal route: $route")
                    } else {
                        Log.e(TAG, "❌ Could not find root view for modal presentation")
                    }
                } else {
                    Log.e(TAG, "❌ No current activity found for modal presentation")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to present modal route '$route': ${e.message}")
            }
        } else {
            Log.e(TAG, "❌ No registered container found for route: $route")
        }
    }
    
    // Helper method to find view for a specific route
    private fun findViewForRoute(rootView: android.view.ViewGroup, route: String): android.view.View? {
        // This is a simplified implementation
        // In a real implementation, you'd need to track which views correspond to which routes
        for (i in 0 until rootView.childCount) {
            val child = rootView.getChildAt(i)
            // Check if this view corresponds to the route
            // This would need to be implemented based on how you track route-view relationships
            if (child.tag == route) {
                return child
            }
        }
        return null
    }
    
    // Helper methods for actual navigation
    private fun getCurrentActivity(): android.app.Activity? {
        // Get the current activity from the DCFlight framework
        // This should return the current activity context
        try {
            // Use reflection to get the current activity from the DCFlight framework
            val activityClass = Class.forName("com.dotcorr.dcflight.DCFFlutterActivity")
            val currentActivityField = activityClass.getDeclaredField("currentActivity")
            currentActivityField.isAccessible = true
            return currentActivityField.get(null) as? android.app.Activity
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to get current activity: ${e.message}")
            return null
        }
    }
    
    private fun replaceFlutterViewWithNativeScreen(
        activity: android.app.Activity,
        screenContainer: DCFScreenContainer,
        route: String,
        animated: Boolean
    ) {
        Log.d(TAG, "🔄 DCFStackNavigationBootstrapperComponent: Replacing Flutter view with native screen for route: $route")
        
        try {
            // Get the root view from the activity
            val rootView = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
            if (rootView != null) {
                // Remove all existing views
                rootView.removeAllViews()
                
                // Add the native screen container
                rootView.addView(screenContainer.view)
                
                // Set up the screen container
                screenContainer.view.layoutParams = android.view.ViewGroup.LayoutParams(
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT
                )
                
                Log.d(TAG, "✅ Successfully replaced Flutter view with native screen for route: $route")
            } else {
                Log.e(TAG, "❌ Could not find root view in activity")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to replace Flutter view with native screen: ${e.message}")
        }
    }
}
