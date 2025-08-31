/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.view.View
import android.view.ViewGroup

/**
 * Protocol that all DCFlight components must implement
 * Each component extends this interface and must override these functions
 * even if they seem like dead code - this ensures components are future-proof
 */
interface DCFComponent {
    /**
     * Create a view with the given props
     */
    fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Update a view with new props
     */
    fun updateView(view: View, props: Map<String, Any?>): Boolean

    /**
     * Apply layout to the view from Yoga calculations
     */
    fun applyLayout(view: View, layout: YogaLayout) {
        // Default implementation - position and size the view
        val params = view.layoutParams ?: ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )

        if (params is ViewGroup.MarginLayoutParams) {
            params.leftMargin = layout.left.toInt()
            params.topMargin = layout.top.toInt()
        }

        params.width = layout.width.toInt()
        params.height = layout.height.toInt()

        view.layoutParams = params
    }

    /**
     * Get intrinsic content size for a view (for text measurement, etc.)
     */
    fun getIntrinsicSize(view: View, props: Map<String, Any?>): Size {
        // Default implementation - measure the view
        view.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        return Size(view.measuredWidth.toFloat(), view.measuredHeight.toFloat())
    }

    /**
     * Called when a view is registered with the shadow tree
     */
    fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Default implementation - store node ID on the view
        view.setTag(R.id.dcf_node_id, nodeId)
    }

    companion object {
        /**
         * Handle tunnel method calls from Dart
         * Components should override this in their companion object
         */
        @JvmStatic
        fun handleTunnelMethod(method: String, params: Map<String, Any?>): Any? {
            println("⚠️ Component does not implement tunnel method: $method")
            return null
        }
    }
}

/**
 * Layout information from a Yoga node
 */
data class YogaLayout(
    val left: Float,
    val top: Float,
    val width: Float,
    val height: Float
)

/**
 * Size data class for intrinsic sizing
 */
data class Size(
    val width: Float,
    val height: Float
)

/**
 * Global event propagation system
 * Universal functions that ANY class can use to propagate events to Dart
 */
object EventPropagation {

    /**
     * Universal event propagation function - can be used by any class
     * Usage: EventPropagation.propagateEvent(scrollView, "onScroll", mapOf("offsetX" to x, "offsetY" to y))
     */
    @JvmStatic
    fun propagateEvent(
        view: View,
        eventName: String,
        eventData: Map<String, Any?> = emptyMap(),
        nativeAction: ((View, Map<String, Any?>) -> Unit)? = null
    ) {
        // Execute optional native-side action first
        nativeAction?.invoke(view, eventData)

        // Get the stored event callback for this view
        val callback = view.getTag(R.id.dcf_event_callback) as? (String, String, Map<String, Any?>) -> Unit
            ?: return

        val viewId = view.getTag(R.id.dcf_view_id) as? String ?: return

        @Suppress("UNCHECKED_CAST")
        val eventTypes = view.getTag(R.id.dcf_event_types) as? List<String> ?: return

        // Check if this event type is registered
        val normalizedEventName = normalizeEventNameForPropagation(eventName)
        val eventRegistered = eventTypes.contains(eventName) ||
                eventTypes.contains(normalizedEventName) ||
                eventTypes.contains(eventName.lowercase()) ||
                eventTypes.contains("on${eventName.capitalize()}")

        if (eventRegistered) {
            callback(viewId, eventName, eventData)
        }
    }

    /**
     * Simplified global event propagation for common cases
     * Usage: EventPropagation.fireEvent(button, "onPress", mapOf("pressed" to true))
     */
    @JvmStatic
    fun fireEvent(view: View, eventName: String, eventData: Map<String, Any?> = emptyMap()) {
        propagateEvent(view, eventName, eventData)
    }

    /**
     * Helper function to normalize event names for propagation matching
     */
    private fun normalizeEventNameForPropagation(name: String): String {
        // If already has "on" prefix and it's followed by uppercase letter, return as is
        if (name.startsWith("on") && name.length > 2 && name[2].isUpperCase()) {
            return name
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
}
