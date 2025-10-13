
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import com.dotcorr.dcfscreens.components.navigation.ScreenComponentsReg


class DcfScreensPlugin : FlutterPlugin {

    companion object {
        private const val TAG = "DcfScreensPlugin"
        private var isRegistered = false
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfScreensPlugin: onAttachedToEngine called")

        if (!isRegistered) {
            registerPrimitiveComponents()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfScreensPlugin: onDetachedFromEngine called")
    }

    private fun registerPrimitiveComponents() {
        Log.d(TAG, "Registering primitive components with DCFlight framework")

        try {
            ScreenComponentsReg.registerComponents()
            isRegistered = true
            Log.d(TAG, "✅ DcfScreensPlugin: Successfully registered primitive components")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DcfScreensPlugin: Failed to register primitive components", e)
        }
    }
}

