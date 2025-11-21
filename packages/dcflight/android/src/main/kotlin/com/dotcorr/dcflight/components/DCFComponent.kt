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
import com.dotcorr.dcflight.extensions.applyStyles

/**
 * Interface that views can implement to opt-out of layout updates during certain states.
 * 
 * This allows modules (like dcf_reanimated) to make views layout-independent
 * without modifying the framework layer.
 * 
 * Example usage:
 * ```kotlin
 * class MyAnimatedView(context: Context) : FrameLayout(context), DCFLayoutIndependent {
 *     override val shouldSkipLayout: Boolean
 *         get() = isAnimating // Skip layout when animating
 * }
 * ```
 */
interface DCFLayoutIndependent {
    /**
     * Returns true if layout updates should be skipped for this view.
     * 
     * When true, Yoga will skip applying layout to this view, making it
     * layout-independent (similar to React Native Reanimated's approach).
     * 
     * This is useful for:
     * - Animated views that use transforms (prevents anchor point recalculation)
     * - Views with custom layout logic
     * - Performance-critical views that don't need layout updates
     */
    val shouldSkipLayout: Boolean
}

/**
 * Interface that views can implement to specify a content container for children.
 * 
 * Some views (like ScrollView) can only have one direct child, but need to host
 * multiple children. This interface allows components to specify where children
 * should actually be attached.
 * 
 * Example usage:
 * ```kotlin
 * class MyScrollView(context: Context) : NestedScrollView(context), DCFContentContainerProvider {
 *     private val contentContainer = FrameLayout(context)
 *     
 *     init {
 *         addView(contentContainer)
 *     }
 *     
 *     override fun getContentContainer(): ViewGroup = contentContainer
 * }
 * ```
 */
interface DCFContentContainerProvider {
    /**
     * Returns the ViewGroup where children should be attached.
     * 
     * If a view implements this interface, the bridge will attach children
     * to the returned container instead of the view itself.
     * 
     * @return The ViewGroup that should receive children, or null to use the view itself
     */
    fun getContentContainer(): ViewGroup?
}

/**
 * DCFComponent - Base class for all DCFlight components
 * Provides the core interface for creating and updating native views
 * 
 * This is the Android equivalent of iOS DCFComponentProtocol
 */
abstract class DCFComponent {
    
    companion object {
        private const val TAG = "DCFComponent"
    }

    /**
     * Creates a new native view for this component
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Updates an existing view with new props
     * Matches iOS: func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool
     * 
     * CRITICAL: Merges new props with existing stored props to preserve all properties
     * This ensures components don't lose state (text alignment, font size, etc.) during updates
     * Framework-level fix - all components benefit automatically
     */
    open fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL FRAMEWORK FIX: Merge new props with existing stored props
        // This preserves all properties across partial updates
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        
        // Store merged props for next update
        storeProps(view, mergedProps)
        
