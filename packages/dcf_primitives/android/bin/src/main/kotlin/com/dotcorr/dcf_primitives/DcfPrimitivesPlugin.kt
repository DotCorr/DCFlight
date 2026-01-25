/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives

import io.flutter.embedding.engine.plugins.FlutterPlugin

class DcfPrimitives {
    companion object {
        @JvmStatic
        fun registerComponents() {
            PrimitivesComponentsReg.registerComponents()
        }
    }
}

/**
 * FlutterPlugin wrapper - minimal, just for Flutter discovery
 * Matches iOS registerWithRegistrar pattern
 */
class DcfPrimitivesPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DcfPrimitives.registerComponents()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No cleanup needed
    }
}
