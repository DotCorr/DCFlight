/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.R
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree
import java.util.concurrent.ConcurrentHashMap

/**
 * Bridge between Dart and native Android code
 * Following iOS DCMauiBridgeImpl pattern - uses component registry, not hardcoded components
 */
class DCMauiBridgeImpl private constructor() {

    companion object {
        private const val TAG = "DCMauiBridgeImpl"

        @JvmField
        val shared = DCMauiBridgeImpl()
    }

    // View registry - stores all created views
    private val viewRegistry = ConcurrentHashMap<String, View>()

    // Track parent-child relationships for proper cleanup
    private val viewHierarchy = ConcurrentHashMap<String, MutableList<String>>()
    private val childToParent = ConcurrentHashMap<String, String>()

    // Application context
    private var appContext: Context? = null

    /**
     * Initialize the framework
     */
    fun initialize(context: Context): Boolean {
        Log.d(TAG, "Initializing DCMauiBridgeImpl")
        appContext = context.applicationContext

        // Check if root view exists
        val rootView = viewRegistry["root"]
        if (rootView != null) {
            Log.d(TAG, "Root view already exists")
            // Ensure the root view is registered with the shadow tree
            if (!YogaShadowTree.shared.hasNode("root")) {
                YogaShadowTree.shared.createNode("root", "View", emptyMap())
            }
        } else {
            Log.d(TAG, "Root view not found - will be registered later")
        }

        return true
    }

    /**
     * Register a pre-existing view with the bridge
     */
    fun registerView(view: View, viewId: String) {
        Log.d(TAG, "Registering view: $viewId")
        viewRegistry[viewId] = view
        view.setTag(R.id.dcf_view_id, viewId)

        // Register with layout manager
        DCFLayoutManager.shared.registerView(view, viewId)
    }

    /**
     * Create a view with properties using component registry
     */
    fun createView(viewId: String, viewType: String, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Creating view: $viewId of type: $viewType")

        if (viewRegistry.containsKey(viewId)) {
            Log.w(TAG, "View already exists: $viewId")
            return false
        }

        val context = appContext ?: getRootView()?.context
        if (context == null) {
            Log.e(TAG, "No context available for creating view")
            return false
        }

        // Use component registry to get the component type
        val componentInstance = DCFComponentRegistry.shared.createComponentInstance(viewType)
        if (componentInstance == null) {
            Log.e(TAG, "Component type not registered: $viewType")
            return false
        }

        // Create the view using the component
        val view = componentInstance.createView(context, props)

        // Set view properties
        view.id = View.generateViewId()
        view.setTag(R.id.dcf_view_id, viewId)
        view.setTag(R.id.dcf_component_type, viewType)

        // Register the view
        viewRegistry[viewId] = view

        // Add to parent if specified
        val parentId = props["parentId"] as? String
        if (parentId != null) {
            addToParent(view, parentId)
        }

        // Register with Yoga layout system
        YogaShadowTree.shared.createNode(viewId, viewType, props)

        // Register with layout manager
        DCFLayoutManager.shared.registerView(view, viewId)

        // Notify component that view is registered
        componentInstance.viewRegisteredWithShadowTree(view, viewId)

        Log.d(TAG, "Successfully created view: $viewId")
        return true
    }

    /**
     * Update a view's properties using component registry
     */
    fun updateView(viewId: String, props: Map<String, Any?>): Boolean {
        val view = viewRegistry[viewId]
        if (view == null) {
            Log.w(TAG, "View not found for update: $viewId")
            return false
        }

        val viewType = view.getTag(R.id.dcf_component_type) as? String ?: "View"

        Log.d(TAG, "Updating view: $viewId of type: $viewType")

        // Get component instance
        val componentInstance = DCFComponentRegistry.shared.createComponentInstance(viewType)
        if (componentInstance == null) {
            Log.e(TAG, "Component type not registered for update: $viewType")
            return false
        }

        // Update view using component
        val success = componentInstance.updateView(view, props)

        if (!success) {
            Log.e(TAG, "Failed to update view: $viewId")
            return false
        }

        // Update Yoga node
        YogaShadowTree.shared.updateNode(viewId, props)

        Log.d(TAG, "Successfully updated view: $viewId")
        return true
    }

