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
    }
}
