package com.dotcorr.dcfscreenspackage com.dotcorr.dcfscreens



import android.content.Contextimport android.content.Context

import android.util.Logimport android.util.Log

import android.view.Viewimport android.view.View

import android.widget.FrameLayoutimport android.widget.FrameLayout

import androidx.fragment.app.FragmentActivityimport androidx.fragment.app.FragmentActivity

import androidx.fragment.app.FragmentManagerimport androidx.fragment.app.FragmentManager

import com.dotcorr.dcflight.components.DCFComponentimport androidx.fragment.app.FragmentTransaction

import com.dotcorr.dcflight.components.DCFComponent

/**

 * DCFStackNavigationBootstrapperComponent - Fragment-based navigation like react-native-screens/**

 * Uses FragmentManager + Fragments instead of manual View management * DCFStackNavigationBootstrapperComponent - Fragment-based navigation like react-native-screens

 * This provides proper Android screen lifecycle and back stack management * Uses FragmentManager + Fragments instead of manual View management

 */ * This provides proper Android screen lifecycle and back stack management

class DCFStackNavigationBootstrapperComponent : DCFComponent() { */

    class DCFStackNavigationBootstrapperComponent : DCFComponent() {

    companion object {    

        private const val TAG = "DCFStackNav"    companion object {

        private const val CONTAINER_ID = View.generateViewId() // Unique ID for Fragment container        private const val TAG = "DCFStackNav"

    }        private const val CONTAINER_ID = View.generateViewId() // Unique ID for FragmentContainerView

        }

    private var fragmentManager: FragmentManager? = null    

    private var containerView: FrameLayout? = null    private var fragmentManager: FragmentManager? = null

    private val navigationStack = mutableListOf<String>()    private var containerView: FrameLayout? = null

    private val navigationStack = mutableListOf<String>()

    override fun createView(context: Context, props: Map<String, Any?>): View {

        Log.d(TAG, "📱 Creating Fragment-based navigation container")    override fun createView(context: Context, props: Map<String, Any?>): View {

                Log.d(TAG, "Creating Fragment-based navigation container")

        val initialScreen = props["initialScreen"] as? String ?: "home"        

                val initialScreen = props["initialScreen"] as? String ?: "home"

        // Get Activity to access FragmentManager        

        val activity = DcfScreensPlugin.getActivity()        // Get Activity to access FragmentManager

        if (activity == null) {        val activity = DcfScreensPlugin.getActivity()

            Log.e(TAG, "❌ No Activity available - cannot use FragmentManager")        if (activity == null) {

            return FrameLayout(context) // Return empty container as fallback            Log.e(TAG, "❌ No Activity available - cannot use FragmentManager")

        }            return FrameLayout(context) // Return empty container as fallback

                }

        if (activity !is FragmentActivity) {        

            Log.e(TAG, "❌ Activity is not a FragmentActivity - cannot use FragmentManager")        if (activity !is FragmentActivity) {

            return FrameLayout(context)            Log.e(TAG, "❌ Activity is not a FragmentActivity - cannot use FragmentManager")

        }            return FrameLayout(context)

                }

        // Create Fragment container with unique ID        

        val container = FrameLayout(context).apply {        // Create Fragment container with unique ID

            id = CONTAINER_ID        val container = FrameLayout(context).apply {

            layoutParams = FrameLayout.LayoutParams(            id = CONTAINER_ID

                FrameLayout.LayoutParams.MATCH_PARENT,            layoutParams = FrameLayout.LayoutParams(

                FrameLayout.LayoutParams.MATCH_PARENT                FrameLayout.LayoutParams.MATCH_PARENT,

            )                FrameLayout.LayoutParams.MATCH_PARENT

        }            )

        containerView = container        }

        fragmentManager = activity.supportFragmentManager        containerView = container

                fragmentManager = activity.supportFragmentManager

        // Show initial screen using Fragment        

        navigationStack.add(initialScreen)        // Show initial screen using Fragment

        showInitialScreen(initialScreen)        navigationStack.add(initialScreen)

                showInitialScreen(initialScreen)

        Log.d(TAG, "✅ Fragment-based navigation created, initial screen: $initialScreen")        

        return container        Log.d(TAG, "✅ Fragment-based navigation created, initial screen: $initialScreen")

    }        return container

        }

