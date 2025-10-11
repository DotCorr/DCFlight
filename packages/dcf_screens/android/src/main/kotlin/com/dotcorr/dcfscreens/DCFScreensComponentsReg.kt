package com.dotcorr.dcfscreens

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry

object DCFScreensComponentsReg {
    private const val TAG = "DCFScreensComponentsReg"
    
    fun registerComponents() {
        try {
            Log.d(TAG, "Registering DCFScreens components")
            
            // Register Screen component
            DCFComponentRegistry.shared.registerComponent(
                "Screen", 
                componentClass = DCFScreenComponent::class.java
            )
            
            // Register StackNavigationBootstrapper component
            DCFComponentRegistry.shared.registerComponent(
                "StackNavigationBootstrapper", 
                componentClass = DCFStackNavigationBootstrapperComponent::class.java
            )
            
            Log.d(TAG, "DCFScreens components registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register DCFScreens components", e)
        }
    }
}
