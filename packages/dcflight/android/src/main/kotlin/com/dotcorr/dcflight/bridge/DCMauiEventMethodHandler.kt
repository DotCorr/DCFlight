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
            // Store the method channel in the shared instance like iOS
            shared.methodChannel = channel
            Log.d(TAG, "✅ METHOD CHANNEL INITIALIZED AND STORED: ${shared.methodChannel}")
        }

        fun getInstance(): DCMauiEventMethodHandler {
            return shared
        }
    }

    // Store the method channel instance like iOS does
    internal var methodChannel: MethodChannel? = null

    private val eventCallbacks = ConcurrentHashMap<String, MutableMap<String, EventCallback>>()
    private val viewEventListeners = ConcurrentHashMap<String, MutableSet<String>>()

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
        val viewId = args?.get("viewId") as? String
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
        val viewId = args?.get("viewId") as? String
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
        val viewId = args?.get("viewId") as? String
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

    // Handle addEventListeners calls (match iOS API)
    private fun handleAddEventListeners(args: Map<String, Any>?, result: Result) {
        val viewId = args?.get("viewId") as? String
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

        // 🚀 UNIFIED EVENT SYSTEM: Use same tag system as propagateEvent (matches iOS)
        // Store viewId and eventTypes on the view using resource IDs (not hash codes)
        view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, viewId)
        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, eventTypes.toSet())

        // 🚀 CRITICAL FIX: Store event callback that sends to Flutter (matches iOS exactly)
        // This is what was missing - Android propagateEvent expects to find this callback!
        val eventCallback: (String, Map<String, Any?>) -> Unit = { eventType, eventData ->
            // Always use the shared instance to ensure the method channel is available
            shared.sendEventToFlutter(viewId, eventType, eventData)
        }
        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_callback, eventCallback)

        Log.d(TAG, "Event listeners registered for view $viewId: $eventTypes")
        result.success(true)
    }
    
    /**
     * Public method to add event listeners without Flutter Result (for batch operations)
     */
    fun addEventListenersForBatch(viewId: String, eventTypes: List<String>): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View $viewId not found for event listener registration")
            return false
        }

        // Store viewId and eventTypes on the view
        view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, viewId)
        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, eventTypes.toSet())

        // Store event callback that sends to Flutter
        val eventCallback: (String, Map<String, Any?>) -> Unit = { eventType, eventData ->
            shared.sendEventToFlutter(viewId, eventType, eventData)
        }
        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_callback, eventCallback)

        Log.d(TAG, "Event listeners registered for view $viewId: $eventTypes")
        return true
    }

    /**
     * Sends events back to Flutter via method channel - matches iOS sendEvent exactly
     */
    internal fun sendEventToFlutter(viewId: String, eventName: String, eventData: Map<String, Any?>) {
        try {
            Log.d(TAG, "📨 Attempting to send event to DCFEngine - viewId: $viewId, eventName: $eventName, eventData: $eventData")
            Log.d(TAG, "🔍 METHOD CHANNEL STATUS: $methodChannel")
            Log.d(TAG, "🔍 IS CHANNEL NULL? ${methodChannel == null}")
            
            // Use the stored method channel like iOS does
            methodChannel?.let { channel ->
                val arguments = mapOf(
                    "viewId" to viewId,
                    "eventType" to eventName,  
                    "eventData" to eventData
                )
                
                Log.d(TAG, "📤 Calling method channel onEvent with arguments: $arguments")
                
                // Run on main thread like iOS
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel.invokeMethod("onEvent", arguments)
                }
            } ?: Log.e(TAG, "❌ Method channel is null - cannot send event to Flutter")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter: ${e.message}", e)
        }
    }

    // Handle removeEventListeners calls (match iOS API)
    private fun handleRemoveEventListeners(args: Map<String, Any>?, result: Result) {
        val viewId = args?.get("viewId") as? String
        val eventTypes = args?.get("eventTypes") as? List<String>

        if (viewId == null || eventTypes == null) {
            result.error("INVALID_ARGS", "Invalid arguments for removeEventListeners", null)
            return
        }

        val view = ViewRegistry.shared.getView(viewId)
        if (view != null) {
            // Clean up stored data - use resource IDs like addEventListeners
            view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, null)
            view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, null)
            view.setTag(com.dotcorr.dcflight.R.id.dcf_event_callback, null)
        }

        result.success(true)
    }

    // Normalize event name to follow React-style convention (match iOS)
    private fun normalizeEventName(name: String): String {
        // If already has "on" prefix and it's followed by uppercase letter, return as is
        if (name.startsWith("on") && name.length > 2) {
            val thirdChar = name[2]
            if (thirdChar.isUpperCase()) {
                return name
            }
        }
        
        // Otherwise normalize: remove "on" if it exists, capitalize first letter, and add "on" prefix
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