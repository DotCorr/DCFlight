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
                    Log.d(TAG, "✅ createView: Root view (0) made visible immediately")
                } else {
                    // Non-root views start invisible - will be made visible after layout
                    Log.d(TAG, "🔍 createView: Non-root view (viewId=$viewId) starts invisible, will be made visible after layout")
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
                        Log.d(TAG, "🔍 attachView: ScrollContentView already attached, skipping insertContentView")
                        // Still add to Yoga tree if not already added
                        childToParent[childId.toString()] = parentId.toString()
                        viewHierarchy.getOrPut(parentId.toString()) { mutableListOf() }.add(childId.toString())
                        YogaShadowTree.shared.addChildNode(parentId, childId, index)
                        return true
                    }
                    
                    Log.d(TAG, "🔍 attachView: Detected ScrollContentView being attached to ScrollView, using insertContentView")
                    
                    // Remove from existing parent before attaching
                    if (childView.parent != null) {
                        (childView.parent as? ViewGroup)?.removeView(childView)
                        Log.d(TAG, "Removed child '$childId' from existing parent")
                    }
                    
                    scrollView.insertContentView(childView)
                    
                    // CRITICAL: Make view visible immediately when attached (matches React Native)
                    val wasInvisible = childView.visibility != View.VISIBLE || childView.alpha < 1.0f
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    
                    // Add to Yoga tree for layout
                    childToParent[childId.toString()] = parentId.toString()
                    viewHierarchy.getOrPut(parentId.toString()) { mutableListOf() }.add(childId.toString())
                    YogaShadowTree.shared.addChildNode(parentId, childId, index)
                    
                    if (wasInvisible) {
                        Log.d(TAG, "✅ attachView: ScrollContentView attached via insertContentView, made visible (was invisible)")
                    } else {
                        Log.d(TAG, "✅ attachView: ScrollContentView attached via insertContentView (already visible)")
                    }
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
                    Log.d(TAG, "Content container provider detected: attaching to content container")
                }
            }

            if (childView.parent != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                Log.d(TAG, "Removed child '$childId' from existing parent")
            }

                try {
                    if (index >= 0 && index <= actualParent.childCount) {
                        actualParent.addView(childView, index)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at index $index")
                    } else {
                        actualParent.addView(childView)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at end")
                    }
                    
                    // CRITICAL: DON'T make view visible here - wait until layout is applied
                    // This prevents flash of incorrect layout (views at 0,0,0,0 before layout)
                    // Views will be made visible in applyLayout after correct frame is set
                    val wasInvisible = childView.visibility != View.VISIBLE || childView.alpha < 1.0f
                    // Keep view invisible until layout is applied
                    if (childId != 0) { // Root view (0) is always visible
                        childView.visibility = View.INVISIBLE
                        childView.alpha = 1.0f // Keep alpha at 1.0 so fade-in works when made visible
                    }
                    
                    if (wasInvisible) {
                        Log.d(TAG, "✅ attachView: Successfully attached child '$childId' to parent '$parentId' (kept invisible until layout)")
                    } else {
                        Log.d(TAG, "✅ attachView: Successfully attached child '$childId' to parent '$parentId' (already visible)")
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
            Log.d(TAG, "🔍 setChildren: START for viewId=$viewId, childrenIds=$childrenIds")
            
            val parentView = ViewRegistry.shared.getView(viewId)
            
            if (parentView == null) {
                Log.w(TAG, "❌ setChildren: parent view '$viewId' not found in registry (likely pending batch creation)")
                return false
            }
            
            val parentViewGroup = parentView as? ViewGroup

            if (parentViewGroup == null) {
                Log.e(TAG, "❌ setChildren: Parent view '$viewId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                return false
            }
            
            Log.d(TAG, "   Parent view type: ${parentView.javaClass.simpleName}, current childCount: ${parentViewGroup.childCount}")

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
                val viewIdStr = viewId.toString()
                viewHierarchy[viewIdStr]?.clear()
                childrenIds.forEach { childId ->
                    val childIdStr = childId.toString()
                    childToParent[childIdStr] = viewIdStr
                    viewHierarchy.getOrPut(viewIdStr) { mutableListOf() }.add(childIdStr)
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = childrenIds.indexOf(childId))
                }
                
                Log.d(TAG, "✅ Added ${childViews.size} children to DCFScreen: $viewId")
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
                        // CRITICAL: Match React Native - verify ALL children exist before proceeding
                        // React Native throws exception if view not found, we log error but continue
                        val missingChildren = childrenIds.filter { ViewRegistry.shared.getView(it) == null }
                        if (missingChildren.isNotEmpty()) {
                            Log.e(TAG, "❌ setChildren: Missing child views: $missingChildren (component: ${viewInfo.type})")
                            // Don't return false - let component.handleChildren handle it or fall through to fallback
                        }
                        
                        // Get child views (filtered - only registered views, matches iOS compactMap pattern)
                        val childViews = childrenIds.mapNotNull { ViewRegistry.shared.getView(it) }
                        
                        Log.d(TAG, "🔍 setChildren: Component '${viewInfo.type}' has custom setChildren, routing ${childViews.size} children (requested ${childrenIds.size})")
                        
                        // Call component's setChildren if it exists (matches iOS pattern)
                        if (componentInstance.setChildren(parentView, childViews, viewId.toString())) {
                            Log.d(TAG, "✅ setChildren: Component '${viewInfo.type}' handled children routing")
                            
                            // CRITICAL: Use ORIGINAL childrenIds for hierarchy tracking (matches iOS)
                            // This ensures all children are tracked, even if not yet registered
                            val viewIdStr = viewId.toString()
                            val childrenIdsStr = childrenIds.map { it.toString() }
                            viewHierarchy[viewIdStr] = childrenIdsStr.toMutableList()
                            for (childIdStr in childrenIdsStr) {
                                childToParent[childIdStr] = viewIdStr
                            }
                            
                            // Update layout manager for registered children only
                            for ((index, childId) in childrenIds.withIndex()) {
                                if (ViewRegistry.shared.getView(childId) != null) {
                                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = index)
                                }
                            }
                            
                            // CRITICAL: Make all child views visible (matches iOS pattern)
                            childViews.forEach { childView ->
                                childView.visibility = View.VISIBLE
                                childView.alpha = 1.0f
                            }
                            
                            Log.d(TAG, "✅ setChildren: Component handled successfully for viewId=$viewId")
                            return true
                        } else {
                            Log.d(TAG, "❌ setChildren: Component '${viewInfo.type}' setChildren returned false, falling back to normal")
                        }
                    }
                }
            }
            
            // CRITICAL: Fallback to React Native's exact pattern
            // React Native's setChildren does NOT call removeAllViews() - just adds children in order
            // Android's ViewGroup.addView() automatically removes view from previous parent
            Log.d(TAG, "⚠️ setChildren: Using React Native pattern (no removeAllViews) for viewId=$viewId")
            
            val viewIdStr = viewId.toString()
            val childrenIdsStr = childrenIds.map { it.toString() }
            
            // Update hierarchy tracking (matches React Native's internal tracking)
            val oldChildren = viewHierarchy[viewIdStr] ?: mutableListOf()
            for (oldChildIdStr in oldChildren) {
                if (!childrenIdsStr.contains(oldChildIdStr)) {
                    childToParent.remove(oldChildIdStr)
                    Log.d(TAG, "   Removed old child from hierarchy: $oldChildIdStr")
                }
            }
            
            viewHierarchy[viewIdStr] = childrenIdsStr.toMutableList()
            for (childIdStr in childrenIdsStr) {
                    childToParent[childIdStr] = viewIdStr
            }
            
            // CRITICAL: Match React Native exactly - do NOT call removeAllViews()
            // Just add children in order - Android's addView() handles parent removal automatically
            // This is the key difference from our previous implementation!
            var addedCount = 0
            var skippedCount = 0
            for ((index, childId) in childrenIds.withIndex()) {
                val childView = ViewRegistry.shared.getView(childId)
                if (childView == null) {
                    // CRITICAL: React Native throws exception here, we log error but continue
                    Log.e(TAG, "❌ setChildren: Child view '$childId' not found at index $index (React Native would throw)")
                    skippedCount++
                    continue
                }
                
                // CRITICAL: Check if view already has a parent
                val currentParent = childView.parent
                if (currentParent != null && currentParent != parentViewGroup) {
                    Log.d(TAG, "   Child $childId already has parent ${currentParent.javaClass.simpleName}, will be moved")
                    (currentParent as? ViewGroup)?.removeView(childView)
                }
                
                // CRITICAL: Match React Native - just call addView at index
                // Android will automatically handle reordering if view is already a child
                try {
                    parentViewGroup.addView(childView, index)
                    Log.d(TAG, "   ✅ Added child $childId at index $index")
                    
                    // CRITICAL: Make child view visible immediately (matches React Native pattern)
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = index)
                    addedCount++
                } catch (e: Exception) {
                    Log.e(TAG, "❌ setChildren: Error adding child $childId at index $index", e)
                    skippedCount++
                }
            }
            
            // CRITICAL: Remove any children that are no longer in the list
            // React Native doesn't do this explicitly, but we need to for correctness
            val currentChildCount = parentViewGroup.childCount
            val childrenToRemove = mutableListOf<android.view.View>()
            for (i in 0 until currentChildCount) {
                val child = parentViewGroup.getChildAt(i)
                val childId = child.id
                if (childId != 0 && !childrenIds.contains(childId)) {
                    childrenToRemove.add(child)
                }
            }
            for (child in childrenToRemove) {
                parentViewGroup.removeView(child)
                Log.d(TAG, "   Removed child ${child.id} (no longer in children list)")
            }
            
            Log.d(TAG, "✅ setChildren: COMPLETE for viewId=$viewId - added: $addedCount, skipped: $skippedCount, removed: ${childrenToRemove.size}")
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
        Log.e(TAG, "🔥🔥🔥 commitBatchUpdate: ENTRY POINT - ${operations.size} operations")
        Log.e(TAG, "🔥🔥🔥 commitBatchUpdate: Thread=${Thread.currentThread().name}, isMainThread=${Looper.getMainLooper().thread == Thread.currentThread()}")
        
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
                        Log.d(TAG, "🗑️ ANDROID_BATCH: Parsed deleteView operation for viewId: $viewId")
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
            Log.d(TAG, "📊 ANDROID_BATCH: Processing batch - deletes: ${deleteOps.size}, creates: ${createOps.size}, updates: ${updateOps.size}, setChildren: ${setChildrenOps.size}, attaches: ${attachOps.size}")
            
            // 🔧 FIX: Delete views FIRST but defer view removal from parent to prevent layout shifts
            // We remove from registry/layout tree but keep views in hierarchy until creates are done
            val viewsToRemove = mutableListOf<android.view.View>()
            
            // Collect all views to remove (parent + children) without removing from parent yet
            fun collectViewsToRemove(parentId: Int) {
                val view = ViewRegistry.shared.getView(parentId)
                if (view != null) {
                    viewsToRemove.add(view)
                }
                val parentIdStr = parentId.toString()
                val children = viewHierarchy[parentIdStr] ?: return
                children.forEach { childIdStr ->
                    val childId = childIdStr.toIntOrNull()
                    if (childId != null) {
                        collectViewsToRemove(childId)
                    }
                }
            }
            
            // 🔧 FIX: Delete phase - remove from layout tree FIRST, before creating new views
            // This prevents both old and new views from being in the layout tree simultaneously,
            // which causes the "imaginary margin" / layout shift issue
            deleteOps.forEach { op ->
                Log.d(TAG, "🗑️ ANDROID_BATCH: Processing delete for viewId=${op.viewId}")
                collectViewsToRemove(op.viewId)
                
                // 🔧 CRITICAL: Remove from layout tree FIRST (before creates)
                // This ensures old view is not in layout tree when new view is added
                Log.d(TAG, "🗑️ ANDROID_BATCH: Removing viewId=${op.viewId} from layout tree (BEFORE creates)")
                YogaShadowTree.shared.removeNode(op.viewId.toString())
                
                // Remove from registry (but keep in hierarchy for now)
                ViewRegistry.shared.removeView(op.viewId)
                DCFLayoutManager.shared.unregisterView(op.viewId)
                views.remove(op.viewId)
                
                // Clean up tracking recursively
                fun cleanupTrackingRecursively(parentId: Int) {
                    val parentIdStr = parentId.toString()
                    val children = viewHierarchy[parentIdStr] ?: return
                    children.forEach { childIdStr ->
                        val childId = childIdStr.toIntOrNull()
                        if (childId != null) {
                            // Remove child from layout tree too
                            YogaShadowTree.shared.removeNode(childIdStr)
                            ViewRegistry.shared.removeView(childId)
                            DCFLayoutManager.shared.unregisterView(childId)
                            cleanupTrackingRecursively(childId)
                        }
                    }
                    viewHierarchy[parentIdStr]?.clear()
                }
                cleanupTrackingRecursively(op.viewId)
                cleanupHierarchyReferences(op.viewId.toString())
            }
            
            if (deleteOps.isNotEmpty()) {
                Log.d(TAG, "🗑️ ANDROID_BATCH: Delete phase completed - ${deleteOps.size} views removed from layout tree and registry")
            }
            
            // Execute phase - process all operations
            // Now create new views - old views are already removed from layout tree
            createOps.forEach { op ->
                createView(op.viewId, op.viewType, op.propsJson)
            }
            
            updateOps.forEach { op ->
                updateView(op.viewId, op.propsJson)
            }
            
            // Process setChildren before attachView to ensure base hierarchy is correct
            setChildrenOps.forEach { op ->
                setChildren(op.viewId, op.childrenIds)
            }
            
            attachOps.forEach { op ->
                Log.d(TAG, "🔍 BATCH_COMMIT: Attaching viewId=${op.childId} to parentId=${op.parentId} at index=${op.index}")
                val success = attachView(op.childId, op.parentId, op.index)
                Log.d(TAG, "   ✅ attachView result: $success")
                val childView = ViewRegistry.shared.getView(op.childId)
                val parentView = ViewRegistry.shared.getView(op.parentId)
                Log.d(TAG, "   After attach: child exists=${childView != null}, hasParent=${childView?.parent != null}, parent exists=${parentView != null}, parent childCount=${(parentView as? ViewGroup)?.childCount}")
            }
            
            // 🔧 FIX: Finally remove ALL old views from parent AFTER layout tree removal
            // This ensures layout is stable before removing from hierarchy
            if (viewsToRemove.isNotEmpty()) {
                Log.d(TAG, "🗑️ ANDROID_BATCH: Removing ${viewsToRemove.size} old views from parent (after layout tree removal)")
                viewsToRemove.forEach { view ->
                    val parentView = view.parent as? android.view.ViewGroup
                    parentView?.removeView(view)
                    Log.d(TAG, "✅ ANDROID_BATCH: View removed from parent")
                }
                Log.d(TAG, "✅ ANDROID_BATCH: All ${viewsToRemove.size} old views removed from parent")
            }
            
            eventOps.forEach { op ->
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(op.viewId, op.eventTypes)
            }
            
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()
            
            Log.d(TAG, "🎯 BATCH_COMMIT: Starting layout calculation - screen size: ${screenWidth}x${screenHeight}")
            
            // DEBUG: Log view registry state
            val allViewIds = ViewRegistry.shared.allViewIds
            Log.d(TAG, "🎯 BATCH_COMMIT: ViewRegistry has ${allViewIds.size} views: $allViewIds")
            
            val rootView = ViewRegistry.shared.getView(0)
            rootView?.let { root ->
                Log.d(TAG, "🎯 BATCH_COMMIT: Root view found, measuring...")
                Log.d(TAG, "🎯 BATCH_COMMIT: Root view current state: left=${root.left}, top=${root.top}, width=${root.width}, height=${root.height}, visibility=${root.visibility}, alpha=${root.alpha}")
                Log.d(TAG, "🎯 BATCH_COMMIT: Root view attached to window: ${root.isAttachedToWindow}, hasParent=${root.parent != null}, parentType=${root.parent?.javaClass?.simpleName}")
                Log.d(TAG, "🎯 BATCH_COMMIT: Root view rootView: ${root.rootView != null}, rootViewType=${root.rootView?.javaClass?.simpleName}")
                
                // CRITICAL: Ensure root view is visible and has correct dimensions
                if (root.visibility != View.VISIBLE) {
                    Log.w(TAG, "⚠️ BATCH_COMMIT: Root view is not VISIBLE! Setting to VISIBLE...")
                    root.visibility = View.VISIBLE
                }
                if (root.alpha < 1.0f) {
                    Log.w(TAG, "⚠️ BATCH_COMMIT: Root view alpha is ${root.alpha}! Setting to 1.0...")
                    root.alpha = 1.0f
                }
                
                root.measure(
                    View.MeasureSpec.makeMeasureSpec(screenWidth.toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(screenHeight.toInt(), View.MeasureSpec.EXACTLY)
                )
                Log.d(TAG, "🎯 BATCH_COMMIT: Root view measured: (${root.measuredWidth}, ${root.measuredHeight})")
                
                // CRITICAL: Layout root view BEFORE calling calculateAndApplyLayout
                // This ensures the root view has correct dimensions when Yoga calculates child layouts
                val rootFrame = android.graphics.Rect(0, 0, screenWidth.toInt(), screenHeight.toInt())
                if (root.left != rootFrame.left || root.top != rootFrame.top ||
                    root.width != rootFrame.width() || root.height != rootFrame.height()) {
                    root.layout(rootFrame.left, rootFrame.top, rootFrame.right, rootFrame.bottom)
                    Log.d(TAG, "🎯 BATCH_COMMIT: Root view laid out to: (${root.left}, ${root.top}, ${root.width}, ${root.height})")
                } else {
                    Log.d(TAG, "🎯 BATCH_COMMIT: Root view already has correct layout: (${root.left}, ${root.top}, ${root.width}, ${root.height})")
                }
            } ?: Log.e(TAG, "🎯 BATCH_COMMIT: Root view (0) not found!")
            
            // DEBUG: Log Yoga shadow tree state before layout
            val rootShadowNode = YogaShadowTree.shared.getShadowNode(0)
            Log.d(TAG, "🎯 BATCH_COMMIT: Root shadow node exists: ${rootShadowNode != null}")
            rootShadowNode?.let {
                Log.d(TAG, "🎯 BATCH_COMMIT: Root shadow node frame: ${it.frame}")
                Log.d(TAG, "🎯 BATCH_COMMIT: Root shadow node availableSize: ${it.availableSize}")
            }
            
            Log.d(TAG, "🎯 BATCH_COMMIT: Calling calculateAndApplyLayout...")
            Log.d(TAG, "🎯 BATCH_COMMIT: Before layout - checking all views:")
            ViewRegistry.shared.allViewIds.forEach { viewId ->
                    val view = ViewRegistry.shared.getView(viewId)
                Log.d(TAG, "   viewId=$viewId: exists=${view != null}, hasParent=${view?.parent != null}, visibility=${view?.visibility}, alpha=${view?.alpha}, frame=(${view?.left}, ${view?.top}, ${view?.width}, ${view?.height})")
            }
            
            // CRITICAL DEBUG: Check if root view exists and is attached
            val rootViewBeforeLayout = ViewRegistry.shared.getView(0)
            Log.d(TAG, "🎯 BATCH_COMMIT: Root view before layout: exists=${rootViewBeforeLayout != null}, attached=${rootViewBeforeLayout?.isAttachedToWindow}, dimensions=${rootViewBeforeLayout?.width}x${rootViewBeforeLayout?.height}")
            
            // CRITICAL DEBUG: Check Yoga shadow tree state
            val rootShadowNodeBeforeLayout = YogaShadowTree.shared.getShadowNode(0)
            Log.d(TAG, "🎯 BATCH_COMMIT: Root shadow node before layout: exists=${rootShadowNodeBeforeLayout != null}, frame=${rootShadowNodeBeforeLayout?.frame}, availableSize=${rootShadowNodeBeforeLayout?.availableSize}")
            
            // CRITICAL DEBUG: Check if layout calculation is blocked
            Log.d(TAG, "🎯 BATCH_COMMIT: About to call calculateAndApplyLayout - screenWidth=$screenWidth, screenHeight=$screenHeight")
            Log.d(TAG, "🎯 BATCH_COMMIT: Stack trace:")
            Thread.currentThread().stackTrace.take(10).forEach { 
                Log.d(TAG, "   at ${it.className}.${it.methodName}(${it.fileName}:${it.lineNumber})")
            }
            
            try {
                Log.d(TAG, "🎯 BATCH_COMMIT: CALLING calculateAndApplyLayout NOW...")
                val layoutSuccess = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
                Log.d(TAG, "🎯 BATCH_COMMIT: calculateAndApplyLayout returned: $layoutSuccess")
                Log.d(TAG, "🎯 BATCH_COMMIT: After layout - checking all views:")
                ViewRegistry.shared.allViewIds.forEach { viewId ->
                    val view = ViewRegistry.shared.getView(viewId)
                    Log.d(TAG, "   viewId=$viewId: exists=${view != null}, hasParent=${view?.parent != null}, visibility=${view?.visibility}, alpha=${view?.alpha}, frame=(${view?.left}, ${view?.top}, ${view?.width}, ${view?.height})")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ BATCH_COMMIT: calculateAndApplyLayout threw exception!", e)
                e.printStackTrace()
                throw e // Re-throw to prevent silent failure
            }
            
            // CRITICAL: Views are made visible INSIDE calculateAndApplyLayout after layouts are applied
            // Do NOT make views visible here - it causes a race condition where views are visible but not laid out
            // This matches iOS behavior where calculateLayoutNow() makes views visible after layout completes
            
            // Invalidate all views to ensure they redraw with new layouts
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
                Log.d(TAG, "🎯 BATCH_COMMIT: Invalidated all views for redraw")
            }
            
            Log.e(TAG, "🔥🔥🔥 commitBatchUpdate: SUCCESS - returning true")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "❌❌❌ commitBatchUpdate: FAILED with exception", e)
            e.printStackTrace()
            Log.e(TAG, "❌❌❌ Exception type: ${e.javaClass.name}")
            Log.e(TAG, "❌❌❌ Exception message: ${e.message}")
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

