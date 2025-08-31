/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * DcfPrimitivesPlugin
 *
 * This plugin registers all primitive UI components with the DCFlight framework.
 * It serves as the entry point for the dcf_primitives package on Android.
 */
class DcfPrimitivesPlugin : FlutterPlugin {

    companion object {
        private const val TAG = "DcfPrimitivesPlugin"
        private var isRegistered = false
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfPrimitivesPlugin: onAttachedToEngine called")

        // Register primitive components only once
        if (!isRegistered) {
            registerPrimitiveComponents()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfPrimitivesPlugin: onDetachedFromEngine called")
        // Components remain registered for the lifetime of the app
    }

    private fun registerPrimitiveComponents() {
        Log.d(TAG, "Registering primitive components with DCFlight framework")

        try {
            // Register all primitive components with the framework registry
            PrimitivesComponentsReg.registerComponents()
            isRegistered = true
            Log.d(TAG, "✅ DcfPrimitivesPlugin: Successfully registered primitive components")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DcfPrimitivesPlugin: Failed to register primitive components", e)
            // Don't set isRegistered to true so it can be retried
        }

        // Verify registration
        if (isRegistered) {
            PrimitivesComponentsReg.verifyRegistration()
        }
    }
}
