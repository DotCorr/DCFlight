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
import com.dotcorr.dcflight.components.DCFPropConstants
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

    /**
     * ⚡ PERFORMANCE OPTIMIZATION: Component Instance Caching
     * 
     * Cache component class instances to avoid repeated instantiation overhead.
     * Component instances are stateless factories, so caching them is safe.
     */
    private val componentInstanceCache = ConcurrentHashMap<String, DCFComponent>()
    
    /**
     * Get or create a cached component instance for a given view type
     * This avoids the overhead of calling getDeclaredConstructor().newInstance() repeatedly
     */
    private fun getCachedComponentInstance(viewType: String): DCFComponent? {
        val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
            ?: return null
        
        // Return cached instance if available, otherwise create and cache
        return componentInstanceCache.getOrPut(viewType) {
            try {
                componentClass.getDeclaredConstructor().newInstance()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create component instance for type '$viewType'", e)
                throw e
            }
        }
    }

    /**
     * Sets the application context for view creation.
     * 
     * @param context The Android application context
     */
    fun setContext(context: Context) {
        appContext = context
    }

    /**
     * Initializes the bridge implementation.
     * 
     * @return `true` if initialization succeeded, `false` otherwise
     */
    fun initialize(): Boolean {
        if (isInitialized) return true
        Log.d(TAG, "Initializing DCMauiBridgeImpl")
        isInitialized = true
        return true
    }

    /**
     * Handles tunnel method calls from Dart to native components.
     * 
     * @param componentType The type of component to call the method on
     * @param method The method name to call
     * @param params Parameters for the method call
     * @return The result of the method call, or `null` if it failed
     */
    fun handleTunnelMethod(componentType: String, method: String, params: Map<String, Any>): Any? {
        Log.d(TAG, "Tunneling $method to $componentType")
        
        return try {
            // ⚡ PERFORMANCE: Use cached component instance
            val componentInstance = getCachedComponentInstance(componentType)
            if (componentInstance != null) {
                componentInstance.handleTunnelMethod(method, params)
            } else {
                Log.e(TAG, "Component $componentType not registered or failed to create instance")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle tunnel method", e)
            null
        }
    }

    /**
     * Creates a new native view with the specified type and properties.
     * 
     * If a view with the same ID already exists and is in the hierarchy,
     * it will be updated instead. If it exists but is not in the hierarchy,
     * it will be deleted and recreated.
     * 
     * @param viewId Unique identifier for the view
     * @param viewType Component type (e.g., "View", "Text", "Button")
     * @param propsJson JSON string containing view properties
     * @return `true` if the view was created successfully, `false` otherwise
     */
    fun createView(viewId: String, viewType: String, propsJson: String): Boolean {
        return try {
            val existingView = ViewRegistry.shared.getView(viewId)
            if (existingView != null) {
                // Check if view is actually in the hierarchy - if not, delete and recreate
                if (existingView.parent == null) {
                    deleteView(viewId)
                } else {
                    return updateView(viewId, propsJson)
                }
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

            val success = com.dotcorr.dcflight.Coordinator.DCFViewManager.shared.createView(viewId, viewType, props)
            if (!success) {
                return false
            }
            
            val view = ViewRegistry.shared.getView(viewId)
            if (view != null) {
                views[viewId] = view
                view.visibility = View.VISIBLE
                view.alpha = 1.0f
            } else {
                Log.e(TAG, "View '$viewId' was created but not found in registry")
                return false
            }

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create view: $viewId", e)
            false
        }
    }

    /**
     * Updates properties of an existing native view.
     * 
     * Separates layout properties from non-layout properties and applies them
     * through the appropriate systems (YogaShadowTree for layout, component updateView for others).
     * 
     * @param viewId Unique identifier for the view to update
     * @param propsJson JSON string containing property changes
     * @return `true` if the view was updated successfully, `false` otherwise
     */
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

            val layoutProps = extractLayoutProps(props)
            val nonLayoutProps = props.filter { !layoutProps.containsKey(it.key) }

            // CRITICAL: Only trigger layout calculation if layout props actually changed
            // This prevents double layout passes when only content changes
            if (layoutProps.isNotEmpty()) {
                // Get stored props from view to compare with new props
                @Suppress("UNCHECKED_CAST")
                val storedProps = (view.getTag(com.dotcorr.dcflight.components.DCFTags.STORED_PROPS_KEY) as? MutableMap<String, Any?>) ?: emptyMap<String, Any?>()
                val previousLayoutProps = extractLayoutProps(storedProps)
                
                // Check if layout props actually changed
                // Convert both to non-null maps for comparison
                val layoutPropsNonNull = layoutProps.filterValues { it != null }.mapValues { it.value!! }
                val previousLayoutPropsNonNull = previousLayoutProps.filterValues { it != null }.mapValues { it.value!! }
                
                val layoutPropsChanged = layoutPropsNonNull.any { (key, value) ->
                    previousLayoutPropsNonNull[key] != value
                } || previousLayoutPropsNonNull.keys != layoutPropsNonNull.keys
                
                if (layoutPropsChanged) {
                    val isScreen = YogaShadowTree.shared.isScreenRoot(viewId)
                    
                    if (isScreen) {
                        YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
                    } else {
                        DCFLayoutManager.shared.updateNodeWithLayoutProps(
                            nodeId = viewId,
                            componentType = viewType,
                            props = layoutProps.filterValues { it != null }.mapValues { it.value!! }
                        )
                    }
                }
            }

            if (nonLayoutProps.isNotEmpty()) {
                val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
                if (componentClass != null) {
                    try {
                        // ⚡ PERFORMANCE: Use cached component instance (matches ViewManager pattern)
                        val componentInstance = getCachedComponentInstance(viewType)
                        if (componentInstance != null) {
                        componentInstance.updateView(view, nonLayoutProps)
                        } else {
                            Log.e(TAG, "Failed to get component instance for type: $viewType")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error calling updateView on $viewType component", e)
                    }
                } else {
                    Log.w(TAG, "Component class not found for type: $viewType")
                }
            }

            // Framework controls visibility in layout application (not here)
            // Visibility is ensured in DCFLayoutManager.applyLayoutDirectly (matches iOS)
            // This prevents redundant visibility changes that cause flash

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update view: $viewId", e)
            false
        }
    }

    /**
     * Deletes a native view and all its children from the view hierarchy.
     * 
     * @param viewId Unique identifier for the view to delete
     * @return `true` if the view was deleted successfully, `false` otherwise
     */
    fun deleteView(viewId: String): Boolean {
        return try {
            deleteChildrenRecursively(viewId)
            
            val view = ViewRegistry.shared.getView(viewId)
            val viewType = ViewRegistry.shared.getViewType(viewId)
            
            if (view != null) {
                val parentView = view.parent as? ViewGroup
                parentView?.removeView(view)
            }
            
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

    /**
     * Attaches a child view to a parent view at the specified index.
     * 
     * If the child is already attached to another parent, it will be removed first.
     * Updates the view hierarchy and YogaShadowTree accordingly.
     * 
     * @param childId Unique identifier for the child view
     * @param parentId Unique identifier for the parent view
     * @param index Position in the parent's child list
     * @return `true` if the view was attached successfully, `false` otherwise
     */
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

            if (childView.parent != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                Log.d(TAG, "Removed child '$childId' from existing parent")
            }

                try {
                    if (index >= 0 && index <= parentViewGroup.childCount) {
                        parentViewGroup.addView(childView, index)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at index $index")
                    } else {
                        parentViewGroup.addView(childView)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at end")
                    }
                    
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

    /**
     * Sets the children of a view, replacing any existing children.
     * 
     * Removes all current children and attaches the new children in the specified order.
     * Updates the view hierarchy and YogaShadowTree accordingly.
     * 
     * @param viewId Unique identifier for the parent view
     * @param childrenIds List of child view identifiers in order
     * @return `true` if children were set successfully, `false` otherwise
     */
    fun setChildren(viewId: String, childrenIds: List<String>): Boolean {
        return try {
            val parentView = ViewRegistry.shared.getView(viewId)
            
            if (parentView == null) {
                Log.e(TAG, "setChildren: parent view '$viewId' not found in registry")
                return false
            }
            
            // ✅ FIX: Filter out child views that aren't registered yet (race condition protection)
            // This prevents crashes when setChildren is called before all views are registered
            val registeredChildIds = childrenIds.filter { childId ->
                val exists = ViewRegistry.shared.getView(childId) != null
                if (!exists) {
                    Log.w(TAG, "setChildren: Child view '$childId' not yet registered, skipping")
                }
                exists
            }
            
            if (registeredChildIds.isEmpty() && childrenIds.isNotEmpty()) {
                Log.w(TAG, "setChildren: No child views registered yet, deferring setChildren for view '$viewId'")
                // All children missing - likely a race condition, skip for now
                // The framework will retry on next update cycle
                return false
            }
            
            val parentViewGroup = parentView as? ViewGroup

            if (parentViewGroup == null) {
                Log.e(TAG, "setChildren: Parent view '$viewId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                return false
            }

            // Check if this is a DCFScreenComponent's FrameLayout (has DCFScreen tag)
            if (parentViewGroup.tag == "DCFScreen") {
                Log.d(TAG, "🎯 Using custom setChildren for DCFScreen: $viewId")
                val childViews = childrenIds.mapNotNull { childId ->
                    ViewRegistry.shared.getView(childId)
                }
                
                // Remove existing children (except navigation bar)
                val childCount = parentViewGroup.childCount
                for (i in childCount - 1 downTo 0) {
                    val child = parentViewGroup.getChildAt(i)
                    if (child.tag != "NavigationBar") { // Keep navigation bar
                        parentViewGroup.removeViewAt(i)
                    }
                }
                
                // Add new children
                childViews.forEach { childView ->
                    parentViewGroup.addView(childView)
                    childView.layoutParams = android.widget.FrameLayout.LayoutParams(
                        android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                        android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    childView.visibility = android.view.View.VISIBLE
                    childView.alpha = 1.0f
                }
                
                // Update view hierarchy
                viewHierarchy[viewId]?.clear()
                childrenIds.forEach { childId ->
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = childrenIds.indexOf(childId))
                }
                
                Log.d(TAG, "✅ Added ${childViews.size} children to DCFScreen: $viewId")
                return true
            }

            // Fallback to default behavior
            parentViewGroup.removeAllViews()
            viewHierarchy[viewId]?.clear()

            registeredChildIds.forEachIndexed { index: Int, childId: String ->
                val childView = ViewRegistry.shared.getView(childId)
                if (childView != null) {
                    parentViewGroup.addView(childView)
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                    
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = index)
                }
            }

            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set children for view: $viewId", e)
            false
        }
    }


    /**
     * Commits a batch of operations atomically with optimized performance.
     * 
     * Accepts pre-serialized JSON strings to eliminate native JSON parsing overhead.
     * Operations are separated into create, update, attach, and event registration phases,
     * then executed in order before triggering a single layout calculation.
     * 
     * @param operations List of operation dictionaries containing view operations
     * @return `true` if all operations succeeded, `false` otherwise
     */
    fun commitBatchUpdate(operations: List<Map<String, Any>>): Boolean {
        data class CreateOp(val viewId: String, val viewType: String, val propsJson: String)
        data class UpdateOp(val viewId: String, val propsJson: String)
        data class AttachOp(val childId: String, val parentId: String, val index: Int)
        data class AddEventListenersOp(val viewId: String, val eventTypes: List<String>)
        
        val createOps = mutableListOf<CreateOp>()
        val updateOps = mutableListOf<UpdateOp>()
        val attachOps = mutableListOf<AttachOp>()
        val eventOps = mutableListOf<AddEventListenersOp>()
        
        // Parse phase - collect all operations
        
        operations.forEach { operation ->
            val operationType = operation["operation"] as? String
            
            when (operationType) {
                "createView" -> {
                    val viewId = operation["viewId"] as? String
                    val viewType = operation["viewType"] as? String
                    
                    if (viewId != null && viewType != null) {
                        val propsJson = operation["propsJson"] as? String ?: run {
                            val props = operation["props"] as? Map<String, Any>
                            if (props != null) {
                                JSONObject(props).toString()
                            } else {
                                "{}"
                            }
                        }
                        createOps.add(CreateOp(viewId, viewType, propsJson))
                    }
                }
                
                "updateView" -> {
                    val viewId = operation["viewId"] as? String
                    
                    if (viewId != null) {
                        val propsJson = operation["propsJson"] as? String ?: run {
                            val props = operation["props"] as? Map<String, Any>
                            if (props != null) {
                                JSONObject(props).toString()
                            } else {
                                "{}"
                            }
                        }
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
        }
        
        try {
            // Execute phase - process all operations
            createOps.forEach { op ->
                createView(op.viewId, op.viewType, op.propsJson)
            }
            
            updateOps.forEach { op ->
                updateView(op.viewId, op.propsJson)
            }
            
            attachOps.forEach { op ->
                attachView(op.childId, op.parentId, op.index)
            }
            
            eventOps.forEach { op ->
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(op.viewId, op.eventTypes)
            }
            
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()
            
            val rootView = ViewRegistry.shared.getView("root")
            rootView?.let { root ->
                root.measure(
                    View.MeasureSpec.makeMeasureSpec(screenWidth.toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(screenHeight.toInt(), View.MeasureSpec.EXACTLY)
                )
            }
            
            YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
            
            // Make all views visible after layout
            ViewRegistry.shared.allViewIds.forEach { viewId ->
                val view = ViewRegistry.shared.getView(viewId)
                view?.let {
                    it.visibility = View.VISIBLE
                    it.alpha = 1.0f
                }
            }
            
            // Invalidate all views and trigger a post-layout calculation
            rootView?.let { root ->
                fun invalidateAll(v: View) {
                    v.invalidate()
                    if (v is ViewGroup) {
                        for (i in 0 until v.childCount) {
                            invalidateAll(v.getChildAt(i))
                        }
                    }
                }
                invalidateAll(root)
                
                root.post {
                    YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
                }
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed during atomic commit", e)
            return false
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
            componentInstanceCache.clear()
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

    private fun extractLayoutProps(props: Map<String, Any?>): Map<String, Any?> {
        val supportedLayoutProps = DCFPropConstants.LAYOUT_PROPS.toSet()
        return props.filter { supportedLayoutProps.contains(it.key) }
    }
}

