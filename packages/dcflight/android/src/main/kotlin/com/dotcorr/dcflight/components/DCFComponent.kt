/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.view.View

/**
 * DCFComponent - Base class for all DCFlight components
 * Provides the core interface for creating and updating native views
 * 
 * This is the Android equivalent of iOS DCFComponentProtocol
 */
abstract class DCFComponent {
    
    companion object {
        private const val TAG = "DCFComponent"
        
        // View tag constants for event system
        const val TAG_VIEW_ID = "dcf_view_id"
        const val TAG_EVENT_TYPES = "dcf_event_types"  
        const val TAG_EVENT_CALLBACK = "dcf_event_callback"
    }

    /**
     * Creates a new native view for this component
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Updates an existing view with new props
     */
    abstract fun updateView(view: View, props: Map<String, Any?>): Boolean
    
    /**
     * Optional: Handle tunnel method calls (framework-specific operations)
     */
    open fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    /**
     * Protected helper method for components to implement their update logic
     * Components can override this to handle prop updates with non-null values
     */
    protected open fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        return false
    }
}

/**
 * Global propagateEvent function - matches iOS DCFComponentProtocol exactly
 * 
 * This function provides the unified event system for all Android components,
 * equivalent to the iOS propagateEvent implementation in DCFComponentProtocol.swift
 */
fun propagateEvent(
    view: View?,
    eventName: String,
    data: Map<String, Any?> = mapOf(),
    nativeAction: ((View, Map<String, Any?>) -> Unit)? = null
) {
    if (view == null) return

    try {
        // Execute native action first if provided
        nativeAction?.invoke(view, data)

        // Get stored event information from view tags (set by event handler)
        val viewId = view.getTag(com.dotcorr.dcflight.R.id.dcf_view_id) as? String
        val eventTypes = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_types) as? Set<String>
        val eventCallback = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_callback) as? (String, Map<String, Any?>) -> Unit

        // Check if this view is registered for events and this specific event type
        if (viewId != null && eventTypes != null && eventCallback != null) {
            val normalizedEventName = normalizeEventNameForPropagation(eventName)
            if (eventTypes.contains(normalizedEventName)) {
                // Call the registered callback with event data
                eventCallback(normalizedEventName, data)
            }
        }
    } catch (e: Exception) {
        // Log error but don't crash
        android.util.Log.e("DCFComponent", "Error in propagateEvent: ${e.message}", e)
    }
}

/**
 * Normalizes event names for consistent event propagation
 * Matches iOS normalizeEventNameForPropagation helper function
 */
fun normalizeEventNameForPropagation(eventName: String): String {
    // Convert camelCase to lowercase for consistency
    return eventName.lowercase().replace("on", "").trim()
}

/**
 * Convenience function for firing events with common patterns
 * Matches iOS fireEvent helper
 */
fun fireEvent(view: View?, eventName: String, data: Map<String, Any?> = mapOf()) {
    propagateEvent(view, eventName, data)
}

/**
 * Utility function to convert dp to pixels
 */
fun dpToPx(dp: Float, context: Context): Int {
    val density = context.resources.displayMetrics.density
    return (dp * density + 0.5f).toInt()
}
