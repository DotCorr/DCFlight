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
        
        // Register the screen container
        val container = DCFScreenContainer(route, screenContainer, presentationStyle)
        registerScreen(route, container)
        
        Log.d(TAG, "Screen created - route: $route, style: $presentationStyle")
        
        return screenContainer
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Screen components typically don't need updates
        return false
    }
}

/**
 * Container for screen content
 */
data class DCFScreenContainer(
    val route: String,
    val view: View,
    val presentationStyle: String
)
