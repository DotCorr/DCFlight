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

/**
 * Android plugin registration for DCF Reanimated
 */
object DcfReanimatedPlugin {
    private const val TAG = "DcfReanimatedPlugin"
    
    fun registerComponents() {
        try {
            DCFComponentRegistry.shared.registerComponent(
                "ReanimatedView",
                DCFAnimatedViewComponent::class.java
            )
            Log.d(TAG, "✅ DCF REANIMATED: Registered pure UI thread components")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DCF REANIMATED: Failed to register components", e)
        }
    }
}

