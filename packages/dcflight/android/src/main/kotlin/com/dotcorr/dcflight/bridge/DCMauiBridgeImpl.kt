/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.content.Context
import android.content.res.Resources
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
    private var isInitialized = false

    fun setContext(context: Context) {
        appContext = context
    }

    fun initialize(): Boolean {
        if (isInitialized) return true
        Log.d(TAG, "Initializing DCMauiBridgeImpl")
        isInitialized = true
        // YogaShadowTree and DCFLayoutManager are already initialized as singletons
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
            // CRITICAL: If view exists, update it instead of creating
            if (ViewRegistry.shared.getView(viewId) != null) {
                Log.d(TAG, "🔥 REDIRECT: View $viewId exists, calling updateView")
                return updateView(viewId, propsJson)
            }
            
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

            YogaShadowTree.shared.createNode(viewId, viewType)
            YogaShadowTree.shared.updateNodeLayoutProps(viewId, props)

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

            // CRITICAL FIX: Separate layout props from other props - MATCH iOS exactly
            val layoutProps = extractLayoutProps(props)
            val nonLayoutProps = props.filter { !layoutProps.containsKey(it.key) }

            // Update layout props if any - MATCH iOS DCFViewManager.updateView
            if (layoutProps.isNotEmpty()) {
                val isScreen = YogaShadowTree.shared.isScreenRoot(viewId)
                
                if (isScreen) {
                    YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
                } else {
                    DCFLayoutManager.shared.updateNodeWithLayoutProps(
                        nodeId = viewId,
                        componentType = viewType,
                        props = layoutProps
                    )
                }
            }

            // Update non-layout props - MATCH iOS DCFViewManager.updateView
            if (nonLayoutProps.isNotEmpty()) {
                val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
                if (componentClass != null) {
                    val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                    componentInstance.updateView(view, nonLayoutProps)
                }
            }

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
                Log.e(TAG, "Available views: ${ViewRegistry.shared.allViewIds}")
                return false
            }

            val parentViewGroup = parentView as? ViewGroup
            if (parentViewGroup == null) {
                Log.e(TAG, "Parent view '$parentId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                return false
            }

            // ANDROID ATTACH FIX: Remove from existing parent first
            if (childView.parent != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                Log.d(TAG, "Removed child '$childId' from existing parent")
            }

            // ANDROID ATTACH FIX: Use post to ensure proper timing
            parentViewGroup.post {
                try {
                    if (index >= 0 && index <= parentViewGroup.childCount) {
                        parentViewGroup.addView(childView, index)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at index $index")
                    } else {
                        parentViewGroup.addView(childView)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at end")
                    }
                    
                    // MATCH iOS: Ensure child is visible after attachment
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    
                    Log.d(TAG, "Successfully attached child '$childId' to parent '$parentId'")
                } catch (e: Exception) {
                    Log.e(TAG, "Error in post attachment: ${e.message}", e)
                }
            }

            childToParent[childId] = parentId
            viewHierarchy.getOrPut(parentId) { mutableListOf() }.add(childId)

            YogaShadowTree.shared.addChildNode(parentId, childId, index)

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

            YogaShadowTree.shared.removeNode(viewId)

            true
        } catch (e: Exception) {
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

            childrenIds.forEachIndexed { index: Int, childId: String ->
                val childView = ViewRegistry.shared.getView(childId)
                if (childView != null) {
                    parentViewGroup.addView(childView)
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                    
                    // CRITICAL FIX: Update shadow tree like iOS - this was missing!
                    // This is why initial layout was broken - shadow tree didn't know relationships
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = index)
                }
            }

            // Children are managed through addChildNode calls individually
            // This prevents the one-by-one rendering issue
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set children for view: $viewId", e)
            false
        }
    }

    fun commitBatchUpdate(operations: List<Map<String, Any>>): Boolean {
        Log.d(TAG, "🔥 BATCH: Committing ${operations.size} operations")
        
        return try {
            operations.forEach { operation ->
                Log.d(TAG, "🔥 BATCH: Processing operation: $operation")
                
                // Handle the format from Dart interface_impl.dart
                val operationType = operation["operation"] as? String
                if (operationType != null) {
                    when (operationType) {
                        "createView" -> {
                            val viewId = operation["viewId"] as? String
                            val viewType = operation["viewType"] as? String  
                            val props = operation["props"] as? Map<String, Any>
                            if (viewId != null && viewType != null && props != null) {
                                Log.d(TAG, "🔥 BATCH: Creating view $viewId of type $viewType")
                                // Convert props map to JSON string for consistency
                                val propsJson = JSONObject(props).toString()
                                createView(viewId, viewType, propsJson)
                            }
                        }
                        "updateView" -> {
                            val viewId = operation["viewId"] as? String
                            val props = operation["props"] as? Map<String, Any>
                            if (viewId != null && props != null) {
                                Log.d(TAG, "🔥 BATCH: Updating view $viewId with props")
                                // Convert props map to JSON string for consistency
                                val propsJson = JSONObject(props).toString()
                                updateView(viewId, propsJson)
                            }
                        }
                        "attachView" -> {
                            val childId = operation["childId"] as? String
                            val parentId = operation["parentId"] as? String
                            val index = operation["index"] as? Int
                            if (childId != null && parentId != null && index != null) {
                                Log.d(TAG, "🔥 BATCH: Attaching view $childId to $parentId at index $index")
                                attachView(childId, parentId, index)
                            }
                        }
                        else -> {
                            Log.w(TAG, "🔥 BATCH: Unknown operation type: $operationType")
                        }
                    }
                } else {
                    // Fallback for legacy format (if any)
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
            }
            Log.d(TAG, "🔥 BATCH: Successfully committed all operations")
            
            // ANDROID ARCHITECTURE FIX: Let layout calculation happen naturally
            // This prevents black screen issues while still allowing proper layout
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "🔥 BATCH: Failed to commit batch update", e)
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

    fun clearAll() {
        Log.d(TAG, "🔥 DCF_ENGINE: Clearing DCMauiBridgeImpl")
        try {
            childToParent.clear()
            viewHierarchy.clear()
            Log.d(TAG, "🔥 DCF_ENGINE: DCMauiBridgeImpl cleared successfully")
        } catch (e: Exception) {
            Log.e(TAG, "🔥 DCF_ENGINE: Error clearing DCMauiBridgeImpl", e)
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

    // MATCH iOS SupportedLayoutsProps.supportedLayoutProps exactly
    private fun extractLayoutProps(props: Map<String, Any>): Map<String, Any> {
        val supportedLayoutProps = setOf(
            "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
            "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
            "marginHorizontal", "marginVertical",
            "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
            "paddingHorizontal", "paddingVertical",
            "left", "top", "right", "bottom", "position",
            "translateX", "translateY",
            "rotateInDegrees",
            "scale", "scaleX", "scaleY",
            "flexDirection", "justifyContent", "alignItems", "alignSelf", "alignContent",
            "flexWrap", "flex", "flexGrow", "flexShrink", "flexBasis",
            "display", "overflow", "direction", "borderWidth",
            "aspectRatio", "gap", "rowGap", "columnGap"
        )
        
        return props.filter { supportedLayoutProps.contains(it.key) }
    }
}

