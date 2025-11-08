/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.pool

import android.view.View
import android.view.ViewGroup
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * View recycling pool manager for performance optimization.
 * Reuses views instead of creating/destroying them, reducing allocation overhead
 * and eliminating visual flashing during rapid updates.
 */
class ViewPoolManager private constructor() {
    
    companion object {
        private const val TAG = "ViewPoolManager"
        private const val DEFAULT_MAX_POOL_SIZE = 10 // Max views per type in pool
        
        @JvmField
        val shared = ViewPoolManager()
    }
    
    // Map of view type -> queue of recycled views
    private val pools = ConcurrentHashMap<String, ConcurrentLinkedQueue<View>>()
    
    // Track pool sizes per type
    private val poolSizes = ConcurrentHashMap<String, Int>()
    private val maxPoolSizes = ConcurrentHashMap<String, Int>()
    
    /**
     * Get a recycled view from the pool, or null if none available
     */
    fun acquireView(viewType: String): View? {
        val pool = pools[viewType] ?: return null
        val view = pool.poll()
        
        if (view != null) {
            val currentSize = poolSizes.getOrDefault(viewType, 0)
            poolSizes[viewType] = maxOf(0, currentSize - 1)
            Log.d(TAG, "♻️ Acquired recycled view for type '$viewType' (pool size: ${poolSizes[viewType]})")
        }
        
        return view
    }
    
    /**
     * Return a view to the pool for recycling
     */
    fun releaseView(view: View, viewType: String) {
        if (view == null) return
        
        // Clean up the view before pooling
        resetViewForReuse(view)
        
        val maxSize = maxPoolSizes.getOrDefault(viewType, DEFAULT_MAX_POOL_SIZE)
        val currentSize = poolSizes.getOrDefault(viewType, 0)
        
        if (currentSize >= maxSize) {
            // Pool is full, don't add this view
            Log.d(TAG, "♻️ Pool for '$viewType' is full (max: $maxSize), discarding view")
            return
        }
        
        val pool = pools.getOrPut(viewType) { ConcurrentLinkedQueue() }
        pool.offer(view)
        poolSizes[viewType] = currentSize + 1
        
        Log.d(TAG, "♻️ Released view to pool for type '$viewType' (pool size: ${poolSizes[viewType]})")
    }
    
    /**
     * Reset a view to a clean state before reusing
     */
    private fun resetViewForReuse(view: View) {
        try {
            // Remove from parent if attached
            val parent = view.parent as? ViewGroup
            parent?.removeView(view)
            
            // Clear any state that might interfere with reuse
            view.alpha = 1.0f
            view.visibility = View.VISIBLE
            view.isEnabled = true
            view.isClickable = false
            view.isFocusable = false
            
            // Clear any layout params that might be specific to previous parent
            view.layoutParams = null
            
            // Clear any view-specific state
            if (view is ViewGroup) {
                view.removeAllViews()
            }
            
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Error resetting view for reuse: ${e.message}")
        }
    }
    
    /**
     * Set maximum pool size for a specific view type
     */
    fun setMaxPoolSize(viewType: String, maxSize: Int) {
        maxPoolSizes[viewType] = maxSize
        Log.d(TAG, "📊 Set max pool size for '$viewType' to $maxSize")
        
        // Trim pool if it exceeds new max size
        val pool = pools[viewType]
        if (pool != null) {
            val currentSize = poolSizes.getOrDefault(viewType, 0)
            if (currentSize > maxSize) {
                val toRemove = currentSize - maxSize
                repeat(toRemove) {
                    pool.poll()?.let {
                        // View will be garbage collected
                    }
                }
                poolSizes[viewType] = maxSize
                Log.d(TAG, "✂️ Trimmed pool for '$viewType' by $toRemove views")
            }
        }
    }
    
    /**
     * Clear all pools (useful for memory management)
     */
    fun clearAll() {
        pools.clear()
        poolSizes.clear()
        maxPoolSizes.clear()
        Log.d(TAG, "🗑️ Cleared all view pools")
    }
    
    /**
     * Clear pool for a specific view type
     */
    fun clearPool(viewType: String) {
        pools.remove(viewType)
        poolSizes.remove(viewType)
        maxPoolSizes.remove(viewType)
        Log.d(TAG, "🗑️ Cleared pool for type '$viewType'")
    }
    
    /**
     * Get current pool size for a view type
     */
    fun getPoolSize(viewType: String): Int {
        return poolSizes.getOrDefault(viewType, 0)
    }
    
    /**
     * Get statistics about all pools
     */
    fun getPoolStats(): Map<String, Int> {
        return poolSizes.toMap()
    }
}

