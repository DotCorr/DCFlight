/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import com.dotcorr.dcflight.layout.ViewRegistry
import java.util.concurrent.ConcurrentHashMap

typealias EventCallback = (Map<String, Any>) -> Unit

/**
 * Handles event-related method calls from Flutter
 */
class DCMauiEventMethodHandler : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "DCMauiEventMethodHandler"

        @JvmField
        val shared = DCMauiEventMethodHandler()

        fun initialize(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
            Log.d(TAG, "🚀 INITIALIZING METHOD CHANNEL: com.dcmaui.events")
            val channel = MethodChannel(binaryMessenger, "com.dcmaui.events")
            channel.setMethodCallHandler(shared)
            shared.methodChannel = channel
            Log.d(TAG, "✅ METHOD CHANNEL INITIALIZED AND STORED: ${shared.methodChannel}")
        }

        fun getInstance(): DCMauiEventMethodHandler {
            return shared
        }
    }

    internal var methodChannel: MethodChannel? = null

    private val eventCallbacks = ConcurrentHashMap<Int, MutableMap<String, EventCallback>>()
    private val viewEventListeners = ConcurrentHashMap<Int, MutableSet<String>>()

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "registerEvent" -> {
                handleRegisterEvent(call.arguments as? Map<String, Any>, result)
            }
            "unregisterEvent" -> {
                handleUnregisterEvent(call.arguments as? Map<String, Any>, result)
            }
            "dispatchEvent" -> {
                handleDispatchEvent(call.arguments as? Map<String, Any>, result)
            }
            "addEventListeners" -> {
                handleAddEventListeners(call.arguments as? Map<String, Any>, result)
            }
            "removeEventListeners" -> {
                handleRemoveEventListeners(call.arguments as? Map<String, Any>, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleRegisterEvent(args: Map<String, Any>?, result: Result) {
        val viewId = (args?.get("viewId") as? Number)?.toInt() ?: (args?.get("viewId") as? Int)
        val eventType = args?.get("eventType") as? String
        val callbackId = args?.get("callbackId") as? String

        if (viewId == null || eventType == null || callbackId == null) {
            result.error("REGISTER_ERROR", "Invalid event registration parameters", null)
            return
        }

        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            result.error("VIEW_NOT_FOUND", "View $viewId not found", null)
            return
        }

        val callback: EventCallback = { eventData ->
            Log.d(TAG, "Event $eventType fired for view $viewId")
        }

        eventCallbacks.getOrPut(viewId) { mutableMapOf() }[eventType] = callback
        viewEventListeners.getOrPut(viewId) { mutableSetOf() }.add(eventType)

        setupNativeEventListener(view, eventType, callback)

        result.success(true)
    }

    private fun handleUnregisterEvent(args: Map<String, Any>?, result: Result) {
        val viewId = (args?.get("viewId") as? Number)?.toInt() ?: (args?.get("viewId") as? Int)
        val eventType = args?.get("eventType") as? String

        if (viewId == null || eventType == null) {
            result.error("UNREGISTER_ERROR", "Invalid event unregistration parameters", null)
            return
        }

        eventCallbacks[viewId]?.remove(eventType)
        viewEventListeners[viewId]?.remove(eventType)

        val view = ViewRegistry.shared.getView(viewId)
        if (view != null) {
            removeNativeEventListener(view, eventType)
        }

        result.success(true)
    }

    private fun handleDispatchEvent(args: Map<String, Any>?, result: Result) {
        val viewId = (args?.get("viewId") as? Number)?.toInt() ?: (args?.get("viewId") as? Int)
        val eventType = args?.get("eventType") as? String
        val eventData = args?.get("eventData") as? Map<String, Any>

        if (viewId == null || eventType == null) {
            result.error("DISPATCH_ERROR", "Invalid event dispatch parameters", null)
            return
        }

        val callback = eventCallbacks[viewId]?.get(eventType)
        if (callback != null) {
            callback(eventData ?: emptyMap())
            result.success(true)
        } else {
            result.error("NO_LISTENER", "No listener registered for $eventType on view $viewId", null)
        }
    }

    private fun setupNativeEventListener(view: android.view.View, eventType: String, callback: EventCallback) {
        when (eventType) {
            "onPress", "onClick" -> {
                view.setOnClickListener {
                    callback(mapOf(
                        "type" to "press",
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            }
            "onLongPress" -> {
                view.setOnLongClickListener {
                    callback(mapOf(
                        "type" to "longPress",
                        "timestamp" to System.currentTimeMillis()
                    ))
                    true
                }
            }
            "onFocus" -> {
                view.setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus) {
                        callback(mapOf(
                            "type" to "focus",
                            "timestamp" to System.currentTimeMillis()
                        ))
                    }
                }
            }
            "onBlur" -> {
                view.setOnFocusChangeListener { _, hasFocus ->
                    if (!hasFocus) {
                        callback(mapOf(
                            "type" to "blur",
                            "timestamp" to System.currentTimeMillis()
                        ))
                    }
                }
            }
            else -> {
                Log.w(TAG, "Unknown event type: $eventType")
            }
        }
    }

    private fun removeNativeEventListener(view: android.view.View, eventType: String) {
        when (eventType) {
            "onPress", "onClick" -> {
                view.setOnClickListener(null)
            }
            "onLongPress" -> {
                view.setOnLongClickListener(null)
            }
            "onFocus", "onBlur" -> {
                view.setOnFocusChangeListener(null)
            }
        }
    }

    fun cleanup() {
        eventCallbacks.clear()
        viewEventListeners.clear()
    }

    private fun handleAddEventListeners(args: Map<String, Any>?, result: Result) {
        val viewId = (args?.get("viewId") as? Number)?.toInt() ?: (args?.get("viewId") as? Int)
        val eventTypes = args?.get("eventTypes") as? List<String>

        if (viewId == null || eventTypes == null) {
            result.error("INVALID_ARGS", "Invalid arguments for addEventListeners", null)
            return
        }

        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            result.error("VIEW_NOT_FOUND", "View $viewId not found", null)
            return
        }

        // ✅ Use pure Kotlin tag keys instead of XML resource IDs
        view.setTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY, viewId)
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, eventTypes.toSet())

        val eventCallback: (String, Map<String, Any?>) -> Unit = { eventType, eventData ->
            shared.sendEventToFlutter(viewId, eventType, eventData)
        }
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_CALLBACK_KEY, eventCallback)

        Log.d(TAG, "Event listeners registered for view $viewId: $eventTypes")
        result.success(true)
    }
    
    /**
     * Public method to add event listeners without Flutter Result (for batch operations)
     */
    fun addEventListenersForBatch(viewId: Int, eventTypes: List<String>): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View $viewId not found for event listener registration")
            return false
        }

        // ✅ Use pure Kotlin tag keys instead of XML resource IDs
        view.setTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY, viewId)
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, eventTypes.toSet())

        val eventCallback: (String, Map<String, Any?>) -> Unit = { eventType, eventData ->
            shared.sendEventToFlutter(viewId, eventType, eventData)
        }
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_CALLBACK_KEY, eventCallback)

        // FRAMEWORK: Automatically enable touch handling for components with event handlers
        // This ensures 1:1 parity with iOS - no manual component-level glue code needed
        if (eventTypes.isNotEmpty()) {
            val hasTouchEvents = eventTypes.any { it.contains("Press", ignoreCase = true) || 
                                                   it.contains("Tap", ignoreCase = true) ||
                                                   it.contains("LongPress", ignoreCase = true) ||
                                                   it.contains("Swipe", ignoreCase = true) ||
                                                   it.contains("Pan", ignoreCase = true) ||
                                                   it.contains("Gesture", ignoreCase = true) }
            if (hasTouchEvents) {
                view.isClickable = true
                view.isFocusable = true
                view.isFocusableInTouchMode = true
            }
        }

        Log.d(TAG, "Event listeners registered for view $viewId: $eventTypes")
        return true
    }

    /**
     * Sends events back to Flutter via method channel - matches iOS sendEvent exactly
     */
    internal fun sendEventToFlutter(viewId: Int, eventName: String, eventData: Map<String, Any?>) {
        try {
            Log.d(TAG, "📨 Attempting to send event to DCFEngine - viewId: $viewId, eventName: $eventName, eventData: $eventData")
            Log.d(TAG, "🔍 METHOD CHANNEL STATUS: $methodChannel")
            Log.d(TAG, "🔍 IS CHANNEL NULL? ${methodChannel == null}")
            
            methodChannel?.let { channel ->
                val arguments = mapOf(
                    "viewId" to viewId,
                    "eventType" to eventName,  
                    "eventData" to eventData
                )
                
                Log.d(TAG, "📤 Calling method channel onEvent with arguments: $arguments")
                
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel.invokeMethod("onEvent", arguments)
                }
            } ?: Log.e(TAG, "❌ Method channel is null - cannot send event to Flutter")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter: ${e.message}", e)
        }
    }

    private fun handleRemoveEventListeners(args: Map<String, Any>?, result: Result) {
        val viewId = (args?.get("viewId") as? Number)?.toInt() ?: (args?.get("viewId") as? Int)
        val eventTypes = args?.get("eventTypes") as? List<String>

        if (viewId == null || eventTypes == null) {
            result.error("INVALID_ARGS", "Invalid arguments for removeEventListeners", null)
            return
        }

        val view = ViewRegistry.shared.getView(viewId)
        if (view != null) {
            // ✅ Use pure Kotlin tag keys instead of XML resource IDs
            view.setTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY, null)
            view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, null)
            view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_CALLBACK_KEY, null)
        }

        result.success(true)
    }

    private fun normalizeEventName(name: String): String {
        if (name.startsWith("on") && name.length > 2) {
            val thirdChar = name[2]
            if (thirdChar.isUpperCase()) {
                return name
            }
        }
        
        var processedName = name
        if (processedName.startsWith("on")) {
            processedName = processedName.drop(2)
        }
        
        if (processedName.isEmpty()) {
            return "onEvent"
        }
        
        return "on${processedName.replaceFirstChar { it.uppercase() }}"
    }
}