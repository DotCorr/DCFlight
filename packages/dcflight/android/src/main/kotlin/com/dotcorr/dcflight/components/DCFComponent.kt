/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.compone        return Color.rgb(r, g, b)
    }

    @Suppress("UNCHECKED_CAST")
    protected fun <T> safeCast(value: Any?, clazz: Class<T>): T? {
        return try {
            if (value == null) return null
            when {
                clazz.isInstance(value) -> value.toString() as T
                clazz == String::class.java -> value.toString() as T
                clazz == Int::class.java && value is Number -> value.toInt() as T
                clazz == Float::class.java && value is Number -> value.toFloat() as T
                clazz == Double::class.java && value is Number -> value.toDouble() as T
                clazz == Boolean::class.java && value is String -> value.toBoolean() as T
                else -> null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cast $value to ${clazz.simpleName}")
            null
        }
    }
}

// MARK: - 🚀 GLOBAL EVENT PROPAGATION SYSTEM (MATCH iOS EXACTLY)
// Universal functions that ANY class can use to propagate events to Dart

/**
 * Universal event propagation function - Android equivalent of iOS propagateEvent()
 * Usage: propagateEvent(button, "onPress", mapOf("pressed" to true))
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
    
    // Get the stored event callback for this view (set up by framework automatically)
    val callback = view.getTag(android.R.id.TAG_EVENT_CALLBACK) as? ((String, String, Map<String, Any>) -> Unit)
    if (callback == null) {
        // Log.d("PropagateEvent", "No event callback found for view, cannot propagate event $eventName")
        return
    }
    
    val viewId = view.getTag(android.R.id.TAG_VIEW_ID) as? String
    if (viewId == null) {
        // Log.w("PropagateEvent", "No viewId found for view, cannot propagate event $eventName")
        return
    }
    
    @Suppress("UNCHECKED_CAST")
    val eventTypes = view.getTag(android.R.id.TAG_EVENT_TYPES) as? List<String>
    if (eventTypes == null) {
        // Log.w("PropagateEvent", "No event types registered for view $viewId, cannot propagate event $eventName")
        return
    }
    
    // Check if this event type is registered (match iOS logic exactly)
    val normalizedEventName = normalizeEventNameForPropagation(eventName)
    val eventRegistered = eventTypes.contains(eventName) || 
                         eventTypes.contains(normalizedEventName) ||
                         eventTypes.contains(eventName.lowercase()) ||
                         eventTypes.contains("on${eventName.replaceFirstChar { it.uppercase() }}")
    
    if (eventRegistered) {
        callback(viewId, eventName, data)
    } else {
        // Log.d("PropagateEvent", "Event $eventName not registered for view $viewId")
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
}d.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcflight.utils.DCFScreenUtilities

/**
 * Base class for all DCFlight components
 */
abstract class DCFComponent {

    companion object {
        private const val TAG = "DCFComponent"
    }

