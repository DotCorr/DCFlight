/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation.utils

import android.util.Log
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer

/**
 * Helper for firing lifecycle events to Dart callbacks
 */
object LifecycleEventHelper {
    private const val TAG = "LifecycleEventHelper"
    
    fun fireOnAppear(screenContainer: ScreenContainer) {
        screenContainer.onAppear?.invoke(mapOf("route" to screenContainer.route))
        Log.d(TAG, "🟢 onAppear: ${screenContainer.route}")
    }
    
    fun fireOnDisappear(screenContainer: ScreenContainer) {
        screenContainer.onDisappear?.invoke(mapOf("route" to screenContainer.route))
        Log.d(TAG, "🔴 onDisappear: ${screenContainer.route}")
    }
    
    fun fireOnActivate(screenContainer: ScreenContainer) {
        screenContainer.onActivate?.invoke(mapOf("route" to screenContainer.route))
        Log.d(TAG, "⚡ onActivate: ${screenContainer.route}")
    }
    
    fun fireOnDeactivate(screenContainer: ScreenContainer) {
        screenContainer.onDeactivate?.invoke(mapOf("route" to screenContainer.route))
        Log.d(TAG, "💤 onDeactivate: ${screenContainer.route}")
    }
    
    fun fireOnReceiveParams(screenContainer: ScreenContainer, params: Map<String, Any?>) {
        val data = mapOf(
            "route" to screenContainer.route,
            "params" to params
        )
        screenContainer.onReceiveParams?.invoke(data)
        Log.d(TAG, "📦 onReceiveParams: ${screenContainer.route} | params: $params")
    }
}