        // Apply merged props (all properties, not just changed ones)
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullProps)
        return true
    }
    
    /**
     * Store props in view tag for merging on updates (React Native pattern)
     * This ensures properties are preserved across partial updates
     * Uses pure Kotlin tag keys - NO XML resources needed
     */
    protected fun storeProps(view: View, props: Map<String, Any?>) {
        view.setTag(DCFTags.STORED_PROPS_KEY, props.toMutableMap())
    }
    
    /**
     * Get stored props from view tag
     * Uses pure Kotlin tag keys - NO XML resources needed
     */
    protected fun getStoredProps(view: View): MutableMap<String, Any?> {
        @Suppress("UNCHECKED_CAST")
        return (view.getTag(DCFTags.STORED_PROPS_KEY) as? MutableMap<String, Any?>) ?: mutableMapOf()
    }
    
    /**
     * Merge existing props with updates (React Native pattern)
     * - Null values remove props
     * - Non-null values update props
     * - Missing props are preserved
     * - Semantic color props are removed if not in new props (StyleSheet property removal)
     */
    protected fun mergeProps(existing: Map<String, Any?>, updates: Map<String, Any?>): MutableMap<String, Any?> {
        val merged = existing.toMutableMap()
        
        for (key in DCFPropConstants.SEMANTIC_COLOR_PROPS) {
            if (updates.containsKey(key) && updates[key] == null) {
                merged.remove(key)
            }
        }
        
        for ((key, value) in updates) {
            if (value == null) {
                merged.remove(key)
            } else {
                merged[key] = value
            }
        }
        return merged
    }
    
    /**
     * Handle tunnel method calls (framework-specific operations)
     * Components MUST implement this (can return null if not needed)
     */
    abstract fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any?
    
    
    /**
     * Calculate intrinsic size for the component - MATCH iOS getIntrinsicSize
     * Used by Yoga layout for measuring leaf nodes
     * Components MUST implement this
     */
    abstract fun getIntrinsicSize(view: View, props: Map<String, Any>): android.graphics.PointF
    
    /**
     * Called when the view is registered with the shadow tree - MATCH iOS
     * Components MUST implement this
     */
    abstract fun viewRegisteredWithShadowTree(view: View, nodeId: String)
    
    /**
     * Apply layout to a view - MATCH iOS applyLayout exactly
     * 
     * iOS signature: func applyLayout(_ view: UIView, layout: YGNodeLayout)
     * Android signature: fun applyLayout(view: View, layout: DCFNodeLayout)
     * 
     * Framework controls everything - components just set the frame.
     * NO props parameter - framework handles all lifecycle and state.
     * 
     * @param view The view to apply layout to
     * @param layout Layout information from Yoga (left, top, width, height)
     */
    open fun applyLayout(view: View, layout: DCFNodeLayout) {
        // Match iOS exactly: just set the frame, nothing else
        // Framework handles all transforms, lifecycle, state - components don't need to know
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
    }
    
    /**
     * Prepare a view for recycling (view pooling) - MATCH iOS prepareForRecycle
     * 
     * iOS uses view pooling for performance. Android doesn't use pooling (for stability),
     * but we provide this method for consistency and future use.
     * 
     * Components can override this for custom cleanup if needed.
     * 
     * @param view The view to prepare for recycling
     */
    open fun prepareForRecycle(view: View) {
        // Remove from parent
        (view.parent as? ViewGroup)?.removeView(view)
        
        // Reset visibility
        view.visibility = View.VISIBLE
        view.alpha = 1.0f
        
        // Clear stored props
        view.setTag(DCFTags.STORED_PROPS_KEY, null)
        
        // Clear event callbacks
        view.setTag(DCFTags.EVENT_CALLBACK_KEY, null)
        view.setTag(DCFTags.VIEW_ID_KEY, null)
        view.setTag(DCFTags.EVENT_TYPES_KEY, null)
        
        // Reset transforms
        view.rotation = 0f
        view.translationX = 0f
        view.translationY = 0f
        view.scaleX = 1f
        view.scaleY = 1f
        
        // Reset frame (will be set by layout)
        view.layout(0, 0, 0, 0)
        
        // Clear subviews (components should handle this if needed)
        if (view is ViewGroup) {
            view.removeAllViews()
        }
    }
}

/**
 * Layout information from a Yoga node - MATCH iOS YGNodeLayout exactly
 */
data class DCFNodeLayout(
    val left: Float,
    val top: Float,
    val width: Float,
    val height: Float
)

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
        nativeAction?.invoke(view, data)

        // ✅ Use pure Kotlin tag keys instead of XML resource IDs
        val viewId = view.getTag(DCFTags.VIEW_ID_KEY) as? Int
        val eventTypes = view.getTag(DCFTags.EVENT_TYPES_KEY) as? Set<String>
        val eventCallback = view.getTag(DCFTags.EVENT_CALLBACK_KEY) as? (String, Map<String, Any?>) -> Unit

        android.util.Log.d("DCFComponent", "🔥 propagateEvent: eventName=$eventName, viewId=$viewId")
        android.util.Log.d("DCFComponent", "🔥 propagateEvent: eventTypes=$eventTypes")
        android.util.Log.d("DCFComponent", "🔥 propagateEvent: eventCallback=$eventCallback")

        if (viewId != null && eventTypes != null && eventCallback != null) {
            val normalizedEventName = normalizeEventNameForPropagation(eventName)
            android.util.Log.d("DCFComponent", "🔥 propagateEvent: normalizedEventName=$normalizedEventName")
            
            if (eventTypes.contains(normalizedEventName) || eventTypes.contains(eventName)) {
                android.util.Log.d("DCFComponent", "🚀 FIRING EVENT: $eventName to Flutter!")
                eventCallback(eventName, data)
            } else {
                android.util.Log.w("DCFComponent", "❌ Event $eventName/$normalizedEventName not in registered types: $eventTypes")
            }
        } else {
            android.util.Log.w("DCFComponent", "❌ propagateEvent: Missing registration - viewId=$viewId, eventTypes=$eventTypes, callback=$eventCallback")
        }
    } catch (e: Exception) {
        android.util.Log.e("DCFComponent", "Error in propagateEvent: ${e.message}", e)
    }
}

/**
 * Normalizes event names for consistent event propagation
 * Matches iOS normalizeEventNameForPropagation helper function
 */
fun normalizeEventNameForPropagation(eventName: String): String {
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
