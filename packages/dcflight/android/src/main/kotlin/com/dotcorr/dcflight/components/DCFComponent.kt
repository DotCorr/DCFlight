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
        
        const val TAG_VIEW_ID = "dcf_view_id"
        const val TAG_EVENT_TYPES = "dcf_event_types"  
        const val TAG_EVENT_CALLBACK = "dcf_event_callback"
        const val TAG_STORED_PROPS = "dcf_stored_props"  //  pattern: store props in view
    }

    /**
     * Creates a new native view for this component
     */
    abstract fun createView(context: Context, props: Map<String, Any?>): View

    /**
     * Updates an existing view with new props
     * Framework-level implementation: Automatically merges props ( pattern)
     * Components MUST override updateViewInternal for their specific update logic
     * 
     * This method is final to ensure all components use the framework's props merging
     */
    fun updateView(view: View, props: Map<String, Any?>): Boolean {
        //  pattern: Store and merge props for stability
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        // Filter out null values for processing
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        val nonNullExistingProps = existingProps.filterValues { it != null }.mapValues { it.value!! }
        
        return updateViewInternal(view, nonNullProps, nonNullExistingProps)
    }
    
    /**
     * Store props in view tag for merging on updates ( pattern)
     * This ensures properties are preserved across partial updates
     */
    protected fun storeProps(view: View, props: Map<String, Any?>) {
        view.setTag(TAG_STORED_PROPS.hashCode(), props.toMutableMap())
    }
    
    /**
     * Get stored props from view tag
     */
    protected fun getStoredProps(view: View): MutableMap<String, Any?> {
        @Suppress("UNCHECKED_CAST")
        return (view.getTag(TAG_STORED_PROPS.hashCode()) as? MutableMap<String, Any?>) ?: mutableMapOf()
    }
    
    /**
     * Merge existing props with updates ( pattern)
     * - Null values remove props
     * - Non-null values update props
     * - Missing props are preserved
     * - CRITICAL: Semantic color props are removed if not in new props (StyleSheet property removal)
     */
    protected fun mergeProps(existing: Map<String, Any?>, updates: Map<String, Any?>): MutableMap<String, Any?> {
        val merged = existing.toMutableMap()
        
        // CRITICAL: StyleSheet ALWAYS provides semantic colors via toMap()
        // Only remove semantic colors if explicitly set to null in updates
        // If not in updates, preserve from existing (StyleSheet should always include them)
        val semanticColorKeys = listOf("primaryColor", "secondaryColor", "tertiaryColor", "accentColor")
        for (key in semanticColorKeys) {
            // Only remove if explicitly null in updates (explicit removal)
            if (updates.containsKey(key) && updates[key] == null) {
                merged.remove(key)
            }
            // If in updates and not null, it will be set below
            // If not in updates at all, preserve from existing (StyleSheet always provides)
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
     * @param view The view to update
     * @param props The merged new props (non-null filtered)
     * @param existingProps The previous props (non-null filtered) - use hasPropChanged() to compare
     */
    protected abstract fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean
    
    /**
     * Framework-level helper: Check if a specific prop changed between existing and new props
     * Use this in updateViewInternal to only update/reload if the prop actually changed
     * 
     * Example (WebView):
     * if (hasPropChanged("source", existingProps, props)) {
     *     webView.loadUrl(newSource)
     * }
     */
    protected fun hasPropChanged(key: String, existing: Map<String, Any>, new: Map<String, Any>): Boolean {
        val existingValue = existing[key]
        val newValue = new[key]
        return existingValue != newValue
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
        nativeAction?.invoke(view, data)

        val viewId = view.getTag(com.dotcorr.dcflight.R.id.dcf_view_id) as? String
        val eventTypes = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_types) as? Set<String>
        val eventCallback = view.getTag(com.dotcorr.dcflight.R.id.dcf_event_callback) as? (String, Map<String, Any?>) -> Unit

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
