/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.bridge

import android.content.Context
import android.util.Log
import com.dotcorr.dcflight.Coordinator.DCFViewManager
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.components.DCFComponentRegistry
import org.json.JSONArray
import org.json.JSONObject

/**
 * JNI interface for DCFlight native operations.
 *
 * This is NOT a MethodChannel bridge - it provides direct JNI access
 * from Dart to Android native code for better performance.
 *
 * All methods are called from Dart via JNI bindings (no MethodChannel).
 */
@JvmName("DCFlightJni")
class DCFlightJni(private val context: Context) {
    
    companion object {
        private const val TAG = "DCFlightJni"
        
        // Event callback interface for native-to-Dart communication
        interface EventCallback {
            fun onEvent(viewId: Int, eventType: String, eventDataJson: String)
        }
        
        // Screen dimensions callback interface
        interface ScreenDimensionsCallback {
            fun onDimensionsChanged(dimensionsJson: String)
        }
        
        private var eventCallback: EventCallback? = null
        private var screenDimensionsCallback: ScreenDimensionsCallback? = null
        
        @JvmStatic
        fun setEventCallback(callback: EventCallback?) {
            eventCallback = callback
        }
        
        @JvmStatic
        fun setScreenDimensionsCallback(callback: ScreenDimensionsCallback?) {
            screenDimensionsCallback = callback
        }
        
        fun sendEvent(viewId: Int, eventType: String, eventData: Map<String, Any>) {
            eventCallback?.let { callback ->
                try {
                    val eventDataJson = JSONObject(eventData).toString()
                    callback.onEvent(viewId, eventType, eventDataJson)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send event via JNI callback", e)
                }
            }
        }
        
    fun sendScreenDimensionsChanged(dimensions: Map<String, Any>) {
        screenDimensionsCallback?.let { callback ->
            try {
                val dimensionsJson = JSONObject(dimensions).toString()
                callback.onDimensionsChanged(dimensionsJson)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send screen dimensions via JNI callback", e)
            }
        }
    }
    
    fun getSessionToken(): String? {
        return com.dotcorr.dcflight.bridge.DCFHotRestartManager.getSessionToken()
    }
    
    fun createSessionToken(): String {
        return com.dotcorr.dcflight.bridge.DCFHotRestartManager.createSessionToken()
    }
    
    fun clearSessionToken() {
        com.dotcorr.dcflight.bridge.DCFHotRestartManager.clearSessionToken()
    }
    
    fun cleanupViews() {
        com.dotcorr.dcflight.bridge.DCFHotRestartManager.cleanupViews()
    }
    }
    
    /**
     * Initialize the DCFlight bridge.
     * @return true if initialization succeeded, false otherwise
     */
    fun initialize(): Boolean {
        return try {
            DCFlightNative.shared.initialize()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize bridge", e)
            false
        }
    }
    
