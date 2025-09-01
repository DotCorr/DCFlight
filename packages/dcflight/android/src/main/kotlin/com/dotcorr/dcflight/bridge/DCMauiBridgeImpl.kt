/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.ViewRegistry
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/**
 * Bridge between Dart and native Android code
 */
class DCMauiBridgeImpl private constructor() {

    companion object {
        private const val TAG = "DCMauiBridgeImpl"

        @JvmField
        val shared = DCMauiBridgeImpl()
    }

    internal val views = ConcurrentHashMap<String, View>()
    private val viewHierarchy = ConcurrentHashMap<String, MutableList<String>>()
    private val childToParent = ConcurrentHashMap<String, String>()
    private var appContext: Context? = null

    fun setContext(context: Context) {
        appContext = context
    }

    fun initialize(): Boolean {
        Log.d(TAG, "Initializing DCMauiBridgeImpl")
        YogaShadowTree.shared.initialize()
        DCFLayoutManager.shared.initialize()
        return true
    }

    fun handleTunnelMethod(componentType: String, method: String, params: Map<String, Any>): Any? {
        Log.d(TAG, "Tunneling $method to $componentType")
        
        return try {
            val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
            if (componentClass == null) {
                Log.e(TAG, "Component $componentType not registered")
                return null
            }

            val componentInstance = componentClass.getDeclaredConstructor().newInstance()
            if (componentInstance is DCFComponent) {
                componentInstance.handleTunnelMethod(method, params)
            } else {
                Log.e(TAG, "Component $componentType is not a DCFComponent")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle tunnel method", e)
            null
        }
    }

    fun createView(viewId: String, viewType: String, propsJson: String): Boolean {
        return try {
            val props = if (propsJson.isNotEmpty()) {
                parseJsonToMap(propsJson)
            } else {
                emptyMap()
            }

            val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
            if (componentClass == null) {
                Log.e(TAG, "Component type '$viewType' not found")
                return false
            }

            val context = appContext
            if (context == null) {
                Log.e(TAG, "No context available for creating view")
                return false
            }

            val componentInstance = componentClass.getDeclaredConstructor().newInstance()
            val view = componentInstance.createView(context, props)

            ViewRegistry.shared.registerView(view, viewId, viewType)
            views[viewId] = view

            YogaShadowTree.shared.createNode(viewId, viewType, props)

            Log.d(TAG, "Successfully created view: $viewId of type: $viewType")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create view: $viewId", e)
            false
        }
    }

    fun updateView(viewId: String, propsJson: String): Boolean {
        return try {
            val view = ViewRegistry.shared.getView(viewId)
            if (view == null) {
                Log.e(TAG, "View '$viewId' not found for update")
                return false
            }

            val props = if (propsJson.isNotEmpty()) {
                parseJsonToMap(propsJson)
            } else {
                emptyMap()
            }

            val viewType = ViewRegistry.shared.getViewType(viewId)
            if (viewType == null) {
                Log.e(TAG, "View type for '$viewId' not found")
                return false
            }

            YogaShadowTree.shared.updateNode(viewId, props)

            val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
            if (componentClass != null) {
                val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                componentInstance.updateView(view, props)
            }

            Log.d(TAG, "Successfully updated view: $viewId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update view: $viewId", e)
            false
        }
    }

    fun deleteView(viewId: String): Boolean {
        return try {
            deleteChildrenRecursively(viewId)
            cleanupHierarchyReferences(viewId)
            
            ViewRegistry.shared.removeView(viewId)
            views.remove(viewId)
            YogaShadowTree.shared.removeNode(viewId)
            
            Log.d(TAG, "Successfully deleted view: $viewId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete view: $viewId", e)
            false
        }
    }

    fun attachView(childId: String, parentId: String, index: Int): Boolean {
        return try {
            val childView = ViewRegistry.shared.getView(childId)
            val parentView = ViewRegistry.shared.getView(parentId)

            if (childView == null || parentView == null) {
                Log.e(TAG, "Cannot attach - child '$childId' or parent '$parentId' not found")
                return false
            }

            val parentViewGroup = parentView as? ViewGroup
            if (parentViewGroup == null) {
                Log.e(TAG, "Parent view '$parentId' is not a ViewGroup")
                return false
            }

            if (childView.parent != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
            }

            if (index >= 0 && index <= parentViewGroup.childCount) {
                parentViewGroup.addView(childView, index)
            } else {
                parentViewGroup.addView(childView)
            }

            childToParent[childId] = parentId
            viewHierarchy.getOrPut(parentId) { mutableListOf() }.add(childId)

            YogaShadowTree.shared.attachChild(childId, parentId, index)

            Log.d(TAG, "Successfully attached view: $childId to $parentId at index $index")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to attach view: $childId to $parentId", e)
            false
        }
    }

    fun detachView(viewId: String): Boolean {
        return try {
            val view = ViewRegistry.shared.getView(viewId)
            if (view == null) {
                Log.e(TAG, "View '$viewId' not found for detach")
                return false
            }

            val parentView = view.parent as? ViewGroup
            parentView?.removeView(view)

            val parentId = childToParent.remove(viewId)
            if (parentId != null) {
                viewHierarchy[parentId]?.remove(viewId)
            }

            YogaShadowTree.shared.detachChild(viewId)

            Log.d(TAG, "Successfully detached view: $viewId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to detach view: $viewId", e)
            false
        }
    }

    fun setChildren(viewId: String, childrenIds: List<String>): Boolean {
        return try {
            val parentView = ViewRegistry.shared.getView(viewId)
            val parentViewGroup = parentView as? ViewGroup

            if (parentViewGroup == null) {
                Log.e(TAG, "Parent view '$viewId' is not a ViewGroup")
                return false
            }

            parentViewGroup.removeAllViews()
            viewHierarchy[viewId]?.clear()

            childrenIds.forEach { childId ->
                val childView = ViewRegistry.shared.getView(childId)
                if (childView != null) {
                    parentViewGroup.addView(childView)
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                }
            }

            YogaShadowTree.shared.setChildren(viewId, childrenIds)

            Log.d(TAG, "Successfully set children for view: $viewId")
            
            // FORCE layout calculation immediately after setting children
            DCFLayoutManager.shared.calculateLayoutNow()
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set children for view: $viewId", e)
            false
        }
    }

    fun commitBatchUpdate(operations: List<Map<String, Any>>): Boolean {
        return try {
            operations.forEach { operation ->
                val type = operation["type"] as? String
                val args = operation["args"] as? Map<String, Any>

                if (type != null && args != null) {
                    when (type) {
                        "createView" -> {
                            val viewId = args["viewId"] as? String
                            val viewType = args["viewType"] as? String
                            val propsJson = args["propsJson"] as? String
                            if (viewId != null && viewType != null && propsJson != null) {
                                createView(viewId, viewType, propsJson)
                            }
                        }
                        "updateView" -> {
                            val viewId = args["viewId"] as? String
                            val propsJson = args["propsJson"] as? String
                            if (viewId != null && propsJson != null) {
                                updateView(viewId, propsJson)
                            }
                        }
                        "attachView" -> {
                            val childId = args["childId"] as? String
                            val parentId = args["parentId"] as? String
                            val index = args["index"] as? Int
                            if (childId != null && parentId != null && index != null) {
                                attachView(childId, parentId, index)
                            }
                        }
                    }
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to commit batch update", e)
            false
        }
    }

    private fun deleteChildrenRecursively(parentId: String) {
        val children = viewHierarchy[parentId] ?: return
        children.forEach { childId ->
            deleteChildrenRecursively(childId)
        }
        viewHierarchy.remove(parentId)
    }

    private fun cleanupHierarchyReferences(viewId: String) {
        childToParent.remove(viewId)
        val parentId = childToParent[viewId]
        if (parentId != null) {
            viewHierarchy[parentId]?.remove(viewId)
        }
    }

    private fun parseJsonToMap(json: String): Map<String, Any> {
        return try {
            val jsonObject = JSONObject(json)
            jsonObject.keys().asSequence().associateWith { key ->
                when (val value = jsonObject.get(key)) {
                    is JSONObject -> parseJsonObjectToMap(value)
                    is JSONArray -> parseJsonArrayToList(value)
                    else -> value
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse JSON: $json", e)
            emptyMap()
        }
    }

    private fun parseJsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        return jsonObject.keys().asSequence().associateWith { key ->
            when (val value = jsonObject.get(key)) {
                is JSONObject -> parseJsonObjectToMap(value)
                is JSONArray -> parseJsonArrayToList(value)
                else -> value
            }
        }
    }

    private fun parseJsonArrayToList(jsonArray: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until jsonArray.length()) {
            when (val value = jsonArray.get(i)) {
                is JSONObject -> list.add(parseJsonObjectToMap(value))
                is JSONArray -> list.add(parseJsonArrayToList(value))
                else -> list.add(value)
            }
        }
        return list
    }
}