package com.dotcorr.dcfscreens

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.navigation.NavController

/**
 * Android Navigation Controller using proper Android Navigation APIs
 * This follows the same pattern as iOS but uses Android's native navigation
 */
class DCFAndroidNavigationController private constructor() {
    
    companion object {
        private const val TAG = "DCFAndroidNavigationController"
        val shared = DCFAndroidNavigationController()
    }
    
    private var activity: Activity? = null
    private var context: Context? = null
    private var navigationContainer: FrameLayout? = null
    private var navController: NavController? = null
    
    fun initialize(activity: Activity) {
        if (this.activity == null) {
            this.activity = activity
            this.context = activity
            setupNavigationContainer()
            Log.d(TAG, "DCFAndroidNavigationController initialized with Activity")
        }
    }
    
    fun initialize(context: Context) {
        if (this.context == null) {
            this.context = context
            Log.d(TAG, "DCFAndroidNavigationController initialized with Context")
        }
    }
    
    fun setNavController(navController: NavController) {
        this.navController = navController
        Log.d(TAG, "NavController set")
    }
    
    private fun setupNavigationContainer() {
        activity?.let { currentActivity ->
            // Create a container that will hold our navigation
            navigationContainer = FrameLayout(currentActivity).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                setBackgroundColor(android.graphics.Color.WHITE)
            }
            
            // Replace the entire Activity content (like iOS replaceRoot)
            currentActivity.setContentView(navigationContainer)
            Log.d(TAG, "✅ Navigation container set as Activity root")
        }
    }
    
    fun pushScreen(route: String, title: String? = null) {
        Log.d(TAG, "Pushing screen: $route")
        
        navController?.let { controller ->
            try {
                controller.navigate(route)
                Log.d(TAG, "✅ Successfully navigated to $route")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to navigate to $route", e)
            }
        } ?: run {
            Log.w(TAG, "NavController not available for navigation to $route")
        }
    }
    
    fun popScreen(): Boolean {
        Log.d(TAG, "Popping screen")
        
        navController?.let { controller ->
            return try {
                controller.popBackStack()
                Log.d(TAG, "✅ Successfully popped screen")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to pop screen", e)
                false
            }
        } ?: run {
            Log.w(TAG, "NavController not available for pop")
            return false
        }
    }
    
    fun getCurrentRoute(): String? {
        return navController?.currentDestination?.route
    }
    
    fun getRootView(): View? {
        return navigationContainer
    }
}