/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_reanimated

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * DcfReanimated - matches iOS pattern exactly
 * Simple class with registerComponents() - no Flutter dependency in registration logic
 */
class DcfReanimated {
    companion object {
        @JvmStatic
        fun registerComponents() {
            ReanimatedComponentsReg.registerComponents()
        }
    }
}

/**
 * FlutterPlugin wrapper - minimal, just for Flutter discovery
 * Matches iOS registerWithRegistrar pattern
 */
class DcfReanimatedPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DcfReanimated.registerComponents()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No cleanup needed
    }
}

