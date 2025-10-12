package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent

class DCFStackNavigationBootstrapperComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFStackNav"
        private val CONTAINER_ID = View.generateViewId()
        
        // Global reference to the navigation bootstrapper (like iOS UINavigationController)
        private var sharedInstance: DCFStackNavigationBootstrapperComponent? = null
        
        fun getSharedInstance(): DCFStackNavigationBootstrapperComponent? {
            return sharedInstance
        }
    }

    private val navigationStack = mutableListOf<String>()
    private var navigationContainer: FrameLayout? = null

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating navigation view with props: $props")
        
        // Store the shared instance (like iOS stores UINavigationController)
        sharedInstance = this
        
        val container = FrameLayout(context).apply {
            id = CONTAINER_ID
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        navigationContainer = container
        
        // Check both possible prop names (initialRouteName and initialScreen)
        val initialRoute = (props["initialRouteName"] ?: props["initialScreen"]) as? String
        if (initialRoute != null) {
            Log.d(TAG, "Setting initial route: $initialRoute")
            showInitialScreen(container, initialRoute)
        } else {
            Log.e(TAG, "No initial route specified! Props: $props")
        }
        
        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating view with props: $props")
        // Navigation container doesn't need prop updates
        return false
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        Log.d(TAG, "Tunnel method: $method with args: $arguments")
        
        when (method) {
            "navigate" -> {
                val routeName = arguments["routeName"] as? String
                if (routeName != null) {
                    navigateToRoute(routeName)
                }
            }
            "goBack" -> {
                goBack()
            }
        }
        return null
    }

    private fun showInitialScreen(container: FrameLayout, initialScreen: String) {
        Log.d(TAG, "Showing initial screen: $initialScreen")
        
        val screenContainer = DCFScreenComponent.getScreenContainer(initialScreen)
        if (screenContainer == null) {
            Log.e(TAG, "Screen container not found for: $initialScreen")
            return
        }
        
        val screenView = screenContainer.view
        
        // CRITICAL: Hide ALL screens in root (ensures no overlays)
        val rootView = container.rootView as? ViewGroup
        if (rootView != null) {
            for (i in 0 until rootView.childCount) {
                val child = rootView.getChildAt(i)
                // Hide all DCFScreenComponent views (but not the nav container)
                if (child != container && child is ViewGroup) {
                    child.visibility = View.GONE
                    Log.d(TAG, "🔒 Hidden sibling screen view at index $i")
                }
            }
        }
        
        // CRITICAL: Remove from ANY parent (including root) before adding to nav container
        val currentParent = screenView.parent as? ViewGroup
        if (currentParent != null) {
            currentParent.removeView(screenView)
            Log.d(TAG, "Removed screen from parent: $currentParent")
        }
        
        // Clear navigation container and add only the initial screen
        container.removeAllViews()
        container.addView(screenView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
        
        screenView.visibility = View.VISIBLE
        screenView.bringToFront()
        
        // Bring navigation container to front (above all sibling screen views in root)
        container.bringToFront()
        container.requestLayout()
        
        navigationStack.clear()
        navigationStack.add(initialScreen)
        
        Log.d(TAG, "✅ Initial screen added. Stack: $navigationStack")
    }

    // Make this public so DCFScreenComponent can call it (like iOS UINavigationController.pushViewController)
    fun navigateToRoute(routeName: String) {
        Log.d(TAG, "🚀 Navigating to route: $routeName")
        
        val container = navigationContainer
        if (container == null) {
            Log.e(TAG, "Navigation container is null")
            return
        }
        
        // Check if we're already on this route (prevent duplicates)
        if (navigationStack.isNotEmpty() && navigationStack.last() == routeName) {
            Log.d(TAG, "Already on route: $routeName. Ignoring navigation.")
            return
        }
        
        val screenContainer = DCFScreenComponent.getScreenContainer(routeName)
        if (screenContainer == null) {
            Log.e(TAG, "Screen container not found for: $routeName")
            return
        }
        
        val screenView = screenContainer.view
        
        // CRITICAL: Hide ALL screens in root (not just the current one in the stack)
        // This ensures no sibling screens are visible over the nav container
        val rootView = container.rootView as? ViewGroup
        if (rootView != null) {
            for (i in 0 until rootView.childCount) {
                val child = rootView.getChildAt(i)
                // Hide all DCFScreenComponent views (but not the nav container)
                if (child != container && child is ViewGroup) {
                    child.visibility = View.GONE
                    Log.d(TAG, "🔒 Hidden sibling screen view at index $i")
                }
            }
        }
        
        // Hide the current top screen (if any) from navigation stack
        if (navigationStack.isNotEmpty()) {
            val currentRoute = navigationStack.last()
            val currentScreenContainer = DCFScreenComponent.getScreenContainer(currentRoute)
            currentScreenContainer?.view?.visibility = View.GONE
            Log.d(TAG, "Hidden previous screen: $currentRoute")
        }
        
        // CRITICAL: Remove from ANY parent (especially root!) before adding to nav container
        val currentParent = screenView.parent as? ViewGroup
        if (currentParent != null) {
            currentParent.removeView(screenView)
            Log.d(TAG, "Removed screen from parent: $currentParent")
        }
        
        // Clear container and add ONLY the new screen (like iOS replaces view controller)
        container.removeAllViews()
        container.addView(screenView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
        
        // Show and bring to front
        screenView.visibility = View.VISIBLE
        screenView.bringToFront()
        
        // CRITICAL: Bring navigation container to front (above ALL sibling screen views in root)
        container.bringToFront()
        container.requestLayout()
        
        // Update navigation stack
        navigationStack.add(routeName)
        
        Log.d(TAG, "✅ Navigated to $routeName. Stack: $navigationStack")
    }

    private fun goBack() {
        Log.d(TAG, "⬅️ Going back")
        
        if (navigationStack.size <= 1) {
            Log.d(TAG, "Already at initial screen, cannot go back")
            return
        }
        
        val container = navigationContainer
        if (container == null) {
            Log.e(TAG, "Navigation container is null")
            return
        }
        
        // Remove current route from stack
        navigationStack.removeAt(navigationStack.size - 1)
        
        // Show previous screen
        val previousRoute = navigationStack.last()
        val previousScreenContainer = DCFScreenComponent.getScreenContainer(previousRoute)
        if (previousScreenContainer == null) {
            Log.e(TAG, "Screen container not found for: $previousRoute")
            return
        }
        
        val previousView = previousScreenContainer.view
        
        // CRITICAL: Hide ALL screens in root (ensures no overlays)
        val rootView = container.rootView as? ViewGroup
        if (rootView != null) {
            for (i in 0 until rootView.childCount) {
                val child = rootView.getChildAt(i)
                // Hide all DCFScreenComponent views (but not the nav container)
                if (child != container && child is ViewGroup) {
                    child.visibility = View.GONE
                    Log.d(TAG, "🔒 Hidden sibling screen view at index $i")
                }
            }
        }
        
        // CRITICAL: Remove from ANY parent before adding to nav container
        val currentParent = previousView.parent as? ViewGroup
        if (currentParent != null) {
            currentParent.removeView(previousView)
            Log.d(TAG, "Removed previous screen from parent: $currentParent")
        }
        
        // Clear container and add ONLY the previous screen
        container.removeAllViews()
        container.addView(previousView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
        
        previousView.visibility = View.VISIBLE
        previousView.bringToFront()
        
        // CRITICAL: Bring navigation container to front (above ALL sibling screen views in root)
        container.bringToFront()
        container.requestLayout()
        
        Log.d(TAG, "✅ Went back to $previousRoute. Stack: $navigationStack")
    }
}

