/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * DCF Screens - Android implementation
 * Registers native components with DCFlight's component registry
 */
class DcfScreens : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "🔧 DcfScreens: Plugin attached to engine")
        registerComponents()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "🔧 DcfScreens: Plugin detached from engine")
    }

    companion object {
        private const val TAG = "DcfScreens"
        
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
