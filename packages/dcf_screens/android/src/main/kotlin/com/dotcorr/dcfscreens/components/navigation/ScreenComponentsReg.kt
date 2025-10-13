/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry

/**
 * Registers dcf_screens navigation components with DCFlight framework
 */
object ScreenComponentsReg {
    private const val TAG = "ScreenComponentsReg"
    
    fun registerComponents() {
        Log.d(TAG, "🔧 Registering dcf_screens navigation components...")
        
        // Register Screen component
        DCFComponentRegistry.shared.registerComponent(
            "Screen",
            DCFScreenComponent::class.java
        )
        
        // Register StackNavigationBootstrapper component
        DCFComponentRegistry.shared.registerComponent(
            "StackNavigationBootstrapper",
            DCFStackNavigationBootstrapperComponent::class.java
        )
        
        printRegistrationSummary()
    }
    
    private fun printRegistrationSummary() {
        Log.d(TAG, """
            ╔════════════════════════════════════════════════════════╗
            ║         DCF_Screens Navigation Components             ║
            ╠════════════════════════════════════════════════════════╣
            ║  ✅ Screen                                             ║
            ║  ✅ StackNavigationBootstrapper                        ║
            ╠════════════════════════════════════════════════════════╣
            ║  📦 Total Components: 2                                ║
            ║  🎯 Framework: Jetpack Compose Navigation              ║
            ║  🚀 Status: Ready for navigation!                      ║
            ╚════════════════════════════════════════════════════════╝
        """.trimIndent())
    }
    
    fun cleanup() {
        Log.d(TAG, "🧹 Cleaning up dcf_screens navigation...")
        // Add cleanup logic if needed for hot reload
    }
}