    /**
     * Delete a view
     */
    fun deleteView(viewId: String): Boolean {
        val view = viewRegistry[viewId]
        if (view == null) {
            Log.w(TAG, "View not found for deletion: $viewId")
            return false
        }

        Log.d(TAG, "Deleting view: $viewId")

        // First, recursively delete all children
        deleteChildrenRecursively(viewId)

        // Remove from parent
        (view.parent as? ViewGroup)?.removeView(view)

        // Remove from registries
        viewRegistry.remove(viewId)

        // Clean up hierarchy tracking
        cleanupHierarchyReferences(viewId)

        // Remove from Yoga tree
        YogaShadowTree.shared.removeNode(viewId)

        // Remove from layout manager
        DCFLayoutManager.shared.unregisterView(viewId)

        Log.d(TAG, "Successfully deleted view: $viewId")
        return true
    }

    /**
     * Attach a child view to a parent view
     */
    fun attachView(childId: String, parentId: String, index: Int): Boolean {
        Log.d(TAG, "Attaching view: $childId to parent: $parentId at index: $index")

        val childView = viewRegistry[childId]
        val parentView = viewRegistry[parentId] as? ViewGroup

        if (childView == null || parentView == null) {
            Log.e(TAG, "Cannot attach - child or parent not found")
            return false
        }

        // Remove from current parent if exists
        (childView.parent as? ViewGroup)?.removeView(childView)

        // Add to new parent
        if (index >= 0 && index < parentView.childCount) {
            parentView.addView(childView, index)
        } else {
            parentView.addView(childView)
        }

        // Update hierarchy tracking
        if (!viewHierarchy.containsKey(parentId)) {
            viewHierarchy[parentId] = mutableListOf()
        }

        // Remove from old parent's children list
        childToParent[childId]?.let { oldParentId ->
            viewHierarchy[oldParentId]?.remove(childId)
        }

        // Add to new parent's children list
        if (!viewHierarchy[parentId]!!.contains(childId)) {
            viewHierarchy[parentId]!!.add(childId)
        }

        childToParent[childId] = parentId

        // Update Yoga tree
        YogaShadowTree.shared.addChildNode(parentId, childId, index)

        Log.d(TAG, "Successfully attached view: $childId to parent: $parentId")
        return true
    }

    /**
     * Detach a view from its parent
     */
    fun detachView(childId: String): Boolean {
        Log.d(TAG, "Detaching view: $childId")

        val childView = viewRegistry[childId]
        if (childView == null) {
            Log.w(TAG, "View not found for detachment: $childId")
            return false
        }

        // Remove view from its parent
        (childView.parent as? ViewGroup)?.removeView(childView)

        // Update parent-child tracking
        childToParent[childId]?.let { parentId ->
            viewHierarchy[parentId]?.remove(childId)
        }
        childToParent.remove(childId)

        Log.d(TAG, "Successfully detached view: $childId")
        return true
    }

    /**
     * Set all children for a view
     */
    fun setChildren(viewId: String, childrenIds: List<String>): Boolean {
        Log.d(TAG, "Setting children for view: $viewId - children: $childrenIds")

        val parentView = viewRegistry[viewId] as? ViewGroup
        if (parentView == null) {
            Log.e(TAG, "Parent view not found or not a ViewGroup: $viewId")
            return false
        }

        // Remove all existing children from tracking that are not in new list
        val oldChildren = viewHierarchy[viewId] ?: mutableListOf()
        for (oldChildId in oldChildren) {
            if (!childrenIds.contains(oldChildId)) {
                childToParent.remove(oldChildId)
            }
        }

        // Reset children array
        viewHierarchy[viewId] = childrenIds.toMutableList()

        // Update child->parent mapping
        for (childId in childrenIds) {
            childToParent[childId] = viewId
        }

        // Remove all existing subviews
        parentView.removeAllViews()

        // Add children in order
        for ((index, childId) in childrenIds.withIndex()) {
            val childView = viewRegistry[childId]
            if (childView != null) {
                parentView.addView(childView)

                // Update shadow tree
                YogaShadowTree.shared.addChildNode(viewId, childId, index)
            } else {
                Log.w(TAG, "Child view not found: $childId")
            }
        }

        Log.d(TAG, "Successfully set children for view: $viewId")
        return true
    }

