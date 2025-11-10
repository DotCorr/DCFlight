/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_module

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * DcfModulePlugin
 *
 * This plugin registers all module components with the DCFlight framework.
 * It serves as the entry point for the dcf_module package on Android.
 */
class DcfModulePlugin : FlutterPlugin {

    companion object {
        private const val TAG = "DcfModulePlugin"
        private var isRegistered = false
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfModulePlugin: onAttachedToEngine called")

        if (!isRegistered) {
            registerModuleComponents()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "DcfModulePlugin: onDetachedFromEngine called")
    }

    private fun registerModuleComponents() {
        Log.d(TAG, "Registering module components with DCFlight framework")

        try {
            ModuleComponentsReg.registerComponents()
            isRegistered = true
            Log.d(TAG, "✅ DcfModulePlugin: Successfully registered module components")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DcfModulePlugin: Failed to register module components", e)
        }
    }
}

