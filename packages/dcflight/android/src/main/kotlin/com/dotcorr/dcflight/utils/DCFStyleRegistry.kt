/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.utils

/**
 * Style registry for caching styles by numeric ID.
 *
 * This enables efficient style management by allowing styles to be referenced
 * by numeric IDs instead of sending full style objects on every update.
 *
 * **Usage:**
 * ```kotlin
 * // Register a style
 * val styleId = DCFStyleRegistry.register(style)
 *
 * // Retrieve a style by ID
 * val style = DCFStyleRegistry.get(styleId)
 * view.applyStyles(style)
 * ```
 *
 * **Benefits:**
 * - Reduces bridge traffic by sending IDs instead of full objects
 * - Enables style deduplication across views
 * - Improves performance for frequently reused styles
 */
object DCFStyleRegistry {
    /**
     * Maps numeric style ID -> style map
     */
    private val styles = mutableMapOf<Int, Map<String, Any>>()
    
    /**
     * Maps style hash -> numeric ID (for deduplication)
     */
    private val styleToId = mutableMapOf<Int, Int>()
    
    /**
     * Next available numeric ID
     */
    private var nextId = 1
    
    /**
     * Register a style and return its numeric ID.
     *
     * If an identical style is already registered, returns the existing ID.
     * This enables automatic style deduplication.
     *
     * @param style Style map to register
     * @return Numeric ID for the registered style
     */
    fun register(style: Map<String, Any>): Int {
        // Create hash of style for deduplication
        val styleHash = styleHashValue(style)
        
        // Check if identical style already exists
        styleToId[styleHash]?.let { existingId ->
            return existingId
        }
        
        // Generate new numeric ID
        val id = nextId
        nextId++
        
        // Store style and hash mapping
        styles[id] = style
        styleToId[styleHash] = id
        
        return id
    }
    
    /**
     * Get style by numeric ID.
     *
     * @param styleId Numeric ID of the style
     * @return Style map if found, null otherwise
     */
    fun get(styleId: Int): Map<String, Any>? {
        return styles[styleId]
    }
    
    /**
     * Check if a style ID exists in the registry.
     *
     * @param styleId Numeric ID to check
     * @return True if style exists, false otherwise
     */
    fun has(styleId: Int): Boolean {
        return styles.containsKey(styleId)
    }
    
    /**
     * Remove a style from the registry.
     *
     * @param styleId Numeric ID of the style to remove
     */
    fun remove(styleId: Int) {
        styles[styleId]?.let { style ->
            val styleHash = styleHashValue(style)
            styles.remove(styleId)
            styleToId.remove(styleHash)
        }
    }
    
    /**
     * Clear all registered styles (for testing/debugging).
     */
    fun clear() {
        styles.clear()
        styleToId.clear()
        nextId = 1
    }
    
    /**
     * Create a hash value for a style map.
     *
     * This is used for style deduplication - identical styles get the same hash.
     *
     * @param style Style map to hash
     * @return Hash value for the style
     */
    private fun styleHashValue(style: Map<String, Any>): Int {
        // Create a deterministic hash from style keys and values
        var hash = 0
        val sortedKeys = style.keys.sorted()
        for (key in sortedKeys) {
            hash = hash * 31 + key.hashCode()
            val value = style[key]
            hash = hash * 31 + (value?.hashCode() ?: 0)
        }
        return hash
    }
}

/**
 * Resolve style props, handling both direct style objects and style IDs.
 *
 * If props contain a "styleId" key, resolves it to the full style map.
 * Otherwise, returns the props as-is.
 *
 * **Usage:**
 * ```kotlin
 * val resolvedProps = resolveStyleProps(props)
 * view.applyStyles(resolvedProps)
 * ```
 *
 * @param props Props map that may contain a "styleId" key
 * @return Resolved props with style ID expanded to full style object
 */
fun resolveStyleProps(props: Map<String, Any>): Map<String, Any> {
    // Check if props contain a style ID
    val styleId = props["styleId"] as? Int
    if (styleId != null) {
        // Resolve style ID to full style map
        val style = DCFStyleRegistry.get(styleId)
        if (style != null) {
            // Merge resolved style with other props (other props take precedence)
            val resolved = style.toMutableMap()
            for ((key, value) in props) {
                if (key != "styleId") {
                    resolved[key] = value
                }
            }
            return resolved
        }
    }
    
    // No style ID or style not found - return props as-is
    return props
}