    /**
     * Creates the native view for this component
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Updates the native view with new properties
     * This version handles nullable maps from the framework
     */
    open fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return try {
            // Filter out null values and convert to non-nullable map for compatibility
            val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
            updateViewInternal(view, nonNullProps)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update view", e)
            false
        }
    }

    /**
     * Internal update method that works with non-nullable maps
     * Override this in components instead of updateView
     */
    protected open fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        applyCommonProps(view, props)
        return true
    }

    /**
     * Handle tunnel method calls for component-specific operations
     */
    open fun handleTunnelMethod(method: String, params: Map<String, Any>): Any? {
        Log.w(TAG, "handleTunnelMethod not implemented for ${this::class.simpleName}")
        return null
    }

    /**
     * Called when view is registered with shadow tree (for layout system)
     */
    open fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "View registered with shadow tree: $nodeId")
    }

    /**
     * Applies common properties to any view
     */
    protected fun applyCommonProps(view: View, props: Map<String, Any>) {
        props["backgroundColor"]?.let { bgColor ->
            when (bgColor) {
                is String -> {
                    val color = ColorUtilities.color(bgColor)
                    if (color != null) {
                        view.setBackgroundColor(color)
                    }
                }
                is Number -> {
                    view.setBackgroundColor(bgColor.toInt())
                }
            }
        }

        props["opacity"]?.let { opacity ->
            when (opacity) {
                is Number -> view.alpha = opacity.toFloat()
            }
        }

        props["visible"]?.let { visible ->
            when (visible) {
                is Boolean -> view.visibility = if (visible) View.VISIBLE else View.GONE
            }
        }

        props["testID"]?.let { testId ->
            view.contentDescription = testId.toString()
        }

        applyAccessibilityProps(view, props)
        applyGestureProps(view, props)
    }

    /**
     * Apply accessibility properties
     */
    protected fun applyAccessibilityProps(view: View, props: Map<String, Any>) {
        props["accessibilityLabel"]?.let { label ->
            view.contentDescription = label.toString()
        }

        props["accessibilityHint"]?.let { hint ->
            view.tooltipText = hint.toString()
        }

        props["accessible"]?.let { accessible ->
            when (accessible) {
                is Boolean -> {
                    view.importantForAccessibility = if (accessible) {
                        View.IMPORTANT_FOR_ACCESSIBILITY_YES
                    } else {
                        View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    }
                }
            }
        }
    }

    /**
     * Apply gesture-related properties
     */
    protected fun applyGestureProps(view: View, props: Map<String, Any>) {
        val hasOnPress = props.containsKey("onPress")
        val hasOnLongPress = props.containsKey("onLongPress")

        if (hasOnPress || hasOnLongPress) {
            view.isClickable = true
            view.isFocusable = true
        }

        if (hasOnPress) {
            view.setOnClickListener {
                Log.d(TAG, "View clicked: ${view.contentDescription}")
            }
        }

        if (hasOnLongPress) {
            view.setOnLongClickListener {
                Log.d(TAG, "View long pressed: ${view.contentDescription}")
                true
            }
        }
    }

    protected fun dpToPx(dp: Float, context: Context): Float {
        return dp * context.resources.displayMetrics.density
    }

    protected fun pxToDp(px: Float, context: Context): Float {
        return px / context.resources.displayMetrics.density
    }

    protected fun dpToPx(context: Context, dp: Float): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }

    protected fun parseDimension(value: Any?, context: Context): Float? {
        return when (value) {
            is Number -> value.toFloat()
            is String -> {
                when {
                    value.endsWith("dp") -> {
                        val dpValue = value.removeSuffix("dp").toFloatOrNull()
                        dpValue?.let { dpToPx(it, context) }
                    }
                    value.endsWith("px") -> {
                        value.removeSuffix("px").toFloatOrNull()
                    }
                    value.endsWith("%") -> {
                        value.removeSuffix("%").toFloatOrNull()
                    }
                    else -> value.toFloatOrNull()
                }
            }
            else -> null
        }
    }

    protected fun parseColor(colorValue: Any): Int {
        return when (colorValue) {
            is String -> {
                try {
                    Color.parseColor(colorValue)
                } catch (e: IllegalArgumentException) {
                    Color.BLACK
                }
            }
            is Number -> colorValue.toInt()
            else -> Color.BLACK
        }
    }

    protected fun darkenColor(color: Int, factor: Float): Int {
        val r = (Color.red(color) * factor).toInt().coerceIn(0, 255)
        val g = (Color.green(color) * factor).toInt().coerceIn(0, 255)
        val b = (Color.blue(color) * factor).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    protected fun lightenColor(color: Int, factor: Float): Int {
        val r = (Color.red(color) + (255 - Color.red(color)) * (factor - 1)).toInt().coerceIn(0, 255)
        val g = (Color.green(color) + (255 - Color.green(color)) * (factor - 1)).toInt().coerceIn(0, 255)
        val b = (Color.blue(color) + (255 - Color.blue(color)) * (factor - 1)).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    @Suppress("UNCHECKED_CAST")
    protected fun <T> safeCast(value: Any?, clazz: Class<T>): T? {
        return try {
            if (value == null) return null
            when {
                clazz.isInstance(value) -> value as T
                clazz == String::class.java -> value.toString() as T
                clazz == Int::class.java && value is Number -> value.toInt() as T
                clazz == Float::class.java && value is Number -> value.toFloat() as T
                clazz == Double::class.java && value is Number -> value.toDouble() as T
                clazz == Boolean::class.java && value is String -> value.toBoolean() as T
                else -> null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cast $value to ${clazz.simpleName}")
            null
        }
    }
}