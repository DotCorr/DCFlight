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
 * CRITICAL FIX: Abstract base class that all DCFlight components must extend
 * Now matches iOS DCFComponent protocol exactly with tunnel method support
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
     * Create a view with the given props - EXACT iOS signature
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Alternative createView for backward compatibility
     */
    fun createView(context: Context): View {
        return createView(context, initialProps)
    }

    /**
     * Update a view with new props - EXACT iOS signature
     */
    abstract fun updateView(view: View, props: Map<String, Any?>): Boolean

    /**
     * CRITICAL FIX: Apply yoga layout to the view - EXACT iOS signature
     */
    open fun applyLayout(view: View, layout: YogaLayout) {
        // Default implementation - position and size the view like iOS
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
     * CRITICAL FIX: Get intrinsic content size for a view - EXACT iOS signature
     */
    open fun getIntrinsicSize(view: View, forProps props: Map<String, Any?>): Size {
        // Default implementation - use view's intrinsic size or zero like iOS
        view.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        return if (view.measuredWidth != 0 || view.measuredHeight != 0) {
            Size(view.measuredWidth.toFloat(), view.measuredHeight.toFloat())
        } else {
            Size(0f, 0f)
        }
    }

    /**
     * CRITICAL FIX: Called when a view is registered with the shadow tree - EXACT iOS signature
     */
    open fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Default implementation - store node ID on the view like iOS
        view.setTag(com.dotcorr.dcflight.R.id.dcf_node_id, nodeId)
    }

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

    companion object {
        /**
         * CRITICAL FIX: Handle tunnel method calls from Dart - EXACT iOS signature
         * Components should override this in their companion object
         */
        @JvmStatic
        open fun handleTunnelMethod(method: String, params: Map<String, Any?>): Any? {
            Log.w(TAG, "Component ${this::class.simpleName} does not implement tunnel method: $method")
            return null
        }

        private const val TAG = "DCFComponent"
    }
}

/**
 * CRITICAL FIX: Extension to make tunnel method work with class instances
 * This allows the registry to call static methods on component classes
 */
fun Class<out DCFComponent>.handleTunnelMethod(method: String, params: Map<String, Any?>): Any? {
    return try {
        // Get the companion object and call handleTunnelMethod
        val companionField = this.getDeclaredField("Companion")
        companionField.isAccessible = true
        val companion = companionField.get(null)
        
        val handleMethod = companion::class.java.getDeclaredMethod(
            "handleTunnelMethod",
            String::class.java,
            Map::class.java
        )
        handleMethod.isAccessible = true
        handleMethod.invoke(companion, method, params)
    } catch (e: Exception) {
        Log.w("DCFComponent", "Failed to call tunnel method $method on ${this.simpleName}", e)
        null
    }
}

/**
 * Layout information from a Yoga node - matches iOS YGNodeLayout exactly
 */
data class YogaLayout(
    val left: Float,
    val top: Float,
    val width: Float,
    val height: Float
)

/**
 * Size data class for intrinsic sizing - matches iOS exactly
 */
data class Size(
    val width: Float,
    val height: Float
)

/**
 * CRITICAL FIX: Global event propagation system - EXACT iOS implementation
 * Universal functions that ANY class can use to propagate events to Dart
 */

/**
 * Universal event propagation function - EXACT iOS signature
 */
fun propagateEvent(
    view: View,
    eventName: String,
    eventData: Map<String, Any?> = emptyMap(),
    nativeAction: ((View, Map<String, Any?>) -> Unit)? = null
) {
    // Execute optional native-side action first like iOS
    nativeAction?.invoke(view, eventData)

    // Get the stored event callback for this view like iOS
    val callback = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_callback) as? (String, String, Map<String, Any?>) -> Unit
        ?: return

    val viewId = view.getTag(com.dotcorr.dcflight.R.id.dcf_view_id) as? String ?: return

    @Suppress("UNCHECKED_CAST")
    val eventTypes = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_types) as? List<String> ?: return

    // Check if this event type is registered like iOS
    val normalizedEventName = normalizeEventNameForPropagation(eventName)
    val eventRegistered = eventTypes.contains(eventName) ||
            eventTypes.contains(normalizedEventName) ||
            eventTypes.contains(eventName.lowercase()) ||
            eventTypes.contains("on${eventName.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }}")

    if (eventRegistered) {
        callback(viewId, eventName, eventData)
    } else {
        Log.d("EventPropagation", "Event $eventName not registered for view $viewId")
    }
}

/**
 * Simplified global event propagation for common cases - EXACT iOS signature
 */
fun fireEvent(view: View, eventName: String, eventData: Map<String, Any?> = emptyMap()) {
    propagateEvent(view, eventName, eventData)
}

/**
 * Helper function to normalize event names for propagation matching - EXACT iOS logic
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

