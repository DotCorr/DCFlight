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
     * This is called by the layout manager after Yoga calculates layout
     * Components can override this to handle special layout cases (e.g., rotation, transforms)
     * 
     * Default implementation applies the frame directly.
     * Components that need transforms/rotations should override this.
     * 
     * @param view The view to apply layout to
     * @param layout Layout information from Yoga (left, top, width, height)
     * @param props Current props (may contain transform properties like rotateInDegrees, translateX, etc.)
     */
    open fun applyLayout(view: View, layout: DCFNodeLayout, props: Map<String, Any?> = emptyMap()) {
        // Default implementation: just set the frame
        // Components can override for transforms/rotations
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        
        // Apply transforms if present
        applyTransforms(view, layout, props)
    }
    
    /**
     * Apply transforms (rotation, translation, scale) to a view
     * This is called by applyLayout by default, but components can override
     * to handle transforms differently (e.g., vertical slider needs custom rotation)
     */
    protected open fun applyTransforms(view: View, layout: DCFNodeLayout, props: Map<String, Any?>) {
        var transformApplied = false
        var rotation = 0f
        var translateX = 0f
        var translateY = 0f
        var scaleX = 1f
        var scaleY = 1f
        
        // Get rotation
        props["rotateInDegrees"]?.let {
            rotation = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            transformApplied = true
        }
        
        // Get translation
        props["translateX"]?.let {
            translateX = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            transformApplied = true
        }
        
        props["translateY"]?.let {
            translateY = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            transformApplied = true
        }
        
        // Get scale
        props["scale"]?.let {
            val scale = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 1f
                else -> 1f
            }
            scaleX = scale
            scaleY = scale
            transformApplied = true
        }
        
        props["scaleX"]?.let {
            scaleX = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 1f
                else -> 1f
            }
            transformApplied = true
        }
        
        props["scaleY"]?.let {
            scaleY = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 1f
                else -> 1f
            }
            transformApplied = true
        }
        
        if (transformApplied) {
            // Apply pivot point at center for rotation
            view.pivotX = layout.width / 2f
            view.pivotY = layout.height / 2f
            
            // Build transform matrix
            view.rotation = rotation
            view.translationX = translateX
            view.translationY = translateY
            view.scaleX = scaleX
            view.scaleY = scaleY
        } else {
            // Reset transforms if none specified
            view.rotation = 0f
            view.translationX = 0f
            view.translationY = 0f
            view.scaleX = 1f
            view.scaleY = 1f
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
