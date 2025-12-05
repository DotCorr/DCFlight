/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.util.Log
import com.dotcorr.dcflight.components.DCFFlutterWidgetComponent

/**
 * Registration class for DCFlight framework components
 */
object FrameworkComponentsReg {
    private const val TAG = "FrameworkComponentsReg"

    /**
     * Register framework-level components
     */
    @JvmStatic
    fun registerComponents() {
        // Register FlutterWidget component for embedding Flutter widgets
        DCFComponentRegistry.shared.registerComponent("FlutterWidget", DCFFlutterWidgetComponent::class.java)
        Log.d(TAG, "✅ Registered FlutterWidget component")
        
        // Register core framework components
        DCFComponentRegistry.shared.registerComponent("View", DCFViewComponent::class.java)
        Log.d(TAG, "✅ Registered View component")
        
        DCFComponentRegistry.shared.registerComponent("Text", DCFTextComponent::class.java)
        Log.d(TAG, "✅ Registered Text component")
        
        DCFComponentRegistry.shared.registerComponent("ScrollView", DCFScrollViewComponent::class.java)
        Log.d(TAG, "✅ Registered ScrollView component")
        
        DCFComponentRegistry.shared.registerComponent("ScrollContentView", DCFScrollContentViewComponent::class.java)
        Log.d(TAG, "✅ Registered ScrollContentView component")
        
        DCFComponentRegistry.shared.registerComponent("Viewport", DCFViewportComponent::class.java)
        Log.d(TAG, "✅ Registered Viewport component")
    }
}
