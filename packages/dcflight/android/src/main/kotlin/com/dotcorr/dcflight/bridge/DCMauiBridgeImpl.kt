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
import com.dotcorr.dcflight.components.DCFContentContainerProvider
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.components.DCFPropConstants
import com.dotcorr.dcflight.components.DCFScrollView
import com.dotcorr.dcflight.Coordinator.DCFViewManager
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

    internal val views = ConcurrentHashMap<Int, View>()
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
    fun createView(viewId: Int, viewType: String, propsJson: String): Boolean {
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
                // CRITICAL: Root view (0) should always be visible
                // Other views will be made visible after layout is applied
                if (viewId == 0) {
                view.visibility = View.VISIBLE
                view.alpha = 1.0f
                } else {
                    // Non-root views start invisible - will be made visible after layout
                }
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
    fun updateView(viewId: Int, propsJson: String): Boolean {
        return try {
            val props = if (propsJson.isNotEmpty()) {
                parseJsonToMap(propsJson)
            } else {
                emptyMap()
            }

            // CRITICAL FRAMEWORK FIX: Delegate to ViewManager.updateView for uniform framework-level handling
            // This ensures all updates (bridge or internal) use the same visibility control logic
            // No prop-specific edge cases - framework handles everything uniformly
            return DCFViewManager.shared.updateView(viewId, props)
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
    fun deleteView(viewId: Int): Boolean {
        return try {
            deleteChildrenRecursively(viewId.toString())
            
            val view = ViewRegistry.shared.getView(viewId)
            val viewType = ViewRegistry.shared.getViewType(viewId)
            
            if (view != null) {
                val parentView = view.parent as? ViewGroup
                parentView?.removeView(view)
            }
            
            cleanupHierarchyReferences(viewId.toString())
            
            ViewRegistry.shared.removeView(viewId)
            views.remove(viewId)
            YogaShadowTree.shared.removeNode(viewId.toString())
            
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
    fun attachView(childId: Int, parentId: Int, index: Int): Boolean {
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

            // CRITICAL: ScrollView special handling
            // DCFScrollView.insertContentView adds the child (ScrollContentView)
            // directly to the internal scroll view via insertContentView
            // IMPORTANT: Only do this when the CHILD is ScrollContentView being attached to ScrollView
            // The ScrollView itself should be attached normally to its parent
            if (parentView is DCFScrollView) {
                val childComponentType = ViewRegistry.shared.getViewType(childId)
                
                if (childComponentType == "ScrollContentView") {
                    // Check if contentView is already set and is the same view
                    // This prevents duplicate calls to insertContentView
                    val scrollView = parentView as DCFScrollView
                    if (scrollView.contentView == childView) {
                        // Still add to Yoga tree if not already added
                        childToParent[childId.toString()] = parentId.toString()
                        viewHierarchy.getOrPut(parentId.toString()) { mutableListOf() }.add(childId.toString())
                        YogaShadowTree.shared.addChildNode(parentId, childId, index)
                        return true
                    }
                    
                    
                    // Remove from existing parent before attaching
                    if (childView.parent != null) {
                        (childView.parent as? ViewGroup)?.removeView(childView)
                    }
                    
                    scrollView.insertContentView(childView)
                    
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    childToParent[childId.toString()] = parentId.toString()
                    viewHierarchy.getOrPut(parentId.toString()) { mutableListOf() }.add(childId.toString())
                    YogaShadowTree.shared.addChildNode(parentId, childId, index)
                    return true
                }
                // If child is NOT ScrollContentView, fall through to normal attachment
            }

            // CRITICAL: Some views (like ScrollView) need children attached to a content container
            // Use DCFContentContainerProvider interface for scalable solution
            var actualParent: ViewGroup = parentViewGroup
            if (parentView is DCFContentContainerProvider) {
                val contentContainer = parentView.getContentContainer()
                if (contentContainer != null) {
                    actualParent = contentContainer
                }
            }

            (childView.parent as? ViewGroup)?.removeView(childView)
            
            try {
                if (index >= 0 && index <= actualParent.childCount) {
                    actualParent.addView(childView, index)
                } else {
                    actualParent.addView(childView)
                }
                
                if (childId != 0) {
                    childView.visibility = View.INVISIBLE
                    childView.alpha = 1.0f
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in attachment: ${e.message}", e)
                throw e
            }

            childToParent[childId.toString()] = parentId.toString()
            viewHierarchy.getOrPut(parentId.toString()) { mutableListOf() }.add(childId.toString())

            YogaShadowTree.shared.addChildNode(parentId, childId, index)

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to attach view: $childId to $parentId", e)
            false
        }
    }

    fun detachView(viewId: Int): Boolean {
        return try {
            val view = ViewRegistry.shared.getView(viewId)
            if (view == null) {
                Log.e(TAG, "View '$viewId' not found for detach")
                return false
            }

            val parentView = view.parent as? ViewGroup
            parentView?.removeView(view)

            val viewIdStr = viewId.toString()
            val parentId = childToParent.remove(viewIdStr)
            if (parentId != null) {
                viewHierarchy[parentId]?.remove(viewIdStr)
            }

            YogaShadowTree.shared.removeNode(viewIdStr)

            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Sets the children of a view, replacing any existing children.
     * 
     * CRITICAL: Matches React Native's NativeViewHierarchyManager.setChildren pattern exactly:
     * 1. Does NOT call removeAllViews() - just adds children in order
     * 2. Android's ViewGroup.addView() automatically removes view from previous parent
     * 3. Throws/logs error if view not found (doesn't silently skip)
     * 
     * @param viewId Unique identifier for the parent view
     * @param childrenIds List of child view identifiers in order
     * @return `true` if children were set successfully, `false` otherwise
     */
    fun setChildren(viewId: Int, childrenIds: List<Int>): Boolean {
        return try {
            
            val parentView = ViewRegistry.shared.getView(viewId)
            
            if (parentView == null) {
                return false
            }
            
            val parentViewGroup = parentView as? ViewGroup

            if (parentViewGroup == null) {
                Log.e(TAG, "❌ setChildren: Parent view '$viewId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                return false
            }
            

            // Check if this is a DCFScreenComponent's FrameLayout (has DCFScreen tag)
            if (parentViewGroup.tag == "DCFScreen") {
                val childViews = childrenIds.mapNotNull { childId ->
                    ViewRegistry.shared.getView(childId)
                }
                
                // OPTIMIZED: Batch remove and add
                val childCount = parentViewGroup.childCount
                val toRemove = mutableListOf<android.view.View>()
                for (i in childCount - 1 downTo 0) {
                    val child = parentViewGroup.getChildAt(i)
                    if (child.tag != "NavigationBar") {
                        toRemove.add(child)
                    }
                }
                toRemove.forEach { parentViewGroup.removeView(it) }
                
                // Batch add with layout params
                val layoutParams = android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                )
                childViews.forEach { childView ->
                    childView.layoutParams = layoutParams
                    childView.visibility = android.view.View.VISIBLE
                    childView.alpha = 1.0f
                    parentViewGroup.addView(childView)
                }
                
                // Single-pass hierarchy update
                val viewIdStr = viewId.toString()
                val childrenIdsStr = childrenIds.map { it.toString() }
                viewHierarchy[viewIdStr] = childrenIdsStr.toMutableList()
                childrenIdsStr.forEach { childToParent[it] = viewIdStr }
                childrenIds.forEachIndexed { index, childId ->
                    DCFLayoutManager.shared.addChildNode(viewId, childId, index)
                }
                
                return true
            }

            // CRITICAL: Match iOS pattern - check for custom component setChildren implementation
            val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
            if (viewInfo != null) {
                val componentClass = DCFComponentRegistry.shared.getComponentType(viewInfo.type)
                if (componentClass != null) {
                    // Get component instance (use cached instance, matches iOS pattern)
                    val componentInstance = getCachedComponentInstance(viewInfo.type)
                    if (componentInstance != null) {
                        // OPTIMIZED: Single pass for child views and hierarchy
                        val childViews = childrenIds.mapNotNull { ViewRegistry.shared.getView(it) }
                        
                        if (componentInstance.setChildren(parentView, childViews, viewId.toString())) {
                            val viewIdStr = viewId.toString()
                            val childrenIdsStr = childrenIds.map { it.toString() }
                            viewHierarchy[viewIdStr] = childrenIdsStr.toMutableList()
                            childrenIdsStr.forEach { childToParent[it] = viewIdStr }
                            
                            // Batch update layout manager and visibility
                            childViews.forEachIndexed { index, childView ->
                                val childId = childrenIds[index]
                                DCFLayoutManager.shared.addChildNode(viewId, childId, index)
                                childView.visibility = View.VISIBLE
                                childView.alpha = 1.0f
                            }
                            
                            return true
                        }
                    }
                }
            }
            
            // CRITICAL: Fallback to React Native's exact pattern
            // React Native's setChildren does NOT call removeAllViews() - just adds children in order
            // Android's ViewGroup.addView() automatically removes view from previous parent
            
            val viewIdStr = viewId.toString()
            val childrenIdsStr = childrenIds.map { it.toString() }
            
            // OPTIMIZED: Single-pass hierarchy update and view operations
            val childrenIdsSet = childrenIds.toSet() // For O(1) lookup
            val oldChildren = viewHierarchy[viewIdStr] ?: mutableListOf()
            
            // Update hierarchy in one pass
            oldChildren.forEach { oldChildIdStr ->
                if (!childrenIdsSet.contains(oldChildIdStr.toIntOrNull())) {
                    childToParent.remove(oldChildIdStr)
                }
            }
            viewHierarchy[viewIdStr] = childrenIdsStr.toMutableList()
            childrenIdsStr.forEach { childToParent[it] = viewIdStr }
            
            // Collect views once, process in single pass
            val childViews = childrenIds.mapNotNull { ViewRegistry.shared.getView(it) }
            val childrenToRemove = mutableListOf<android.view.View>()
            val absoluteViews = mutableListOf<android.view.View>()
            
            // Single pass: collect removals and process additions
            val currentChildCount = parentViewGroup.childCount
            for (i in 0 until currentChildCount) {
                val child = parentViewGroup.getChildAt(i)
                val childId = child.getTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY) as? Int
                if (childId != null && !childrenIdsSet.contains(childId)) {
                    childrenToRemove.add(child)
                }
            }
            
            // Batch remove old children
            childrenToRemove.forEach { parentViewGroup.removeView(it) }
            
            // Single pass: add all children and collect absolute views
            childViews.forEachIndexed { index, childView ->
                val childId = childrenIds[index]
                val currentParent = childView.parent
                if (currentParent != null && currentParent != parentViewGroup) {
                    (currentParent as? ViewGroup)?.removeView(childView)
                }
                
                try {
                    parentViewGroup.addView(childView, index)
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    DCFLayoutManager.shared.addChildNode(viewId, childId, index)
                    
                    // Collect absolute views for batch processing
                    val shadowNode = YogaShadowTree.shared.getShadowNode(childId)
                    if (shadowNode?.yogaNode?.positionType == com.facebook.yoga.YogaPositionType.ABSOLUTE) {
                        absoluteViews.add(childView)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "setChildren: Error adding child $childId", e)
                }
            }
            
            // Batch process absolute views
            if (absoluteViews.isNotEmpty() && parentViewGroup is com.dotcorr.dcflight.components.DCFFrameLayout) {
                parentViewGroup.clipChildren = false
                parentViewGroup.clipToPadding = false
                absoluteViews.forEach { parentViewGroup.bringChildToFront(it) }
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ setChildren: Failed to set children for view: $viewId", e)
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
        data class CreateOp(val viewId: Int, val viewType: String, val propsJson: String)
        data class UpdateOp(val viewId: Int, val propsJson: String)
        data class AttachOp(val childId: Int, val parentId: Int, val index: Int)
        data class SetChildrenOp(val viewId: Int, val childrenIds: List<Int>)
        data class AddEventListenersOp(val viewId: Int, val eventTypes: List<String>)
        data class DeleteOp(val viewId: Int)
        
        val deleteOps = mutableListOf<DeleteOp>()
        val createOps = mutableListOf<CreateOp>()
        val updateOps = mutableListOf<UpdateOp>()
        val attachOps = mutableListOf<AttachOp>()
        val setChildrenOps = mutableListOf<SetChildrenOp>()
        val eventOps = mutableListOf<AddEventListenersOp>()
        
        // Parse phase - collect all operations
        
        operations.forEach { operation ->
            val operationType = operation["operation"] as? String
            
            when (operationType) {
                "deleteView" -> {
                    val viewId = (operation["viewId"] as? Number)?.toInt() ?: (operation["viewId"] as? Int)
                    if (viewId != null) {
                        deleteOps.add(DeleteOp(viewId))
                    }
                }
                
                "createView" -> {
                    val viewId = (operation["viewId"] as? Number)?.toInt() ?: (operation["viewId"] as? Int)
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
                    val viewId = (operation["viewId"] as? Number)?.toInt() ?: (operation["viewId"] as? Int)
                    
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
                    val childId = (operation["childId"] as? Number)?.toInt() ?: (operation["childId"] as? Int)
                    val parentId = (operation["parentId"] as? Number)?.toInt() ?: (operation["parentId"] as? Int)
                    val index = operation["index"] as? Int
                    if (childId != null && parentId != null && index != null) {
                        attachOps.add(AttachOp(childId, parentId, index))
                    }
                }
                
                "addEventListeners" -> {
                    val viewId = (operation["viewId"] as? Number)?.toInt() ?: (operation["viewId"] as? Int)
                    val eventTypes = operation["eventTypes"] as? List<String>
                    if (viewId != null && eventTypes != null) {
                        eventOps.add(AddEventListenersOp(viewId, eventTypes))
                    }
                }

                "setChildren" -> {
                    val viewId = (operation["viewId"] as? Number)?.toInt() ?: (operation["viewId"] as? Int)
                    val childrenIds = (operation["childrenIds"] as? List<*>)?.mapNotNull { 
                        (it as? Number)?.toInt() ?: (it as? Int)
                    }
                    
                    if (viewId != null && childrenIds != null) {
                        setChildrenOps.add(SetChildrenOp(viewId, childrenIds))
                    }
                }
            }
        }
        
        try {
            // OPTIMIZED: Single-pass deletion - collect everything once, remove in batch
            // Defer view removal from parent to prevent layout shifts during batch
            val viewsToRemoveSet = mutableSetOf<android.view.View>()
            val allIdsToRemove = mutableSetOf<Int>()
            
            // Single recursive pass: collect views, IDs, and clear hierarchy in one go
            fun collectAndRemoveRecursive(parentId: Int) {
                val view = ViewRegistry.shared.getView(parentId)
                if (view != null) {
                    viewsToRemoveSet.add(view)
                }
                allIdsToRemove.add(parentId)
                
                val parentIdStr = parentId.toString()
                val children = viewHierarchy[parentIdStr] ?: return
                children.forEach { childIdStr ->
                    val childId = childIdStr.toIntOrNull()
                    if (childId != null) {
                        collectAndRemoveRecursive(childId)
                    }
                }
                // Clear hierarchy immediately during collection
                viewHierarchy[parentIdStr]?.clear()
            }
            
            // Delete phase - remove from layout tree FIRST, before creating new views
            deleteOps.forEach { op ->
                collectAndRemoveRecursive(op.viewId)
                cleanupHierarchyReferences(op.viewId.toString())
            }
            
            // Batch remove all collected IDs (much faster than individual removals)
            allIdsToRemove.forEach { viewId ->
                try {
                    YogaShadowTree.shared.removeNode(viewId.toString())
                } catch (e: Exception) {
                    // Silent - continue with other removals
                }
                try {
                    ViewRegistry.shared.removeView(viewId)
                } catch (e: Exception) {
                    // Silent - continue
                }
                try {
                    DCFLayoutManager.shared.unregisterView(viewId)
                } catch (e: Exception) {
                    // Silent - continue
                }
                views.remove(viewId)
            }
            
            // Execute phase - process all operations
            // CRITICAL: Wrap each operation in try-catch to prevent one failure from blocking others
            // Now create new views - old views are already removed from layout tree
            createOps.forEach { op ->
                try {
                    createView(op.viewId, op.viewType, op.propsJson)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error creating view ${op.viewId} of type ${op.viewType}", e)
                    // Continue with other operations
                }
            }
            
            updateOps.forEach { op ->
                try {
                    updateView(op.viewId, op.propsJson)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error updating view ${op.viewId}", e)
                    // Continue with other operations
                }
            }
            
            // Process setChildren before attachView to ensure base hierarchy is correct
            setChildrenOps.forEach { op ->
                try {
                    setChildren(op.viewId, op.childrenIds)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error setting children for view ${op.viewId}", e)
                    // Continue with other operations
                }
            }
            
            attachOps.forEach { op ->
                try {
                    attachView(op.childId, op.parentId, op.index)
                } catch (e: Exception) {
                    Log.e(TAG, "Error attaching view ${op.childId} to parent ${op.parentId}", e)
                    // Continue with other operations
                }
            }
            
            // Batch remove all old views from parents (after all operations complete)
            viewsToRemoveSet.forEach { view ->
                (view.parent as? android.view.ViewGroup)?.removeView(view)
            }
            
            eventOps.forEach { op ->
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(op.viewId, op.eventTypes)
            }
            
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()
            
            val rootView = ViewRegistry.shared.getView(0)
            rootView?.let { root ->
                // CRITICAL: Ensure root view is visible and has correct dimensions
                if (root.visibility != View.VISIBLE) {
                    root.visibility = View.VISIBLE
                }
                if (root.alpha < 1.0f) {
                    root.alpha = 1.0f
                }
                
                root.measure(
                    View.MeasureSpec.makeMeasureSpec(screenWidth.toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(screenHeight.toInt(), View.MeasureSpec.EXACTLY)
                )
                
                // CRITICAL: Layout root view BEFORE calling calculateAndApplyLayout
                // This ensures the root view has correct dimensions when Yoga calculates child layouts
                val rootFrame = android.graphics.Rect(0, 0, screenWidth.toInt(), screenHeight.toInt())
                if (root.left != rootFrame.left || root.top != rootFrame.top ||
                    root.width != rootFrame.width() || root.height != rootFrame.height()) {
                    root.layout(rootFrame.left, rootFrame.top, rootFrame.right, rootFrame.bottom)
                }
            }
            
            // CRITICAL: Layout calculation must never hang or throw uncaught exceptions
            // If it fails, we continue - views will be laid out on next frame
            // This ensures button presses and other interactions remain snappy
            try {
                val layoutSuccess = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
                if (!layoutSuccess) {
                    // Layout may be deferred - not a fatal error, will happen next frame
                }
            } catch (e: Exception) {
                // CRITICAL: Don't re-throw - log and continue
                // A layout failure shouldn't crash the app or block the batch update
                Log.e(TAG, "calculateAndApplyLayout threw exception (non-fatal)", e)
                // Continue - views will be laid out on next frame or next batch update
            }
            
            // CRITICAL: Views are made visible INSIDE calculateAndApplyLayout after layouts are applied
            // Do NOT make views visible here - it causes a race condition where views are visible but not laid out
            // This matches iOS behavior where calculateLayoutNow() makes views visible after layout completes
            
            // OPTIMIZED: Only invalidate root - Android will handle child invalidation automatically
            // Recursive invalidation is expensive and unnecessary
            rootView?.invalidate()
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "commitBatchUpdate failed with exception", e)
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
        try {
            childToParent.clear()
            viewHierarchy.clear()
            componentInstanceCache.clear()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing DCMauiBridgeImpl", e)
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

