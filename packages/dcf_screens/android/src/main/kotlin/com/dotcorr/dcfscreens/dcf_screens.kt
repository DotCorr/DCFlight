/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry

/**
 * DCF Screens - Android implementation
 * Registers native components with DCFlight's component registry
 */
class DcfScreens {
    companion object {
        private const val TAG = "DcfScreens"
        
        @JvmStatic
        fun registerWithRegistrar() {
            registerComponents()
        }
        
        @JvmStatic
        fun registerComponents() {
            Log.d(TAG, "🔧 DcfScreens: Registering components with DCFlight")
            
            // Register Screen component
            DCFComponentRegistry.shared.registerComponent(
                "Screen", 
                DCFScreenComponent::class.java
            )
            Log.d(TAG, "✅ DcfScreens: Registered Screen component")
            
            // Register TabNavigator component
            DCFComponentRegistry.shared.registerComponent(
                "TabNavigator", 
                DCFTabNavigatorComponent::class.java
            )
            Log.d(TAG, "✅ DcfScreens: Registered TabNavigator component")
            
            // Register StackNavigationBootstrapper component
            DCFComponentRegistry.shared.registerComponent(
                "StackNavigationBootstrapper", 
                DCFStackNavigationBootstrapperComponent::class.java
            )
            Log.d(TAG, "✅ DcfScreens: Registered StackNavigationBootstrapper component")
            
            Log.d(TAG, "🎉 DcfScreens: All components registered successfully!")
        }
    }
}
