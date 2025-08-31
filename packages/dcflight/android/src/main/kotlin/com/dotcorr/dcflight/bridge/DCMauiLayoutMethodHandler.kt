/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree

/**
 * Handles layout method calls between Flutter and native Android for DCFlight
 * Manages layout calculations, updates, and component positioning
 */
class DCMauiLayoutMethodHandler private constructor() : MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var binaryMessenger: BinaryMessenger? = null

    companion object {
        private const val TAG = "DCMauiLayoutMethodHandler"
        private const val CHANNEL_NAME = "com.dotcorr.dcflight/layout"

        @JvmStatic
        val shared = DCMauiLayoutMethodHandler()
    }

    fun initialize(messenger: BinaryMessenger) {
        Log.d(TAG, "Initializing DCMauiLayoutMethodHandler")

        binaryMessenger = messenger
        methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)

        Log.d(TAG, "DCMauiLayoutMethodHandler initialized successfully")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")

        when (call.method) {
            "calculateLayout" -> {
                val componentId = call.argument<String>("componentId")
                val width = call.argument<Double>("width")?.toFloat()
                val height = call.argument<Double>("height")?.toFloat()

                if (componentId != null && width != null && height != null) {
                    calculateLayout(componentId, width, height, result)
                } else {
                    result.error("INVALID_ARGS", "componentId, width, and height required", null)
                }
            }

            "updateLayout" -> {
                val componentId = call.argument<String>("componentId")
                val layoutProps = call.argument<Map<String, Any>>("layoutProps")

                if (componentId != null && layoutProps != null) {
                    updateLayout(componentId, layoutProps, result)
                } else {
                    result.error("INVALID_ARGS", "componentId and layoutProps required", null)
                }
            }

            "getLayout" -> {
                val componentId = call.argument<String>("componentId")

                if (componentId != null) {
                    getLayout(componentId, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "invalidateLayout" -> {
                val componentId = call.argument<String>("componentId")

                if (componentId != null) {
                    invalidateLayout(componentId, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "markDirty" -> {
                val componentId = call.argument<String>("componentId")

                if (componentId != null) {
                    markDirty(componentId, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "applyLayoutChanges" -> {
                applyLayoutChanges(result)
            }

            "setFlexDirection" -> {
                val componentId = call.argument<String>("componentId")
                val direction = call.argument<String>("direction")

                if (componentId != null && direction != null) {
                    setFlexDirection(componentId, direction, result)
                } else {
                    result.error("INVALID_ARGS", "componentId and direction required", null)
                }
            }

            "setJustifyContent" -> {
                val componentId = call.argument<String>("componentId")
                val justifyContent = call.argument<String>("justifyContent")

                if (componentId != null && justifyContent != null) {
                    setJustifyContent(componentId, justifyContent, result)
                } else {
                    result.error("INVALID_ARGS", "componentId and justifyContent required", null)
                }
            }

            "setAlignItems" -> {
                val componentId = call.argument<String>("componentId")
                val alignItems = call.argument<String>("alignItems")

                if (componentId != null && alignItems != null) {
                    setAlignItems(componentId, alignItems, result)
                } else {
                    result.error("INVALID_ARGS", "componentId and alignItems required", null)
                }
            }

            "setPadding" -> {
                val componentId = call.argument<String>("componentId")
                val top = call.argument<Double>("top")?.toFloat()
                val right = call.argument<Double>("right")?.toFloat()
                val bottom = call.argument<Double>("bottom")?.toFloat()
                val left = call.argument<Double>("left")?.toFloat()

                if (componentId != null) {
                    setPadding(componentId, top, right, bottom, left, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "setMargin" -> {
                val componentId = call.argument<String>("componentId")
                val top = call.argument<Double>("top")?.toFloat()
                val right = call.argument<Double>("right")?.toFloat()
                val bottom = call.argument<Double>("bottom")?.toFloat()
                val left = call.argument<Double>("left")?.toFloat()

                if (componentId != null) {
                    setMargin(componentId, top, right, bottom, left, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "setPosition" -> {
                val componentId = call.argument<String>("componentId")
                val x = call.argument<Double>("x")?.toFloat()
                val y = call.argument<Double>("y")?.toFloat()

                if (componentId != null && x != null && y != null) {
                    setPosition(componentId, x, y, result)
                } else {
                    result.error("INVALID_ARGS", "componentId, x, and y required", null)
                }
            }

            "setSize" -> {
                val componentId = call.argument<String>("componentId")
                val width = call.argument<Double>("width")?.toFloat()
                val height = call.argument<Double>("height")?.toFloat()

                if (componentId != null) {
                    setSize(componentId, width, height, result)
                } else {
                    result.error("INVALID_ARGS", "componentId required", null)
                }
            }

            "setBorderRadius" -> {
                val componentId = call.argument<String>("componentId")
                val radius = call.argument<Double>("radius")?.toFloat()

                if (componentId != null && radius != null) {
                    setBorderRadius(componentId, radius, result)
                } else {
                    result.error("INVALID_ARGS", "componentId and radius required", null)
                }
            }

            "getScreenDimensions" -> {
                getScreenDimensions(result)
            }

            "performBatchUpdate" -> {
                val updates = call.argument<List<Map<String, Any>>>("updates")

                if (updates != null) {
                    performBatchUpdate(updates, result)
                } else {
                    result.error("INVALID_ARGS", "updates required", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun calculateLayout(componentId: String, width: Float, height: Float, result: Result) {
        try {
            Log.d(TAG, "Calculating layout for $componentId: ${width}x${height}")

            YogaShadowTree.shared.calculateLayout(componentId)
            DCFLayoutManager.shared.applyLayout(componentId, 0f, 0f, width, height)

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating layout", e)
            result.error("LAYOUT_ERROR", "Failed to calculate layout: ${e.message}", null)
        }
    }

    private fun updateLayout(componentId: String, layoutProps: Map<String, Any>, result: Result) {
        try {
            Log.d(TAG, "Updating layout for $componentId with props: $layoutProps")

            DCFLayoutManager.shared.updateLayoutProperties(componentId, layoutProps)
            YogaShadowTree.shared.markDirty(componentId)

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating layout", e)
            result.error("LAYOUT_ERROR", "Failed to update layout: ${e.message}", null)
        }
    }

    private fun getLayout(componentId: String, result: Result) {
        try {
            val layout = DCFLayoutManager.shared.getLayout(componentId)
            result.success(layout)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting layout", e)
            result.error("LAYOUT_ERROR", "Failed to get layout: ${e.message}", null)
        }
    }

    private fun invalidateLayout(componentId: String, result: Result) {
        try {
            Log.d(TAG, "Invalidating layout for $componentId")

            YogaShadowTree.shared.invalidate(componentId)
            DCFLayoutManager.shared.requestLayout(componentId)

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error invalidating layout", e)
            result.error("LAYOUT_ERROR", "Failed to invalidate layout: ${e.message}", null)
        }
    }

    private fun markDirty(componentId: String, result: Result) {
        try {
            YogaShadowTree.shared.markDirty(componentId)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error marking component dirty", e)
            result.error("LAYOUT_ERROR", "Failed to mark dirty: ${e.message}", null)
        }
    }

    private fun applyLayoutChanges(result: Result) {
        try {
            Log.d(TAG, "Applying layout changes")

            YogaShadowTree.shared.applyAllLayouts()
            DCFLayoutManager.shared.flushLayoutQueue()

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error applying layout changes", e)
            result.error("LAYOUT_ERROR", "Failed to apply layout changes: ${e.message}", null)
        }
    }

    private fun setFlexDirection(componentId: String, direction: String, result: Result) {
        try {
            DCFLayoutManager.shared.setFlexDirection(componentId, direction)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting flex direction", e)
            result.error("LAYOUT_ERROR", "Failed to set flex direction: ${e.message}", null)
        }
    }

    private fun setJustifyContent(componentId: String, justifyContent: String, result: Result) {
        try {
            DCFLayoutManager.shared.setJustifyContent(componentId, justifyContent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting justify content", e)
            result.error("LAYOUT_ERROR", "Failed to set justify content: ${e.message}", null)
        }
    }

    private fun setAlignItems(componentId: String, alignItems: String, result: Result) {
        try {
            DCFLayoutManager.shared.setAlignItems(componentId, alignItems)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting align items", e)
            result.error("LAYOUT_ERROR", "Failed to set align items: ${e.message}", null)
        }
    }

    private fun setPadding(
        componentId: String,
        top: Float?,
        right: Float?,
        bottom: Float?,
        left: Float?,
        result: Result
    ) {
        try {
            DCFLayoutManager.shared.setPadding(componentId, top, right, bottom, left)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting padding", e)
            result.error("LAYOUT_ERROR", "Failed to set padding: ${e.message}", null)
        }
    }

    private fun setMargin(
        componentId: String,
        top: Float?,
        right: Float?,
        bottom: Float?,
        left: Float?,
        result: Result
    ) {
        try {
            DCFLayoutManager.shared.setMargin(componentId, top, right, bottom, left)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting margin", e)
            result.error("LAYOUT_ERROR", "Failed to set margin: ${e.message}", null)
        }
    }

    private fun setPosition(componentId: String, x: Float, y: Float, result: Result) {
        try {
            DCFLayoutManager.shared.setPosition(componentId, x, y)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting position", e)
            result.error("LAYOUT_ERROR", "Failed to set position: ${e.message}", null)
        }
    }

    private fun setSize(componentId: String, width: Float?, height: Float?, result: Result) {
        try {
            DCFLayoutManager.shared.setSize(componentId, width, height)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting size", e)
            result.error("LAYOUT_ERROR", "Failed to set size: ${e.message}", null)
        }
    }

    private fun setBorderRadius(componentId: String, radius: Float, result: Result) {
        try {
            DCFLayoutManager.shared.setBorderRadius(componentId, radius)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting border radius", e)
            result.error("LAYOUT_ERROR", "Failed to set border radius: ${e.message}", null)
        }
    }

    private fun getScreenDimensions(result: Result) {
        try {
            val dimensions = DCFLayoutManager.shared.getScreenDimensions()
            result.success(dimensions)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screen dimensions", e)
            result.error("LAYOUT_ERROR", "Failed to get screen dimensions: ${e.message}", null)
        }
    }

    private fun performBatchUpdate(updates: List<Map<String, Any>>, result: Result) {
        try {
            Log.d(TAG, "Performing batch update with ${updates.size} updates")

            DCFLayoutManager.shared.beginBatchUpdate()

            for (update in updates) {
                val componentId = update["componentId"] as? String
                val layoutProps = update["layoutProps"] as? Map<String, Any>

                if (componentId != null && layoutProps != null) {
                    DCFLayoutManager.shared.updateLayoutProperties(componentId, layoutProps)
                }
            }

            DCFLayoutManager.shared.endBatchUpdate()

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error performing batch update", e)
            result.error("LAYOUT_ERROR", "Failed to perform batch update: ${e.message}", null)
        }
    }

    /**
     * Send layout update notification to Flutter
     */
    fun notifyLayoutUpdate(componentId: String, layout: Map<String, Any>) {
        Log.d(TAG, "Notifying layout update for $componentId")

        methodChannel?.invokeMethod(
            "onLayoutUpdate", mapOf(
                "componentId" to componentId,
                "layout" to layout
            )
        )
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiLayoutMethodHandler")

        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        binaryMessenger = null

        Log.d(TAG, "DCMauiLayoutMethodHandler cleaned up")
    }
}
