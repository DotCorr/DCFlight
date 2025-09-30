/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.util.Log
import android.view.View
import java.util.concurrent.ConcurrentHashMap

/**
 * Registry for storing and managing view references
 * Matches iOS ViewRegistry exactly
 */
class ViewRegistry private constructor() {

    companion object {
        private const val TAG = "ViewRegistry"
        
        @JvmField
        val shared = ViewRegistry()
    }

    data class ViewTypeInfo(val view: View, val type: String)
    
    private val registry = ConcurrentHashMap<String, ViewTypeInfo>()

    fun registerView(view: View, id: String, type: String) {
        registry[id] = ViewTypeInfo(view, type)
        DCFLayoutManager.shared.registerView(view, id)
        Log.d(TAG, "Registered view: $id of type: $type")
    }

    fun getViewInfo(id: String): ViewTypeInfo? {
        return registry[id]
    }

    fun getView(id: String): View? {
        return registry[id]?.view
    }

    fun getViewType(id: String): String? {
        return registry[id]?.type
    }

    fun removeView(id: String) {
        val viewInfo = registry.remove(id)
        if (viewInfo != null) {
            DCFLayoutManager.shared.unregisterView(id)
            Log.d(TAG, "Removed view: $id of type: ${viewInfo.type}")
        }
    }

    fun hasView(id: String): Boolean {
        return registry.containsKey(id)
    }

    val allViewIds: List<String>
        get() = registry.keys.toList()

    fun cleanup() {
        Log.d(TAG, "Cleaning up ViewRegistry")
        registry.clear()
    }

    fun clearAll() {
        Log.d(TAG, "Clearing all views from ViewRegistry")
        registry.clear()
    }

    /**
     * Clear all views except the root view during hot restart
     * This prevents the first view from not getting cleared off the view manager
     */
    fun clearAllExceptRoot() {
        Log.d(TAG, "Clearing all views except 'root' from ViewRegistry")
        val rootViewInfo = registry["root"]
        registry.clear()
        
        // Restore root if it existed
        if (rootViewInfo != null) {
            registry["root"] = rootViewInfo
            Log.d(TAG, "Preserved root view during cleanup")
        }
        
        Log.d(TAG, "Cleared ${registry.size - (if (rootViewInfo != null) 1 else 0)} views, keeping root")
    }
}