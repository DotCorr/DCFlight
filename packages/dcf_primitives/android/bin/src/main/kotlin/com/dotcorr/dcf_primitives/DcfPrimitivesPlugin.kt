/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
