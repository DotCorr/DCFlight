/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * DcfReanimatedPlugin
 *
 * This plugin registers all reanimated UI components with the DCFlight framework.
 * It serves as the entry point for the dcf_reanimated package on Android.
 */
class DcfReanimatedPlugin : FlutterPlugin {

    companion object {
        private const val TAG = "DcfReanimatedPlugin"
        private var isRegistered = false
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfReanimatedPlugin: onAttachedToEngine called")

        if (!isRegistered) {
            try {
                ReanimatedComponentsReg.registerComponents()
                isRegistered = true
                Log.d(TAG, "✅ DcfReanimatedPlugin: Successfully registered reanimated components")
            } catch (e: Exception) {
                Log.e(TAG, "❌ DcfReanimatedPlugin: Failed to register reanimated components", e)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfReanimatedPlugin: onDetachedFromEngine called")
    }
}
