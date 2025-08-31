/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Handles event communication between Flutter and native Android for DCFlight
 */
class DCMauiEventMethodHandler private constructor() : MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var binaryMessenger: BinaryMessenger? = null

    companion object {
        private const val TAG = "DCMauiEventMethodHandler"
        private const val METHOD_CHANNEL_NAME = "com.dotcorr.dcflight/events"
        private const val EVENT_CHANNEL_NAME = "com.dotcorr.dcflight/event_stream"

        @JvmStatic
        val shared = DCMauiEventMethodHandler()
    }

    fun initialize(messenger: BinaryMessenger) {
        Log.d(TAG, "Initializing DCMauiEventMethodHandler")

        binaryMessenger = messenger

        // Setup method channel for event control
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)

        // Setup event channel for streaming events
        eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "Event stream listener attached")
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "Event stream listener cancelled")
                eventSink = null
            }
        })

        Log.d(TAG, "DCMauiEventMethodHandler initialized successfully")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")

        when (call.method) {
            "sendEvent" -> {
                val eventData = call.arguments as? Map<String, Any?>
                if (eventData != null) {
                    sendEventToFlutter(eventData)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "Event data must be a Map", null)
                }
            }

            "registerEventHandler" -> {
                val handlerType = call.argument<String>("type")
                val identifier = call.argument<String>("identifier")
                registerEventHandler(handlerType, identifier)
                result.success(true)
            }

            "unregisterEventHandler" -> {
                val identifier = call.argument<String>("identifier")
                unregisterEventHandler(identifier)
                result.success(true)
            }

            "dispatchEvent" -> {
                val eventType = call.argument<String>("type")
                val eventData = call.argument<Map<String, Any?>>("data")
                dispatchEvent(eventType, eventData)
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Send an event from native to Flutter
     */
    fun sendEventToFlutter(eventData: Map<String, Any?>) {
        Log.d(TAG, "Sending event to Flutter: $eventData")
        eventSink?.success(eventData) ?: Log.w(TAG, "Event sink is null, cannot send event")
    }

    /**
     * Send a component event to Flutter
     */
    fun sendComponentEvent(componentId: String, eventType: String, data: Map<String, Any?>?) {
        val eventData = mutableMapOf<String, Any?>(
            "componentId" to componentId,
            "eventType" to eventType,
            "timestamp" to System.currentTimeMillis()
        )

        data?.let {
            eventData["data"] = it
        }

        sendEventToFlutter(eventData)
    }

    /**
     * Send a touch event to Flutter
     */
    fun sendTouchEvent(componentId: String, touchType: String, x: Float, y: Float, pressure: Float = 1.0f) {
        val eventData = mapOf(
            "componentId" to componentId,
            "eventType" to "touch",
            "touchType" to touchType,
            "x" to x,
            "y" to y,
            "pressure" to pressure,
            "timestamp" to System.currentTimeMillis()
        )

        sendEventToFlutter(eventData)
    }

    /**
     * Send a value change event to Flutter
     */
    fun sendValueChangeEvent(componentId: String, value: Any?) {
        val eventData = mapOf(
            "componentId" to componentId,
            "eventType" to "valueChanged",
            "value" to value,
            "timestamp" to System.currentTimeMillis()
        )

        sendEventToFlutter(eventData)
    }

    /**
     * Send a lifecycle event to Flutter
     */
    fun sendLifecycleEvent(eventType: String, data: Map<String, Any?>? = null) {
        val eventData = mutableMapOf<String, Any?>(
            "eventType" to "lifecycle",
            "lifecycleEvent" to eventType,
            "timestamp" to System.currentTimeMillis()
        )

        data?.let {
            eventData["data"] = it
        }

        sendEventToFlutter(eventData)
    }

    /**
     * Send a layout event to Flutter
     */
    fun sendLayoutEvent(componentId: String, x: Float, y: Float, width: Float, height: Float) {
        val eventData = mapOf(
            "componentId" to componentId,
            "eventType" to "layout",
            "x" to x,
            "y" to y,
            "width" to width,
            "height" to height,
            "timestamp" to System.currentTimeMillis()
        )

        sendEventToFlutter(eventData)
    }

    /**
     * Register an event handler for a specific type
     */
    private fun registerEventHandler(type: String?, identifier: String?) {
        Log.d(TAG, "Registering event handler: type=$type, identifier=$identifier")
        // Store handler registration if needed
    }

    /**
     * Unregister an event handler
     */
    private fun unregisterEventHandler(identifier: String?) {
        Log.d(TAG, "Unregistering event handler: identifier=$identifier")
        // Remove handler registration if needed
    }

    /**
     * Dispatch an event from Flutter to native
     */
    private fun dispatchEvent(eventType: String?, eventData: Map<String, Any?>?) {
        Log.d(TAG, "Dispatching event: type=$eventType, data=$eventData")

        // Handle different event types
        when (eventType) {
            "componentTap" -> handleComponentTap(eventData)
            "componentLongPress" -> handleComponentLongPress(eventData)
            "componentDoubleTap" -> handleComponentDoubleTap(eventData)
            "componentDrag" -> handleComponentDrag(eventData)
            "componentPinch" -> handleComponentPinch(eventData)
            else -> Log.w(TAG, "Unknown event type: $eventType")
        }
    }

    private fun handleComponentTap(data: Map<String, Any?>?) {
        val componentId = data?.get("componentId") as? String
        Log.d(TAG, "Component tap: $componentId")
        // Handle tap event
    }

    private fun handleComponentLongPress(data: Map<String, Any?>?) {
        val componentId = data?.get("componentId") as? String
        Log.d(TAG, "Component long press: $componentId")
        // Handle long press event
    }

    private fun handleComponentDoubleTap(data: Map<String, Any?>?) {
        val componentId = data?.get("componentId") as? String
        Log.d(TAG, "Component double tap: $componentId")
        // Handle double tap event
    }

    private fun handleComponentDrag(data: Map<String, Any?>?) {
        val componentId = data?.get("componentId") as? String
        val deltaX = (data?.get("deltaX") as? Number)?.toFloat() ?: 0f
        val deltaY = (data?.get("deltaY") as? Number)?.toFloat() ?: 0f
        Log.d(TAG, "Component drag: $componentId, delta: ($deltaX, $deltaY)")
        // Handle drag event
    }

    private fun handleComponentPinch(data: Map<String, Any?>?) {
        val componentId = data?.get("componentId") as? String
        val scale = (data?.get("scale") as? Number)?.toFloat() ?: 1f
        Log.d(TAG, "Component pinch: $componentId, scale: $scale")
        // Handle pinch event
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiEventMethodHandler")

        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        eventSink = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null

        binaryMessenger = null

        Log.d(TAG, "DCMauiEventMethodHandler cleaned up")
    }
}
