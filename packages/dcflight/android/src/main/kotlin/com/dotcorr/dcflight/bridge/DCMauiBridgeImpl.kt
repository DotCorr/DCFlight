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

            // REACT-LIKE RENDERING: Attach synchronously, no post()
            // Views MUST be attached immediately for batch commits to work properly
            try {
                if (index >= 0 && index <= parentViewGroup.childCount) {
                    parentViewGroup.addView(childView, index)
                    Log.d(TAG, "Attached child '$childId' to parent '$parentId' at index $index")
                } else {
                    parentViewGroup.addView(childView)
                    Log.d(TAG, "Attached child '$childId' to parent '$parentId' at end")
                }
                
                // REACT-LIKE RENDERING: Do NOT manipulate visibility!
                // Views are visible by default. Let the natural view lifecycle handle this.
                
                Log.d(TAG, "Successfully attached child '$childId' to parent '$parentId'")
            } catch (e: Exception) {
                Log.e(TAG, "Error in attachment: ${e.message}", e)
                throw e
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
        Log.d(TAG, "🔥 BATCH: Committing ${operations.size} operations (REACT-LIKE ATOMIC)")
        
        // REACT-LIKE RENDERING: Phase 1 - RENDER (Collect all operations, no side effects)
        data class CreateOp(val viewId: String, val viewType: String, val propsJson: String)
        data class UpdateOp(val viewId: String, val propsJson: String)
        data class AttachOp(val childId: String, val parentId: String, val index: Int)
        data class AddEventListenersOp(val viewId: String, val eventTypes: List<String>)
        
        val createOps = mutableListOf<CreateOp>()
        val updateOps = mutableListOf<UpdateOp>()
        val attachOps = mutableListOf<AttachOp>()
        val eventOps = mutableListOf<AddEventListenersOp>()
        
        // Collect all operations first (pure, no side effects)
        operations.forEach { operation ->
            val operationType = operation["operation"] as? String
            if (operationType != null) {
                when (operationType) {
                    "createView" -> {
                        val viewId = operation["viewId"] as? String
                        val viewType = operation["viewType"] as? String  
                        val props = operation["props"] as? Map<String, Any>
                        if (viewId != null && viewType != null && props != null) {
                            val propsJson = JSONObject(props).toString()
                            createOps.add(CreateOp(viewId, viewType, propsJson))
                        }
                    }
                    "updateView" -> {
                        val viewId = operation["viewId"] as? String
                        val props = operation["props"] as? Map<String, Any>
                        if (viewId != null && props != null) {
                            val propsJson = JSONObject(props).toString()
                            updateOps.add(UpdateOp(viewId, propsJson))
                        }
                    }
                    "attachView" -> {
                        val childId = operation["childId"] as? String
                        val parentId = operation["parentId"] as? String
                        val index = operation["index"] as? Int
                        if (childId != null && parentId != null && index != null) {
                            attachOps.add(AttachOp(childId, parentId, index))
                        }
                    }
                    "addEventListeners" -> {
                        val viewId = operation["viewId"] as? String
                        val eventTypes = operation["eventTypes"] as? List<String>
                        if (viewId != null && eventTypes != null) {
                            eventOps.add(AddEventListenersOp(viewId, eventTypes))
                        }
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
                                createOps.add(CreateOp(viewId, viewType, propsJson))
                            }
                        }
                        "updateView" -> {
                            val viewId = args["viewId"] as? String
                            val propsJson = args["propsJson"] as? String
                            if (viewId != null && propsJson != null) {
                                updateOps.add(UpdateOp(viewId, propsJson))
                            }
                        }
                        "attachView" -> {
                            val childId = args["childId"] as? String
                            val parentId = args["parentId"] as? String
                            val index = args["index"] as? Int
                            if (childId != null && parentId != null && index != null) {
                                attachOps.add(AttachOp(childId, parentId, index))
                            }
                        }
                    }
                }
            }
        }
        
        Log.d(TAG, "🔥 BATCH: Collected ${createOps.size} creates, ${updateOps.size} updates, ${attachOps.size} attaches, ${eventOps.size} event registrations")
        
        // REACT-LIKE RENDERING: Phase 2 - COMMIT (Apply ALL operations atomically)
        return try {
            // CRITICAL FIX: Execute synchronously, not posted!
            // The bridge methods are already called on main thread from Flutter
            // Using Handler.post() causes the function to return before work is done
            
            // 1. Create all views first
            createOps.forEach { op ->
                Log.d(TAG, "🔥 BATCH_COMMIT: Creating ${op.viewId}")
                createView(op.viewId, op.viewType, op.propsJson)
            }
            
            // 2. Update all view props
            updateOps.forEach { op ->
                Log.d(TAG, "🔥 BATCH_COMMIT: Updating ${op.viewId}")
                updateView(op.viewId, op.propsJson)
            }
            
            // 3. Attach all views to build tree structure
            attachOps.forEach { op ->
                Log.d(TAG, "🔥 BATCH_COMMIT: Attaching ${op.childId} to ${op.parentId}")
                attachView(op.childId, op.parentId, op.index)
            }
            
            // 4. Register event listeners AFTER all views exist
            eventOps.forEach { op ->
                Log.d(TAG, "🔥 BATCH_COMMIT: Registering event listeners for ${op.viewId}")
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(op.viewId, op.eventTypes)
            }
            
            // 5. REACT-LIKE: Layout calculation happens ONCE for entire tree
            //    This is the equivalent of React's layout phase after commit
            Log.d(TAG, "🔥 BATCH_COMMIT: Triggering SYNCHRONOUS layout calculation")
            
            // Get screen dimensions
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()
            
            // Calculate and apply layout SYNCHRONOUSLY (not posted to executor)
            val layoutSuccess = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
            Log.d(TAG, "🔥 BATCH_COMMIT: Layout calculation completed synchronously: $layoutSuccess")
            
            // Force a redraw of the root view to ensure all changes are visible
            val rootView = ViewRegistry.shared.getView("root")
            rootView?.let { root ->
                // Recursively invalidate all views to ensure text renders on initial mount
                // NOTE: Do NOT call requestLayout() - it conflicts with manual layout
                fun invalidateAll(v: View) {
                    v.invalidate()
                    if (v is ViewGroup) {
                        for (i in 0 until v.childCount) {
                            invalidateAll(v.getChildAt(i))
                        }
                    }
                }
                invalidateAll(root)
                Log.d(TAG, "🔥 BATCH_COMMIT: Forced recursive invalidation of entire hierarchy")
            }
            
            Log.d(TAG, "🔥 BATCH_COMMIT: Successfully committed all operations atomically")
            true
        } catch (e: Exception) {
            Log.e(TAG, "🔥 BATCH_COMMIT: Failed during atomic commit", e)
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

