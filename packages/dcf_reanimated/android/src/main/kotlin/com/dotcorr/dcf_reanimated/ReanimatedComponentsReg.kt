/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_reanimated

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcf_reanimated.components.DCFAnimatedViewComponent

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
    }
}

