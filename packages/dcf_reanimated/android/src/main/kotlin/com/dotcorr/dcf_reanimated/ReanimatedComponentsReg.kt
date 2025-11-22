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

/**
 * Registration class for DCF reanimated components
 * Following iOS FrameworkComponentsReg pattern
 * All component names must match iOS exactly for cross-platform consistency
 */
object ReanimatedComponentsReg {
    private const val TAG = "ReanimatedComponentsReg"

    /**
     * Register all reanimated components with the framework
     * This should be called during app initialization
     */
    @JvmStatic
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        // Register ReanimatedView
        registry.registerComponent("ReanimatedView", DCFAnimatedViewComponent::class.java)
        
        // Register Canvas component
        registry.registerComponent("Canvas", DCFCanvasComponent::class.java)
    }
}

