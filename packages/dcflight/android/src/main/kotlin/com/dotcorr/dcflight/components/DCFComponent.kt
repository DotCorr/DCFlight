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
     * Framework-level implementation: Automatically merges props (React Native pattern)
     * Components MUST override updateViewInternal for their specific update logic
     * 
     * This method is final to ensure all components use the framework's props merging
     */
    fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        val nonNullExistingProps = existingProps.filterValues { it != null }.mapValues { it.value!! }
        
        return updateViewInternal(view, nonNullProps, nonNullExistingProps)
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
     * Protected helper method for components to implement their update logic
     * Components MUST override this to handle prop updates
     * Props are already merged and null-filtered by updateView()
     * 
     * This is called by updateView() after props merging
     * 
     * CRITICAL PATTERN FOR STATE PRESERVATION:
     * When only semantic colors change (theme toggle), read current state from view, not props.
     * Example: Slider reads from seekBar.progress, SegmentedControl reads from button text color.
     * Use onlySemanticColorsChanged() helper to detect this case.
     * 
     * @param view The view to update
     * @param props The merged new props (non-null filtered)
     * @param existingProps The previous props (non-null filtered) - use hasPropChanged() to compare
     */
    protected abstract fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean
    
    /**
     * Check if a specific prop changed between existing and new props
     * Use this in updateViewInternal to only update/reload if the prop actually changed
     */
    protected fun hasPropChanged(key: String, existing: Map<String, Any>, new: Map<String, Any>): Boolean {
        val existingValue = existing[key]
        val newValue = new[key]
        return existingValue != newValue
    }
    
    /**
     * Check if only semantic colors changed (no state props changed)
     * Use this to preserve component state when only theme/colors change
     * 
     * When only colors change, read current state from view (not props)
     * This prevents components from resetting when theme toggles
     * 
     * @param existingProps Previous props (from getStoredProps)
     * @param props New props (merged)
     * @param stateProps List of prop keys that represent component state (e.g., ["selectedIndex", "value", "checked"])
     *                   Common state props like "enabled", "disabled" are automatically included.
     * @return true if only semantic colors changed, false if state props also changed
     */
    protected fun onlySemanticColorsChanged(
        existingProps: Map<String, Any>,
        props: Map<String, Any>,
        stateProps: List<String> = emptyList()
    ): Boolean {
        val allStateProps = stateProps + DCFPropConstants.COMMON_STATE_PROPS + listOf("segments")
        
        val stateChanged = allStateProps.any { hasPropChanged(it, existingProps, props) }
        if (stateChanged) return false
        
        val colorChanged = DCFPropConstants.SEMANTIC_COLOR_PROPS.any { hasPropChanged(it, existingProps, props) }
        
        return colorChanged
    }
    
    /**
     * Check if layout props changed between existing and new props.
     * 
     * This is a framework-level utility to avoid duplicating layout prop detection logic.
     * Components should use this instead of manually checking layout props.
     * 
     * Uses DCFPropConstants.LAYOUT_PROPS to ensure consistency with bridge-level layout prop extraction.
     * 
     * @param existingProps Previous props (from getStoredProps)
     * @param props New props (merged)
     * @return true if any layout props changed, false otherwise
     */
    protected fun hasLayoutPropsChanged(
        existingProps: Map<String, Any>,
        props: Map<String, Any>
    ): Boolean {
        return DCFPropConstants.LAYOUT_PROPS.any { hasPropChanged(it, existingProps, props) }
    }
    
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
        val viewId = view.getTag(DCFTags.VIEW_ID_KEY) as? String
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