    private fun showInitialScreen(route: String) {    

        val fragmentManager = this.fragmentManager ?: run {    private fun showInitialScreen(route: String) {

            Log.e(TAG, "❌ FragmentManager not available")        val fragmentManager = this.fragmentManager ?: run {

            return            Log.e(TAG, "❌ FragmentManager not available")

        }            return

                }

        Log.d(TAG, "📱 Showing initial screen as Fragment: $route")        

                Log.d(TAG, "📱 Showing initial screen as Fragment: $route")

        val fragment = DCFScreenFragment.newInstance(route)        

                val fragment = DCFScreenFragment.newInstance(route)

        fragmentManager.beginTransaction()        

            .replace(CONTAINER_ID, fragment, route)        fragmentManager.beginTransaction()

            .commitNow() // Synchronous commit for initial screen            .replace(CONTAINER_ID, fragment, route)

                    .commitNow() // Synchronous commit for initial screen

        Log.d(TAG, "✅ Initial Fragment committed: $route")        

    }        Log.d(TAG, "✅ Initial Fragment committed: $route")

    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {

        Log.d(TAG, "🔄 updateView called")    override fun updateView(view: View, props: Map<String, Any?>): Boolean {

                Log.d(TAG, "🔄 updateView called with props: $props")

        val commandData = props["routeNavigationCommand"] as? Map<String, Any?>        

        if (commandData != null) {        val commandData = props["routeNavigationCommand"] as? Map<String, Any?>

            Log.d(TAG, "🚀 Processing route navigation command: $commandData")        if (commandData != null) {

            handleRouteNavigationCommand(commandData)            Log.d(TAG, "🚀 Processing route navigation command: $commandData")

        }            handleRouteNavigationCommand(commandData)

                }

        return false        

    }        return false

        }

    private fun handleRouteNavigationCommand(commandData: Map<String, Any?>) {    

        // Handle navigateToRoute command    private fun handleRouteNavigationCommand(commandData: Map<String, Any?>) {

        val targetRoute = commandData["navigateToRoute"] as? String        Log.d(TAG, "🚀 Processing route navigation command: $commandData")

        if (targetRoute != null) {        

            val animated = commandData["animated"] as? Boolean ?: true        // Handle navigateToRoute command

            navigateToRoute(targetRoute, animated)        val targetRoute = commandData["navigateToRoute"] as? String

        }        if (targetRoute != null) {

                    val animated = commandData["animated"] as? Boolean ?: true

        // Handle pop command            val params = commandData["params"] as? Map<String, Any?>

        val popCommand = commandData["pop"] as? Map<String, Any?>            navigateToRoute(targetRoute, animated, params)

        if (popCommand != null) {        }

            val animated = popCommand["animated"] as? Boolean ?: true        

            popCurrentRoute(animated)        // Handle pop command

        }        val popCommand = commandData["pop"] as? Map<String, Any?>

                if (popCommand != null) {

        // Handle popToRoot command            val animated = popCommand["animated"] as? Boolean ?: true

        val popToRootCommand = commandData["popToRoot"] as? Map<String, Any?>            val result = popCommand["result"] as? Map<String, Any?>

        if (popToRootCommand != null) {            popCurrentRoute(animated, result)

            val animated = popToRootCommand["animated"] as? Boolean ?: true        }

            popToRootRoute(animated)        

        }        // Handle popToRoot command

                val popToRootCommand = commandData["popToRoot"] as? Map<String, Any?>

        // Handle popToRoute command        if (popToRootCommand != null) {

        val popToRoute = commandData["popToRoute"] as? String            val animated = popToRootCommand["animated"] as? Boolean ?: true

        if (popToRoute != null) {            popToRootRoute(animated)

            val animated = commandData["animated"] as? Boolean ?: true        }

            popToRoute(popToRoute, animated)        

        }        // Handle popToRoute command

                val popToRoute = commandData["popToRoute"] as? String

        // Handle replaceWithRoute command        if (popToRoute != null) {

        val replaceCommand = commandData["replaceWithRoute"] as? Map<String, Any?>            val animated = commandData["animated"] as? Boolean ?: true

        if (replaceCommand != null) {            popToRoute(popToRoute, animated)

            val targetRoute = replaceCommand["route"] as? String        }

            val animated = replaceCommand["animated"] as? Boolean ?: true        

            if (targetRoute != null) {        // Handle replaceWithRoute command

                replaceWithRoute(targetRoute, animated)        val replaceCommand = commandData["replaceWithRoute"] as? Map<String, Any?>

            }        if (replaceCommand != null) {

        }            val targetRoute = replaceCommand["route"] as? String

    }            val animated = replaceCommand["animated"] as? Boolean ?: true

