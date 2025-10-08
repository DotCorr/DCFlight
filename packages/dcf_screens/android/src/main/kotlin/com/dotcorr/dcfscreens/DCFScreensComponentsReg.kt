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
 * Registration class for DCFScreens components
 * Registers Screen, TabNavigator, and StackNavigationBootstrapper components
 */
object DCFScreensComponentsReg {
    private const val TAG = "DCFScreensComponentsReg"

    /**
     * Register dcf_screens specific components
     */
    @JvmStatic
    fun registerComponents() {
        try {
            // Register Screen component
            DCFComponentRegistry.shared.registerComponent(
                "Screen", 
                DCFScreenComponent::class.java
            )
            
            // Register TabNavigator component
            DCFComponentRegistry.shared.registerComponent(
                "TabNavigator", 
                DCFTabNavigatorComponent::class.java
            )
            
            // Register StackNavigationBootstrapper component
            DCFComponentRegistry.shared.registerComponent(
                "StackNavigationBootstrapper", 
                DCFStackNavigationBootstrapperComponent::class.java
            )
            
            Log.d(TAG, "DCFScreens components registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register DCFScreens components", e)
        }
    }
}
