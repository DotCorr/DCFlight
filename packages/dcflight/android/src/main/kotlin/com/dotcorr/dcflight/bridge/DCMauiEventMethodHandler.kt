/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * CRITICAL FIX: Method channel handler for all event-related operations
 * Now matches iOS DCMauiEventMethodHandler exactly
 */
class DCMauiEventMethodHandler private constructor() : MethodCallHandler {
    
    companion object {
        private const val TAG = "DCMauiEventMethodHandler"
        // CRITICAL FIX: Use EXACT iOS channel name
        private const val METHOD_CHANNEL_NAME = "com.dcmaui.events"

        @JvmStatic
        val shared = DCMauiEventMethodHandler()
    }

    // Method channel for event operations
    private var methodChannel: MethodChannel? = null

    // Event callback closure type - EXACT iOS pattern
    typealias EventCallback = (String, String, Map<String, Any?>) -> Unit

    // Store the event callback
    private var eventCallback: EventCallback? = null

    /**
     * Initialize with Flutter binary messenger - EXACT iOS pattern
     */
    fun initialize(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Initializing DCMauiEventMethodHandler")

        methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME)
        setupMethodCallHandler()

        Log.d(TAG, "DCMauiEventMethodHandler initialized successfully")
    }

    /**
     * Register method call handler - EXACT iOS pattern
     */
    private fun setupMethodCallHandler() {
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "Event method call: ${call.method}")

            when (call.method) {
                "addEventListeners" -> {
                    handleAddEventListeners(call, result)
                }

                "removeEventListeners" -> {
                    handleRemoveEventListeners(call, result)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Set event callback function - EXACT iOS pattern
     */
    fun setEventCallback(callback: EventCallback) {
        this.eventCallback = callback
    }

    /**
     * Send event to Dart - EXACT iOS pattern
     */
    fun sendEvent(viewId: String, eventName: String, eventData: Map<String, Any?>) {
        Log.d(TAG, "Sending event: $eventName for view: $viewId")

        // Ensure event name follows "on" convention like iOS
        val normalizedEventName = normalizeEventName(eventName)

        if (eventCallback != null) {
            // Use the stored callback if available
            eventCallback!!(viewId, normalizedEventName, eventData)
        } else {
            // Fall back to method channel
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onEvent", mapOf(
                    "viewId" to viewId,
                    "eventType" to normalizedEventName,
                    "eventData" to eventData
                ))
            }
        }
    }

    /**
     * Normalize event name to follow React-style convention - EXACT iOS logic
     */
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
            processedName = processedName.substring(2)
        }

        if (processedName.isEmpty()) {
            return "onEvent"
        }

        return "on${processedName.substring(0, 1).uppercase()}${processedName.substring(1)}"
    }

    // MARK: - Method handlers

    /**
     * Handle addEventListeners calls - EXACT iOS pattern
     */
    private fun handleAddEventListeners(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any>
        val viewId = args?.get("viewId") as? String
        val eventTypes = args?.get("eventTypes") as? List<String>

        if (viewId == null || eventTypes == null) {
            result.error("INVALID_ARGS", "Invalid arguments for addEventListeners", null)
            return
        }

        Log.d(TAG, "Adding event listeners for view: $viewId, events: $eventTypes")

        // Get view from the registry like iOS
        var view: View? = DCMauiBridgeMethodChannel.shared.getViewById(viewId)

        // If still not found, try the LayoutManager like iOS
        if (view == null) {
            view = DCFLayoutManager.shared.getView(viewId)
        }

        if (view == null) {
            Log.w(TAG, "View not found: $viewId")
            // Return success anyway to prevent Flutter errors like iOS
            result.success(true)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            // Now register event listeners with the found view
            val success = registerEventListeners(view, viewId, eventTypes)
            result.success(success)
        }
    }

    /**
     * Handle removeEventListeners calls - EXACT iOS pattern
     */
    private fun handleRemoveEventListeners(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any>
        val viewId = args?.get("viewId") as? String
        val eventTypes = args?.get("eventTypes") as? List<String>

        if (viewId == null || eventTypes == null) {
            result.error("INVALID_ARGS", "Invalid arguments for removeEventListeners", null)
            return
        }

        Log.d(TAG, "Removing event listeners for view: $viewId, events: $eventTypes")

        // Get view from the registry like iOS
        var view: View? = DCMauiBridgeMethodChannel.shared.getViewById(viewId)

        // If still not found, try the LayoutManager like iOS
        if (view == null) {
            view = DCFLayoutManager.shared.getView(viewId)
        }

        if (view == null) {
            Log.w(TAG, "View not found: $viewId")
            // Return success anyway to prevent Flutter errors like iOS
            result.success(true)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            // Now unregister event listeners with the found view
            val success = unregisterEventListeners(view, viewId, eventTypes)
            result.success(success)
        }
    }

    /**
     * CRITICAL FIX: Helper method to register event listeners - EXACT iOS pattern
     */
    private fun registerEventListeners(view: View, viewId: String, eventTypes: List<String>): Boolean {
        val viewType = view::class.simpleName

        // Normalize event types for consistency like iOS
        val normalizedEventTypes = eventTypes.map { normalizeEventName(it) }

        // Store both original and normalized event types like iOS
        val allEventTypes = mutableSetOf<String>()
        allEventTypes.addAll(eventTypes)
        allEventTypes.addAll(normalizedEventTypes)

        Log.d(TAG, "Registering events for $viewType view $viewId: $allEventTypes")

        // CRITICAL FIX: Store event registration info directly on the view for global event system like iOS
        view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, viewId)
        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, allEventTypes.toList())

        // Store the event callback for the global system to use like iOS
        val eventCallback: (String, String, Map<String, Any?>) -> Unit = { viewId, eventType, eventData ->
            this.sendEvent(viewId, eventType, eventData)
        }

        view.setTag(com.dotcorr.dcflight.R.id.dcf_event_callback, eventCallback)

        return true
    }

    /**
     * CRITICAL FIX: Helper method to unregister event listeners - EXACT iOS pattern
     */
    private fun unregisterEventListeners(view: View, viewId: String, eventTypes: List<String>): Boolean {
        val storedEventTypes = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_types) as? List<String>
        if (storedEventTypes != null) {
            val remainingTypes = storedEventTypes.toMutableList()

            for (eventType in eventTypes) {
                val normalizedType = normalizeEventName(eventType)
                remainingTypes.remove(normalizedType)
            }

            if (remainingTypes.isEmpty()) {
                // Clear all event data if no events remain like iOS
                view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, null)
                view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, null)
                view.setTag(com.dotcorr.dcflight.R.id.dcf_event_callback, null)
            } else {
                // Update remaining event types
                view.setTag(com.dotcorr.dcflight.R.id.dcf_event_types, remainingTypes)
            }
        }

        return true
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiEventMethodHandler")
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventCallback = null
        Log.d(TAG, "DCMauiEventMethodHandler cleanup complete")
    }
}

