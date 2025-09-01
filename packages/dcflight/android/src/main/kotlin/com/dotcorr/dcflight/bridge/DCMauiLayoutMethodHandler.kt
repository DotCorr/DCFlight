/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

/**
 * Handles layout-related method calls from Flutter
 */
class DCMauiLayoutMethodHandler : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "DCMauiLayoutMethodHandler"

        @JvmField
        val shared = DCMauiLayoutMethodHandler()

        fun initialize(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
            val channel = MethodChannel(binaryMessenger, "com.dotcorr.dcflight/layout")
            channel.setMethodCallHandler(shared)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "calculateLayout" -> {
                handleCalculateLayout(call.arguments as? Map<String, Any>, result)
            }
            "setUseWebDefaults" -> {
                handleSetUseWebDefaults(call.arguments as? Map<String, Any>, result)
            }
            "getUseWebDefaults" -> {
                handleGetUseWebDefaults(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleCalculateLayout(args: Map<String, Any>?, result: Result) {
        val nodeId = args?.get("nodeId") as? String

        if (nodeId == null) {
            result.error("LAYOUT_ERROR", "Invalid node ID", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val layout = YogaShadowTree.shared.calculateLayout(nodeId)
            if (layout != null) {
                result.success(layout)
            } else {
                result.error("LAYOUT_FAILED", "Failed to calculate layout for node $nodeId", null)
            }
        }
    }

    private fun handleSetUseWebDefaults(args: Map<String, Any>?, result: Result) {
        val enabled = args?.get("enabled") as? Boolean

        if (enabled == null) {
            result.error("ARGS_ERROR", "Invalid enabled parameter", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            DCFLayoutManager.shared.setUseWebDefaults(enabled)
            result.success(true)
        }
    }

    private fun handleGetUseWebDefaults(result: Result) {
        Handler(Looper.getMainLooper()).post {
            val enabled = DCFLayoutManager.shared.getUseWebDefaults()
            result.success(enabled)
        }
    }
}