    /**
     * Create a view with the specified ID, type, and properties.
     * @param viewId Unique identifier for the view
     * @param viewType Component type (e.g., "View", "Text", "Button")
     * @param propsJson JSON string containing view properties
     * @return true if the view was created successfully, false otherwise
     */
    fun createView(viewId: Int, viewType: String, propsJson: String): Boolean {
        return try {
            DCFlightNative.shared.createView(viewId, viewType, propsJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create view: $viewId", e)
            false
        }
    }
    
    /**
     * Update properties of an existing view.
     * @param viewId Unique identifier for the view to update
     * @param propsJson JSON string containing property changes
     * @return true if the view was updated successfully, false otherwise
     */
    fun updateView(viewId: Int, propsJson: String): Boolean {
        return try {
            DCFlightNative.shared.updateView(viewId, propsJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update view: $viewId", e)
            false
        }
    }
    
    /**
     * Delete a view.
     * @param viewId Unique identifier for the view to delete
     * @return true if the view was deleted successfully, false otherwise
     */
    fun deleteView(viewId: Int): Boolean {
        return try {
            DCFlightNative.shared.deleteView(viewId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete view: $viewId", e)
            false
        }
    }
    
    /**
     * Detach a view from its parent without deleting it.
     * @param viewId Unique identifier for the view to detach
     * @return true if the view was detached successfully, false otherwise
     */
    fun detachView(viewId: Int): Boolean {
        return try {
            DCFlightNative.shared.detachView(viewId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to detach view: $viewId", e)
            false
        }
    }
    
    /**
     * Attach a child view to a parent view at the specified index.
     * @param childId Unique identifier for the child view
     * @param parentId Unique identifier for the parent view
     * @param index Position in the parent's child list
     * @return true if the view was attached successfully, false otherwise
     */
    fun attachView(childId: Int, parentId: Int, index: Int): Boolean {
        return try {
            DCFlightNative.shared.attachView(childId, parentId, index)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to attach view: $childId to $parentId", e)
            false
        }
    }
    
    /**
     * Set all children for a view (replacing any existing children).
     * @param viewId Unique identifier for the parent view
     * @param childrenIds Array of child view identifiers
     * @return true if children were set successfully, false otherwise
     */
    fun setChildren(viewId: Int, childrenIdsJson: String): Boolean {
        return try {
            val jsonArray = JSONArray(childrenIdsJson)
            val childrenIds = mutableListOf<Int>()
            for (i in 0 until jsonArray.length()) {
                childrenIds.add(jsonArray.getInt(i))
            }
            DCFlightNative.shared.setChildren(viewId, childrenIds)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set children for view: $viewId", e)
            false
        }
    }
    
    /**
     * Add event listeners to a view.
     * @param viewId Unique identifier for the view
     * @param eventTypes JSON array string of event types (e.g., "[\"onPress\",\"onChange\"]")
     * @return true if listeners were added successfully, false otherwise
     */
    fun addEventListeners(viewId: Int, eventTypes: String): Boolean {
        return try {
            val eventTypesArray = JSONArray(eventTypes)
            val eventTypesList = mutableListOf<String>()
            for (i in 0 until eventTypesArray.length()) {
                eventTypesList.add(eventTypesArray.getString(i))
            }
            com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler.shared.addEventListenersForBatch(viewId, eventTypesList)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add event listeners for view: $viewId", e)
            false
        }
    }
    
    /**
     * Remove event listeners from a view.
     * @param viewId Unique identifier for the view
     * @param eventTypes JSON array string of event types to remove (e.g., "[\"onPress\",\"onChange\"]")
     * @return true if listeners were removed successfully, false otherwise
     */
    fun removeEventListeners(viewId: Int, eventTypes: String): Boolean {
        return try {
            val eventTypesArray = JSONArray(eventTypes)
            val eventTypesList = mutableListOf<String>()
            for (i in 0 until eventTypesArray.length()) {
                eventTypesList.add(eventTypesArray.getString(i))
            }
            DCMauiEventMethodHandler.shared.removeEventListeners(viewId, eventTypesList)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove event listeners for view: $viewId", e)
            false
        }
    }
    
    /**
     * Start a batch update (multiple operations that will be applied atomically).
     * @return true if batch update started successfully, false if one is already in progress
     */
    fun startBatchUpdate(): Boolean {
        return true // Batch updates are handled on Dart side
    }
    
    /**
     * Commit all queued batch update operations atomically.
     * @param operationsJson JSON string containing array of operations
     * @return true if the batch was committed successfully, false otherwise
     */
    fun commitBatchUpdate(operationsJson: String): Boolean {
        return try {
            val operationsArray = JSONArray(operationsJson)
            val operations = mutableListOf<Map<String, Any>>()
            
            for (i in 0 until operationsArray.length()) {
                val operationObj = operationsArray.getJSONObject(i)
                val operationMap = mutableMapOf<String, Any>()
                
                val keys = operationObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = operationObj.get(key)
                    operationMap[key] = when (value) {
                        is JSONArray -> {
                            val list = mutableListOf<Any>()
                            for (j in 0 until value.length()) {
                                list.add(value.get(j))
                            }
                            list
                        }
                        is JSONObject -> {
                            val map = mutableMapOf<String, Any>()
                            val objKeys = value.keys()
                            while (objKeys.hasNext()) {
                                val objKey = objKeys.next()
                                map[objKey] = value.get(objKey)
                            }
                            map
                        }
                        else -> value
                    }
                }
                operations.add(operationMap)
            }
            
            DCFlightNative.shared.commitBatchUpdate(operations)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to commit batch update", e)
            false
        }
    }
    
    /**
     * Cancel the pending batch updates.
     * @return true if a batch was cancelled, false if no batch was in progress
     */
    fun cancelBatchUpdate(): Boolean {
        return true // Batch updates are handled on Dart side
    }
    
    /**
     * Get screen dimensions and metrics.
     * @return JSON string containing screen dimensions, or null if it failed
     */
    fun getScreenDimensions(): String? {
        return try {
            val dimensions = com.dotcorr.dcflight.utils.DCFScreenUtilities.shared.getScreenDimensions()
            JSONObject(dimensions).toString()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get screen dimensions", e)
            null
        }
    }
    
    /**
     * Get display metrics.
     * @return JSON string containing display metrics, or null if it failed
     */
    fun getDisplayMetrics(): String? {
        return try {
            val metrics = com.dotcorr.dcflight.utils.DCFScreenUtilities.shared.getDisplayMetrics()
            JSONObject(metrics).toString()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get display metrics", e)
            null
        }
    }
    
    /**
     * Convert DP to pixels.
     * @param dp Density-independent pixels value
     * @return Pixel value
     */
    fun convertDpToPx(dp: Double): Double {
        return try {
            com.dotcorr.dcflight.utils.DCFScreenUtilities.shared.convertDpToPx(dp.toFloat()).toDouble()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert DP to PX", e)
            dp
        }
    }
    
    /**
     * Convert pixels to DP.
     * @param px Pixel value
     * @return Density-independent pixels value
     */
    fun convertPxToDp(px: Double): Double {
        return try {
            com.dotcorr.dcflight.utils.DCFScreenUtilities.shared.convertPxToDp(px.toFloat()).toDouble()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert PX to DP", e)
            px
        }
    }
    
    /**
     * Call a method on a native component via the tunnel mechanism.
     * @param componentType Type of component to call the method on
     * @param method Method name to call
     * @param paramsJson JSON string containing parameters for the method call
     * @return JSON string containing the result, or null if it failed
     */
    fun tunnel(componentType: String, method: String, paramsJson: String): String? {
        return try {
            val params = JSONObject(paramsJson)
            val paramsMap = mutableMapOf<String, Any>()
            
            val keys = params.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                paramsMap[key] = params.get(key)
            }
            
            val result = DCFlightNative.shared.handleTunnelMethod(componentType, method, paramsMap)
            
            if (result == null) {
                return null
            }
            
            // Convert result to JSON string
            when (result) {
                is Map<*, *> -> JSONObject(result as Map<*, *>).toString()
                is List<*> -> JSONArray(result).toString()
                is String -> "\"$result\""
                is Number -> result.toString()
                is Boolean -> result.toString()
                else -> JSONObject().put("value", result.toString()).toString()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to call tunnel method", e)
            null
        }
    }
}