    /**
     * Handle batch updates
     */
    fun commitBatchUpdate(updates: List<Map<String, Any?>>): Boolean {
        Log.d(TAG, "Committing batch update with ${updates.size} operations")

        var allSucceeded = true

        for (update in updates) {
            val operation = update["operation"] as? String ?: continue

            when (operation) {
                "createView" -> {
                    val viewId = update["viewId"] as? String ?: continue
                    val viewType = update["viewType"] as? String ?: continue
                    val props = update["props"] as? Map<String, Any?> ?: emptyMap()

                    if (!createView(viewId, viewType, props)) {
                        allSucceeded = false
                    }
                }

                "updateView" -> {
                    val viewId = update["viewId"] as? String ?: continue
                    val props = update["props"] as? Map<String, Any?> ?: emptyMap()

                    if (!updateView(viewId, props)) {
                        allSucceeded = false
                    }
                }

                "deleteView" -> {
                    val viewId = update["viewId"] as? String ?: continue

                    if (!deleteView(viewId)) {
                        allSucceeded = false
                    }
                }

                "attachView" -> {
                    val childId = update["childId"] as? String ?: continue
                    val parentId = update["parentId"] as? String ?: continue
                    val index = update["index"] as? Int ?: -1

                    if (!attachView(childId, parentId, index)) {
                        allSucceeded = false
                    }
                }

                "detachView" -> {
                    val childId = update["childId"] as? String ?: continue

                    if (!detachView(childId)) {
                        allSucceeded = false
                    }
                }

                "setChildren" -> {
                    val viewId = update["viewId"] as? String ?: continue
                    val childrenIds = update["childrenIds"] as? List<String> ?: emptyList()

                    if (!setChildren(viewId, childrenIds)) {
                        allSucceeded = false
                    }
                }
            }
        }

        Log.d(TAG, "Batch update completed - success: $allSucceeded")
        return allSucceeded
    }

    /**
     * Get a view by ID
     */
    fun getView(viewId: String): View? {
        return viewRegistry[viewId]
    }

    /**
     * Get root view
     */
    fun getRootView(): View? {
        return viewRegistry["root"]
    }

    /**
     * Clean up for hot restart
     */
    fun cleanupForHotRestart() {
        Log.d(TAG, "Cleaning up for hot restart")

        // Remove all non-root views
        val nonRootViews = viewRegistry.filterKeys { it != "root" }
        for ((viewId, view) in nonRootViews) {
            (view.parent as? ViewGroup)?.removeView(view)
            viewRegistry.remove(viewId)
        }

        // Clear root view's children but preserve root
        val rootView = viewRegistry["root"] as? ViewGroup
        rootView?.removeAllViews()

        // Clear hierarchy tracking except for root
        viewHierarchy.clear()
        viewHierarchy["root"] = mutableListOf()
        childToParent.clear()

        Log.d(TAG, "Hot restart cleanup complete")
    }

    // Private helper methods

    private fun addToParent(view: View, parentId: String) {
        val parent = viewRegistry[parentId] as? ViewGroup
        if (parent != null) {
            parent.addView(view)
        } else {
            Log.w(TAG, "Parent not found or not a ViewGroup: $parentId")
        }
    }

    private fun deleteChildrenRecursively(parentId: String) {
        val children = viewHierarchy[parentId] ?: return

        // Make a copy to avoid modification during iteration
        val childrenCopy = children.toList()

        for (childId in childrenCopy) {
            // Recursively delete grandchildren first
            deleteChildrenRecursively(childId)

            // Now delete the child view
            val childView = viewRegistry[childId]
            if (childView != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)

                // Remove from registries
                viewRegistry.remove(childId)
                YogaShadowTree.shared.removeNode(childId)
                DCFLayoutManager.shared.unregisterView(childId)
            }

            // Update tracking
            childToParent.remove(childId)
        }

        // Clear the children array for this parent
        viewHierarchy[parentId]?.clear()
    }

    private fun cleanupHierarchyReferences(viewId: String) {
        // Remove from parent's children list
        childToParent[viewId]?.let { parentId ->
            viewHierarchy[parentId]?.remove(viewId)
        }

        // Remove from child->parent mapping
        childToParent.remove(viewId)

        // Remove from parent->children mapping
        viewHierarchy.remove(viewId)
    }

    /**
     * Get children IDs for a view
     */
    fun getChildrenIds(viewId: String): List<String> {
        return viewHierarchy[viewId] ?: emptyList()
    }

    /**
     * Get parent ID for a view
     */
    fun getParentId(childId: String): String? {
        return childToParent[childId]
    }

    /**
     * Print hierarchy for debugging
     */
    fun printHierarchy() {
        Log.d(TAG, "View Hierarchy:")
        for ((parentId, childrenIds) in viewHierarchy) {
            Log.d(TAG, "  $parentId -> $childrenIds")
        }
    }

    /**
     * Cleanup all resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiBridgeImpl")

        // Clear all views
        viewRegistry.clear()
        viewHierarchy.clear()
        childToParent.clear()

        // Clear context
        appContext = null

        Log.d(TAG, "DCMauiBridgeImpl cleanup complete")
    }
}
