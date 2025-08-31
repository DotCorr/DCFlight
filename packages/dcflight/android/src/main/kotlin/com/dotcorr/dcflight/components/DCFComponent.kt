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
 * Abstract base class that all DCFlight components must extend
 * Matches iOS DCFComponent protocol pattern
 * Each component extends this class and must override these functions
 * even if they seem like dead code - this ensures components are future-proof
 */
abstract class DCFComponent {

    // Properties that were passed during creation
    protected var initialProps: Map<String, Any?> = emptyMap()

    // Bound view reference
    protected var boundView: View? = null

    /**
     * Default constructor for components
     */
    constructor() {
        this.initialProps = emptyMap()
    }

    /**
     * Constructor with initial properties
     */
    constructor(props: Map<String, Any?>) {
        this.initialProps = props
    }

    /**
     * Create a view with the given props
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Alternative createView for backward compatibility
     */
    fun createView(context: Context): View {
        return createView(context, initialProps)
    }

    /**
     * Update a view with new props
     */
    abstract fun updateView(view: View, props: Map<String, Any?>): Boolean

    /**
     * Apply properties to the component
     */
    open fun applyProperties(props: Map<String, Any?>) {
        boundView?.let { view ->
            updateView(view, props)
        }
    }

    /**
     * Update properties of the component
     */
    open fun updateProperties(props: Map<String, Any?>) {
        applyProperties(props)
    }

    /**
     * Bind a view to this component
     */
    open fun bindView(view: View) {
        this.boundView = view
    }

    /**
     * Cleanup when component is removed
     */
    open fun cleanup() {
        boundView = null
    }

    /**
     * Apply layout to the view from Yoga calculations
     */
    open fun applyLayout(view: View, layout: YogaLayout) {
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
    open fun getIntrinsicSize(view: View, props: Map<String, Any?>): Size {
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
    open fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Default implementation - store node ID on the view
        view.setTag(DCF_NODE_ID_TAG, nodeId)
    }

    companion object {
        // Tag IDs for storing data on views
        // Using high numbers to avoid conflicts with user-defined IDs
        const val DCF_NODE_ID_TAG = 0x7f0a0001
        const val DCF_EVENT_CALLBACK_TAG = 0x7f0a0002
        const val DCF_VIEW_ID_TAG = 0x7f0a0003
        const val DCF_EVENT_TYPES_TAG = 0x7f0a0004
        const val DCF_COMPONENT_TYPE_TAG = 0x7f0a0005
        const val DCF_TEST_ID_TAG = 0x7f0a0006
        const val DCF_WEBVIEW_CLIENT_TAG = 0x7f0a0007
        const val DCF_WEBVIEW_CHROME_CLIENT_TAG = 0x7f0a0008
        const val DCF_WEBVIEW_PROGRESS_TAG = 0x7f0a0009
        const val DCF_WEBVIEW_NAVIGATION_GESTURES_TAG = 0x7f0a000a

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
        val callback = view.getTag(DCFComponent.DCF_EVENT_CALLBACK_TAG) as? (String, String, Map<String, Any?>) -> Unit
            ?: return

        val viewId = view.getTag(DCFComponent.DCF_VIEW_ID_TAG) as? String ?: return

        @Suppress("UNCHECKED_CAST")
        val eventTypes = view.getTag(DCFComponent.DCF_EVENT_TYPES_TAG) as? List<String> ?: return

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
