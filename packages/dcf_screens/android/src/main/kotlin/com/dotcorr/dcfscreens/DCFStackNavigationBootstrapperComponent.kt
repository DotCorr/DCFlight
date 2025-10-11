package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent

/**
 * DCFStackNavigationBootstrapperComponent for Android using native Android navigation
 * This follows the same pattern as iOS but uses Android's native navigation
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
        
        // Create a simple FrameLayout for now - we'll implement proper navigation later
        val container = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(android.graphics.Color.WHITE)
        }
        
        // Add a simple text view to show the current screen
        val textView = TextView(context).apply {
            text = "🏠 Android Navigation Stack\nInitial Screen: $initialScreen\nNavigation is working!"
            textSize = 18f
            setTextColor(android.graphics.Color.BLACK)
            gravity = android.view.Gravity.CENTER
        }
        
        container.addView(textView)
        
        // Initialize the navigation controller
        DCFAndroidNavigationController.shared.initialize(context)
        
        Log.d(TAG, "Stack navigation bootstrapper created successfully")
        
        return container
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Stack navigation bootstrapper typically doesn't need updates
        return false
    }
}