                val params = replaceCommand["params"] as? Map<String, Any?>

    private fun navigateToRoute(route: String, animated: Boolean) {            if (targetRoute != null) {

        val fragmentManager = this.fragmentManager ?: run {                replaceWithRoute(targetRoute, animated, params)

            Log.e(TAG, "❌ FragmentManager not available")            }

            return        }

        }    }

            

        Log.d(TAG, "🚀 Navigating to route: $route (Fragment-based)")    private fun navigateToRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {

                val fragmentManager = this.fragmentManager ?: run {

        navigationStack.add(route)            Log.e(TAG, "❌ FragmentManager not available")

                    return

        val fragment = DCFScreenFragment.newInstance(route)        }

                

        val transaction = fragmentManager.beginTransaction()        Log.d(TAG, "🚀 Navigating to route: $route (Fragment-based)")

                

        if (animated) {        navigationStack.add(route)

            // Use Android's standard slide animations        

            transaction.setCustomAnimations(        val fragment = DCFScreenFragment.newInstance(route)

                android.R.anim.slide_in_left,        

                android.R.anim.slide_out_right,        val transaction = fragmentManager.beginTransaction()

                android.R.anim.slide_in_left,        

                android.R.anim.slide_out_right        if (animated) {

            )            // Use Android's standard slide animations

        }            transaction.setCustomAnimations(

                        android.R.anim.slide_in_left,

        transaction                android.R.anim.slide_out_right,

            .replace(CONTAINER_ID, fragment, route)                android.R.anim.slide_in_left,

            .addToBackStack(route) // Add to back stack for Android back button                android.R.anim.slide_out_right

            .commit()            )

                }

        Log.d(TAG, "✅ Fragment transaction committed: $route")        

    }        transaction

                .replace(CONTAINER_ID, fragment, route)

    private fun popCurrentRoute(animated: Boolean) {            .addToBackStack(route) // Add to back stack for Android back button

        val fragmentManager = this.fragmentManager ?: run {            .commit()

            Log.e(TAG, "❌ FragmentManager not available")        

            return        Log.d(TAG, "✅ Navigation Fragment transaction committed: $route")

        }    }

            

        if (navigationStack.size <= 1) {    private fun popCurrentRoute(animated: Boolean, result: Map<String, Any?>?) {

            Log.w(TAG, "⚠️ Cannot pop - already at root")        val fragmentManager = this.fragmentManager ?: run {

            return            Log.e(TAG, "❌ FragmentManager not available")

        }            return

                }

        Log.d(TAG, "⬅️ Popping current route")        

        navigationStack.removeLastOrNull()        if (navigationStack.size <= 1) {

                    Log.w(TAG, "⚠️ Cannot pop - already at root")

        fragmentManager.popBackStack()            return

                }

        Log.d(TAG, "✅ Fragment popped from back stack")        

    }        Log.d(TAG, "⬅️ Popping current route")

            navigationStack.removeLastOrNull()

