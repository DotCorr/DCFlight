package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent

/**
 * Native Stack Navigator - iOS UINavigationController pattern
 * 
 * Like iOS:
 * - Maintains a stack of view controllers (screens)
 * - Last child in container = top of stack = visible screen
 * - Previous screens stay in container but are covered by top screen
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFStackNav"
        private val CONTAINER_ID = View.generateViewId()
        
        // Singleton access for DCFScreenComponent
        private var sharedInstance: DCFStackNavigationBootstrapperComponent? = null
        
        fun getSharedInstance(): DCFStackNavigationBootstrapperComponent? {
            return sharedInstance
        }
    }

    // Navigation stack tracking route names
    private val navigationStack = mutableListOf<String>()
    
    // Main container holding all screen views
    private var navigationContainer: FrameLayout? = null
    
    // CRITICAL: Keep strong references to screens in the stack
    // to prevent them from being removed by Flutter
    private val screenViewCache = mutableMapOf<String, View>()

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "📱 Creating navigation container")
        
        val container = FrameLayout(context).apply {
            id = CONTAINER_ID
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        navigationContainer = container
        sharedInstance = this
        
        val initialRoute = (props["initialRouteName"] ?: props["initialScreen"]) as? String
        if (initialRoute != null) {
            Log.d(TAG, "Setting initial route: $initialRoute")
            showInitialScreen(container, initialRoute)
        }
        
        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return false
    }

    /**
     * Initialize stack with root screen (iOS: initWithRootViewController:)
     */
    private fun showInitialScreen(container: FrameLayout, initialScreen: String) {
        Log.d(TAG, "📱 Showing initial screen: $initialScreen")
        
        val screenContainer = DCFScreenComponent.getScreenContainer(initialScreen)
        if (screenContainer == null) {
            Log.e(TAG, "❌ Screen not found: $initialScreen")
            return
        }
        
        val screenView = screenContainer.view
        
        // CRITICAL: Only remove from parent if it's NOT already in our container
        val currentParent = screenView.parent as? ViewGroup
        if (currentParent != null && currentParent != container) {
            currentParent.removeView(screenView)
            Log.d(TAG, "Removed initial screen from different parent: ${currentParent.javaClass.simpleName}")
        }
        
        // Add as FIRST screen in container (DON'T call removeAllViews here!)
        // Only add if not already in container
        if (screenView.parent != container) {
            container.addView(screenView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
            Log.d(TAG, "Added initial screen to container")
        } else {
            Log.d(TAG, "Initial screen already in container")
        }
        
        screenView.visibility = View.VISIBLE
        
        navigationStack.clear()
        navigationStack.add(initialScreen)
        screenViewCache[initialScreen] = screenView  // Cache the initial screen
        
        Log.d(TAG, "✅ Initial screen set. Stack: $navigationStack, Children: ${container.childCount}")
    }

    /**
     * Push new screen onto stack (iOS: pushViewController:animated:)
     * 
     * CRITICAL: ADD to container, DON'T REMOVE previous screens!
     */
    fun navigateToRoute(routeName: String) {
        Log.d(TAG, "🚀 Push: $routeName")
        
        val container = navigationContainer ?: run {
            Log.e(TAG, "❌ No container")
            return
        }
        
        // Prevent duplicate push
        if (navigationStack.lastOrNull() == routeName) {
            Log.d(TAG, "Already on: $routeName")
            return
        }
        
        val screenContainer = DCFScreenComponent.getScreenContainer(routeName)
        if (screenContainer == null) {
            Log.e(TAG, "❌ Screen not found: $routeName")
            return
        }
        
        val screenView = screenContainer.view
        
        // CRITICAL: Re-add all previous screens that may have been removed by Flutter
        Log.d(TAG, "Container children before restoration: ${container.childCount}")
        for (i in 0 until navigationStack.size) {
            val routeInStack = navigationStack[i]
            val cachedView = screenViewCache[routeInStack]
            if (cachedView != null && cachedView.parent != container) {
                Log.d(TAG, "🔧 RESTORING screen to container: $routeInStack (was removed by Flutter!)")
                (cachedView.parent as? ViewGroup)?.removeView(cachedView)
                container.addView(cachedView, i, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                ))
            }
        }
        Log.d(TAG, "Container children after restoration: ${container.childCount}")
        
        Log.d(TAG, "Stack before push: $navigationStack")
        
        // ✅ CRITICAL FIX: Only remove from parent if it's NOT already in our navigation container
        val currentParent = screenView.parent as? ViewGroup
        if (currentParent != null && currentParent != container) {
            currentParent.removeView(screenView)
            Log.d(TAG, "Removed screen from different parent: ${currentParent.javaClass.simpleName}")
        } else if (currentParent == container) {
            Log.d(TAG, "Screen already in navigation container, not removing")
        } else {
            Log.d(TAG, "Screen has no parent")
        }
        
        // ✅ CRITICAL: ADD to end of container (DON'T call removeAllViews!)
        // This accumulates screens: [home] → [home, profile] → [home, profile, settings]
        // Only add if not already a child
        if (screenView.parent != container) {
            container.addView(screenView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
            Log.d(TAG, "Added screen to container")
        } else {
            Log.d(TAG, "Screen already in container, just bringing to front")
        }
        
        screenView.visibility = View.VISIBLE
        screenView.bringToFront()
        
        navigationStack.add(routeName)
        screenViewCache[routeName] = screenView  // Cache the view
        
        Log.d(TAG, "Container children after add: ${container.childCount}")
        Log.d(TAG, "✅ Pushed $routeName. Stack: $navigationStack, Children: ${container.childCount}")
    }

    /**
     * Pop top screen from stack (iOS: popViewControllerAnimated:)
     */
    fun goBack() {
        Log.d(TAG, "🔙 Pop")
        
        if (navigationStack.size <= 1) {
            Log.d(TAG, "At root, cannot pop")
            return
        }
        
        val container = navigationContainer ?: run {
            Log.e(TAG, "❌ No container")
            return
        }
        
        // Remove from stack
        val poppedRoute = navigationStack.removeAt(navigationStack.size - 1)
        
        // Remove the LAST child (top screen)
        val childCount = container.childCount
        if (childCount > 0) {
            container.removeViewAt(childCount - 1)
            Log.d(TAG, "Removed view for: $poppedRoute")
        }
        
        // Remove from cache
        screenViewCache.remove(poppedRoute)
        Log.d(TAG, "Removed $poppedRoute from cache")
        
        val currentRoute = navigationStack.last()
        
        Log.d(TAG, "✅ Popped to $currentRoute. Stack: $navigationStack, Children: ${container.childCount}")
    }
}
