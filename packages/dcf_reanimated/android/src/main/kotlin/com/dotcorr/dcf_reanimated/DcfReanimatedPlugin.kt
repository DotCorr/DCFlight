/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcf_reanimated.components.DCFAnimatedViewComponent
import com.dotcorr.dcf_reanimated.components.DCFCanvasComponent
import com.dotcorr.dcf_reanimated.components.DCFGPUComponent

/**
 * Android plugin registration for DCF Reanimated
 */
object DcfReanimatedPlugin {
    private const val TAG = "DcfReanimatedPlugin"
    
    fun registerComponents() {
        try {
            // Register ReanimatedView
            DCFComponentRegistry.shared.registerComponent(
                "ReanimatedView",
                DCFAnimatedViewComponent::class.java
            )
            
            // Register Skia Canvas component
            DCFComponentRegistry.shared.registerComponent(
                "Canvas",
                DCFCanvasComponent::class.java
            )
            
            // Register Skia GPU component
            DCFComponentRegistry.shared.registerComponent(
                "GPU",
                DCFGPUComponent::class.java
            )
            
            Log.d(TAG, "✅ DCF REANIMATED: Registered components (ReanimatedView, Canvas, GPU)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DCF REANIMATED: Failed to register components", e)
        }
    }
}