    private fun popToRootRoute(animated: Boolean) {        

        val fragmentManager = this.fragmentManager ?: run {        fragmentManager.popBackStack()

            Log.e(TAG, "❌ FragmentManager not available")        

            return        Log.d(TAG, "✅ Fragment popped from back stack")

        }    }

            

        Log.d(TAG, "⬅️ Popping to root")    private fun popToRootRoute(animated: Boolean) {

                val fragmentManager = this.fragmentManager ?: run {

        // Pop all fragments except the first one            Log.e(TAG, "❌ FragmentManager not available")

        fragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)            return

                }

        // Clear stack except initial screen        

        val initialScreen = navigationStack.firstOrNull()        Log.d(TAG, "⬅️ Popping to root")

        navigationStack.clear()        

        if (initialScreen != null) {        // Pop all fragments except the first one

            navigationStack.add(initialScreen)        fragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        }        

                // Clear stack except initial screen

        Log.d(TAG, "✅ Popped to root")        val initialScreen = navigationStack.firstOrNull()

    }        navigationStack.clear()

            if (initialScreen != null) {

    private fun popToRoute(route: String, animated: Boolean) {            navigationStack.add(initialScreen)

        val fragmentManager = this.fragmentManager ?: run {        }

            Log.e(TAG, "❌ FragmentManager not available")        

            return        Log.d(TAG, "✅ Popped to root")

        }    }

            

        Log.d(TAG, "⬅️ Popping to route: $route")    private fun popToRoute(route: String, animated: Boolean) {

                val fragmentManager = this.fragmentManager ?: run {

        // Pop back stack to the specified route            Log.e(TAG, "❌ FragmentManager not available")

        fragmentManager.popBackStack(route, 0)            return

                }

        // Update navigation stack        

        val index = navigationStack.indexOf(route)        Log.d(TAG, "⬅️ Popping to route: $route")

        if (index >= 0) {        

            navigationStack.subList(index + 1, navigationStack.size).clear()        // Pop back stack to the specified route

        }        fragmentManager.popBackStack(route, 0)

                

        Log.d(TAG, "✅ Popped to route: $route")        // Update navigation stack

    }        val index = navigationStack.indexOf(route)

            if (index >= 0) {

    private fun replaceWithRoute(route: String, animated: Boolean) {            navigationStack.subList(index + 1, navigationStack.size).clear()

        val fragmentManager = this.fragmentManager ?: run {        }

            Log.e(TAG, "❌ FragmentManager not available")        

            return        Log.d(TAG, "✅ Popped to route: $route")

        }    }

            

        Log.d(TAG, "🔄 Replacing current route with: $route")    private fun replaceWithRoute(route: String, animated: Boolean, params: Map<String, Any?>?) {

                val fragmentManager = this.fragmentManager ?: run {

        // Pop current screen from stack            Log.e(TAG, "❌ FragmentManager not available")

        navigationStack.removeLastOrNull()            return

        navigationStack.add(route)        }

                

        val fragment = DCFScreenFragment.newInstance(route)        Log.d(TAG, "🔄 Replacing current route with: $route")

                

        val transaction = fragmentManager.beginTransaction()        // Pop current screen from stack

                navigationStack.removeLastOrNull()

        if (animated) {        navigationStack.add(route)

            transaction.setCustomAnimations(        

                android.R.anim.fade_in,        val fragment = DCFScreenFragment.newInstance(route)

                android.R.anim.fade_out        

            )        val transaction = fragmentManager.beginTransaction()

        }        

                if (animated) {

        transaction            transaction.setCustomAnimations(

            .replace(CONTAINER_ID, fragment, route)                android.R.anim.fade_in,

            .commit()                android.R.anim.fade_out

                    )

        Log.d(TAG, "✅ Route replaced: $route")        }

    }        

}        transaction

            .replace(CONTAINER_ID, fragment, route)
            .commit()
        
        Log.d(TAG, "✅ Route replaced: $route")
    }
}
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
