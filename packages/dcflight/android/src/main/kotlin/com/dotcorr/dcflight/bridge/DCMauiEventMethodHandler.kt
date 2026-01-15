/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import com.dotcorr.dcflight.layout.ViewRegistry
import java.util.concurrent.ConcurrentHashMap

typealias EventCallback = (Map<String, Any>) -> Unit

class DCMauiEventMethodHandler {

    companion object {
        private const val TAG = "DCMauiEventMethodHandler"

        @JvmField
        val shared = DCMauiEventMethodHandler()

        fun getInstance(): DCMauiEventMethodHandler {
            return shared
        }
    }

    private val eventCallbacks = ConcurrentHashMap<Int, MutableMap<String, EventCallback>>()
    private val viewEventListeners = ConcurrentHashMap<Int, MutableSet<String>>()

    fun addEventListenersForBatch(viewId: Int, eventTypes: List<String>): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View $viewId not found for event listener registration")
            return false
        }

        view.setTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY, viewId)
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, eventTypes.toSet())

        val eventCallback: (String, Map<String, Any?>) -> Unit = { eventType, eventData ->
            shared.sendEventToFlutter(viewId, eventType, eventData)
        }
        view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_CALLBACK_KEY, eventCallback)

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

    internal fun sendEventToFlutter(viewId: Int, eventName: String, eventData: Map<String, Any?>) {
        try {
            com.dotcorr.dcflight.bridge.DCFlightJni.sendEvent(viewId, eventName, eventData)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event via JNI: ${e.message}", e)
        }
    }

    fun removeEventListeners(viewId: Int, eventTypes: List<String>): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View $viewId not found for event listener removal")
            return false
        }

        val currentEventTypes = view.getTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY) as? Set<String>
        if (currentEventTypes == null || currentEventTypes.isEmpty()) {
            Log.d(TAG, "No event listeners found for view $viewId")
            return false
        }

        val remainingEventTypes = currentEventTypes.toMutableSet()
        for (eventType in eventTypes) {
            remainingEventTypes.remove(eventType)
            val normalizedType = if (eventType.startsWith("on", ignoreCase = true)) {
                eventType
            } else {
                "on${eventType.replaceFirstChar { it.uppercaseChar() }}"
            }
            remainingEventTypes.remove(normalizedType)
        }

        if (remainingEventTypes.isEmpty) {
            view.setTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY, null)
            view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, null)
            view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_CALLBACK_KEY, null)
            viewEventListeners.remove(viewId)
            eventCallbacks.remove(viewId)
            Log.d(TAG, "All event listeners removed for view $viewId")
        } else {
            view.setTag(com.dotcorr.dcflight.components.DCFTags.EVENT_TYPES_KEY, remainingEventTypes)
            Log.d(TAG, "Event listeners partially removed for view $viewId. Remaining: $remainingEventTypes")
        }

        return true
    }

    fun cleanup() {
        eventCallbacks.clear()
        viewEventListeners.clear()
    }
}
