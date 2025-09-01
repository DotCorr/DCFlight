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
            val channel = MethodChannel(binaryMessenger, "com.dotcorr.dcflight/events")
            channel.setMethodCallHandler(shared)
        }
    }

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
}