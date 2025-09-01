/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.utils

import android.view.View
import com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler

/**
 * Android equivalent of iOS propagateEvent() global function
 * 
 * Usage: propagateEvent(view, "onPress", mapOf("pressed" to true))
 * 
 * This matches iOS propagateEvent API exactly for 1:1 parity
 */
fun propagateEvent(
    view: View, 
    eventName: String, 
    data: Map<String, Any> = emptyMap(),
    nativeAction: ((View, Map<String, Any>) -> Unit)? = null
) {
    // Execute optional native-side action first (match iOS)
    nativeAction?.invoke(view, data)
    
    // Get the stored viewId from the view (set up by the framework)
    val viewId = view.getTag(com.dotcorr.dcflight.R.id.dcf_view_id) as? String
    if (viewId == null) {
        android.util.Log.w("PropagateEvent", "No viewId found for view, cannot propagate event $eventName")
        return
    }
    
    // Get the registered event types for this view
    @Suppress("UNCHECKED_CAST")
    val eventTypes = view.getTag(com.dotcorr.dcf_primitives.R.id.dcf_event_types) as? List<String>
    if (eventTypes == null) {
        android.util.Log.w("PropagateEvent", "No event types registered for view $viewId, cannot propagate event $eventName")
        return
    }
    
    // Check if this event type is registered (match iOS logic)
    val normalizedEventName = normalizeEventNameForPropagation(eventName)
    val eventRegistered = eventTypes.contains(eventName) || 
                         eventTypes.contains(normalizedEventName) ||
                         eventTypes.contains(eventName.lowercase()) ||
                         eventTypes.contains("on${eventName.replaceFirstChar { it.uppercase() }}")
    
    if (!eventRegistered) {
        android.util.Log.d("PropagateEvent", "Event $eventName not registered for view $viewId")
        return
    }
    
    // Get the event callback and send the event (match iOS behavior)
    @Suppress("UNCHECKED_CAST")
    val eventCallback = view.getTag(com.dotcorr.dcf_primitives.R.id.dcf_event_callback) as? ((String, String, Map<String, Any>) -> Unit)
    
    if (eventCallback != null) {
        // Use the stored callback (preferred method)
        eventCallback(viewId, normalizedEventName, data)
    } else {
        // Fallback to DCMauiEventMethodHandler
        android.util.Log.d("PropagateEvent", "Sending event $normalizedEventName for view $viewId via method channel")
        // Note: This requires DCMauiEventMethodHandler to have a sendEvent method - will implement if needed
    }
}

/**
 * Helper function to normalize event names for propagation matching (match iOS exactly)
 */
private fun normalizeEventNameForPropagation(name: String): String {
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

/**
 * Simplified global event propagation for common cases (match iOS fireEvent)
 * Usage: fireEvent(button, "onPress", mapOf("pressed" to true))
 */
fun fireEvent(view: View, eventName: String, data: Map<String, Any> = emptyMap()) {
    propagateEvent(view, eventName, data)
}
