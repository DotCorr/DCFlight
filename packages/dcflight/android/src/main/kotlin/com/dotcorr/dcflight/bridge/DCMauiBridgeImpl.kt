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
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/**
 * CRITICAL FIX: Bridge between Dart and native Android code
 * Now matches iOS DCMauiBridgeImpl method signatures EXACTLY
 */
class DCMauiBridgeImpl private constructor() {

    companion object {
        private const val TAG = "DCMauiBridgeImpl"

        @JvmField
        val shared = DCMauiBridgeImpl()
    }

    // CRITICAL FIX: Match iOS property names exactly
    internal val views = ConcurrentHashMap<String, View>()

    // Track parent-child relationships for proper cleanup
    private val viewHierarchy = ConcurrentHashMap<String, MutableList<String>>()
    private val childToParent = ConcurrentHashMap<String, String>()

    // Application context
    private var appContext: Context? = null

    /**
     * Register a pre-existing view with the bridge - EXACT iOS signature
     */
    fun registerView(view: View, withId viewId: String) {
        Log.d(TAG, "Registering view: $viewId")
        views[viewId] = view
        // Set view tag for identification
        view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, viewId)

        // Register with layout manager like iOS
        DCFLayoutManager.shared.registerView(view, viewId)
    }

    /**
     * Initialize the framework - EXACT iOS signature
     */
    fun initialize(): Boolean {
        Log.d(TAG, "Initializing DCMauiBridgeImpl")

        // Check if root view exists already like iOS
        val rootView = views["root"]
        if (rootView != null) {
            Log.d(TAG, "Root view already exists")
            // Ensure the root view is registered with the shadow tree
            if (!YogaShadowTree.shared.hasNode("root")) {
                YogaShadowTree.shared.createNode("root", "View")
            }
        } else {
            Log.d(TAG, "Root view not found - will be registered later")
        }

        return true
    }

    /**
     * CRITICAL FIX: Create a view with JSON props - EXACT iOS signature
     */
    fun createView(viewId: String, viewType: String, propsJson: String): Boolean {
        Log.d(TAG, "Creating view: $viewId of type: $viewType")

        // CRITICAL FIX: Parse props JSON like iOS
        val props = try {
            val jsonObject = JSONObject(propsJson)
            jsonObject.toMap()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse props JSON", e)
            return false
        }

        val context = appContext ?: getRootView()?.context
        if (context == null) {
            Log.e(TAG, "No context available for creating view")
            return false
        }

        // CRITICAL FIX: Detect if this is a screen component like iOS
        val isScreen = (viewType == "Screen" || props["presentationStyle"] != null)

        Log.d(TAG, "Creating ${if (isScreen) "screen" else "component"} '$viewId' of type '$viewType'")

        // Get component type from registry
        val componentInstance = DCFComponentRegistry.shared.createComponentInstance(viewType)
        if (componentInstance == null) {
            Log.e(TAG, "Component type not registered: $viewType")
            return false
        }

        // Create the view using the component
        val view = componentInstance.createView(context, props)

        // Set view properties like iOS
        view.setTag(com.dotcorr.dcflight.R.id.dcf_view_id, viewId)
        view.setTag(com.dotcorr.dcflight.R.id.dcf_component_type, viewType)

        // Register the view
        views[viewId] = view

        // CRITICAL FIX: Handle screen vs regular component like iOS
        if (isScreen) {
            Log.d(TAG, "🖼️ Creating screen '$viewId' with presentation style")
            // Create screen as its own Yoga root
            YogaShadowTree.shared.createScreenRoot(viewId, viewType)
        } else {
            Log.d(TAG, "🧩 Creating regular component '$viewId' of type '$viewType'")
            // Regular components get added to the main Yoga tree
            YogaShadowTree.shared.createNode(viewId, viewType)
        }

        // Register with layout manager
        DCFLayoutManager.shared.registerView(view, viewId)

        // Notify component that view is registered
        componentInstance.viewRegisteredWithShadowTree(view, viewId)

        Log.d(TAG, "✅ Successfully created ${if (isScreen) "screen" else "component"} '$viewId'")
        return true
    }

    /**
     * CRITICAL FIX: Update a view with JSON props - EXACT iOS signature
     */
    fun updateView(viewId: String, propsJson: String): Boolean {
        val view = views[viewId]
        if (view == null) {
            Log.w(TAG, "View not found for update: $viewId")
            return false
        }

        // CRITICAL FIX: Parse props JSON like iOS
        val props = try {
            val jsonObject = JSONObject(propsJson)
            jsonObject.toMap()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse props JSON for update", e)
            return false
        }

        val viewType = view.getTag(com.dotcorr.dcflight.R.id.dcf_component_type) as? String ?: "View"

        Log.d(TAG, "🔄 Updating view: $viewId of type: $viewType")

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

        // CRITICAL FIX: Handle layout vs non-layout props like iOS
        val layoutProps = extractLayoutProps(props)
        if (layoutProps.isNotEmpty()) {
            val isScreen = YogaShadowTree.shared.isScreenRoot(viewId)

            if (isScreen) {
                Log.d(TAG, "📐 Updating layout props for screen root '$viewId'")
                YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
            } else {
                Log.d(TAG, "📐 Updating layout props for regular component '$viewId'")
                YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
            }
        }

        Log.d(TAG, "✅ Successfully updated view: $viewId")
        return true
    }

    /**
     * CRITICAL FIX: Set all children for a view with JSON - EXACT iOS signature
     */
    fun setChildren(viewId: String, childrenJson: String): Boolean {
        Log.d(TAG, "Setting children for view: $viewId")

        // CRITICAL FIX: Parse children JSON like iOS
        val childrenIds = try {
            val jsonArray = JSONArray(childrenJson)
            (0 until jsonArray.length()).map { jsonArray.getString(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse children JSON", e)
            return false
        }

        val parentView = views[viewId] as? ViewGroup
        if (parentView == null) {
            Log.e(TAG, "Parent view not found or not a ViewGroup: $viewId")
            return false
        }

        // Handle children normally for all components like iOS
        return setChildrenNormally(parentView, viewId, childrenIds)
    }

    /**
     * CRITICAL FIX: Handle children for normal (non-present) components like iOS
     */
    private fun setChildrenNormally(parentView: ViewGroup, viewId: String, childrenIds: List<String>): Boolean {
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
            val childView = views[childId]
            if (childView != null) {
                parentView.addView(childView, index)

                // Update shadow tree like iOS
                DCFLayoutManager.shared.addChildNode(viewId, childId, index)
            } else {
                Log.w(TAG, "Child view not found: $childId")
            }
        }

        return true
    }

    /**
     * Get children IDs for a view - iOS compatibility
     */
    fun getChildrenIds(viewId: String): List<String> {
        return viewHierarchy[viewId] ?: emptyList()
    }

    /**
     * Get parent ID for a view - iOS compatibility
     */
    fun getParentId(childId: String): String? {
        return childToParent[childId]
    }

    /**
     * Print hierarchy for debugging - iOS compatibility
     */
    fun printHierarchy() {
        Log.d(TAG, "View Hierarchy:")
        for ((parentId, childrenIds) in viewHierarchy) {
            Log.d(TAG, "  $parentId -> $childrenIds")
        }
    }

    /**
     * CRITICAL FIX: Extract layout properties like iOS
     */
    private fun extractLayoutProps(props: Map<String, Any?>): Map<String, Any?> {
        val layoutPropKeys = setOf(
            "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
            "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
            "marginHorizontal", "marginVertical",
            "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
            "paddingHorizontal", "paddingVertical",
            "left", "top", "right", "bottom", "position",
            "translateX", "translateY", "rotateInDegrees",
            "scale", "scaleX", "scaleY",
            "flexDirection", "justifyContent", "alignItems", "alignSelf", "alignContent",
            "flexWrap", "flex", "flexGrow", "flexShrink", "flexBasis",
            "display", "overflow", "direction", "borderWidth",
            "aspectRatio", "gap", "rowGap", "columnGap"
        )
        return props.filter { layoutPropKeys.contains(it.key) }
    }

    /**
     * Clean up all views except root view for hot restart - EXACT iOS pattern
     */
    fun cleanupForHotRestart() {
        Log.d(TAG, "Cleaning up for hot restart")

        // Remove all non-root views from registry
        val nonRootViews = views.filter { it.key != "root" }
        for ((viewId, view) in nonRootViews) {
            (view.parent as? ViewGroup)?.removeView(view)
            views.remove(viewId)
        }

        // Clear root view's children but preserve root
        val rootView = views["root"] as? ViewGroup
        rootView?.removeAllViews()

        // Clear hierarchy tracking except for root
        val nonRootHierarchy = viewHierarchy.filter { it.key != "root" }
        for ((parentId, _) in nonRootHierarchy) {
            viewHierarchy.remove(parentId)
        }

        // Clear child-to-parent mappings for non-root views
        val nonRootChildMappings = childToParent.filter { it.value != "root" && it.key != "root" }
        for ((childId, _) in nonRootChildMappings) {
            childToParent.remove(childId)
        }

        // Reset root's children list but keep root entry
        viewHierarchy["root"] = mutableListOf()

        Log.d(TAG, "Hot restart cleanup complete")
    }

    // Helper methods that were missing

    private fun deleteChildrenRecursively(parentId: String) {
        val children = viewHierarchy[parentId] ?: return

        val childrenCopy = children.toList()

        for (childId in childrenCopy) {
            deleteChildrenRecursively(childId)

            val childView = views[childId]
            if (childView != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                views.remove(childId)
                YogaShadowTree.shared.removeNode(childId)
                DCFLayoutManager.shared.unregisterView(childId)
            }

            childToParent.remove(childId)
        }

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
     * CRITICAL FIX: Delete a view - EXACT iOS signature
     */
    fun deleteView(viewId: String): Boolean {
        val view = views[viewId]
        if (view == null) {
            Log.w(TAG, "View not found for deletion: $viewId")
            return false
        }

        Log.d(TAG, "Deleting view: $viewId")

        // First, recursively delete all children like iOS
        deleteChildrenRecursively(viewId)

        // Remove from parent
        (view.parent as? ViewGroup)?.removeView(view)

        // Remove from registries
        views.remove(viewId)

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
     * CRITICAL FIX: Attach a child view to a parent view - EXACT iOS signature
     */
    fun attachView(childId: String, parentId: String, index: Int): Boolean {
        Log.d(TAG, "Attaching view: $childId to parent: $parentId at index: $index")

        val childView = views[childId]
        val parentView = views[parentId] as? ViewGroup

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

        // Update hierarchy tracking like iOS
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

        Log.d(TAG, "Successfully attached view: $childId to parent: $parentId")
        return true
    }

    /**
     * CRITICAL FIX: Detach a child view from its parent - EXACT iOS signature
     */
    fun detachView(childId: String): Boolean {
        Log.d(TAG, "Detaching view: $childId")

        val childView = views[childId]
        if (childView == null) {
            Log.w(TAG, "View not found for detachment: $childId")
            return false
        }

        // Remove view from its parent like iOS
        (childView.parent as? ViewGroup)?.removeView(childView)

        // Update parent-child tracking like iOS
        childToParent[childId]?.let { parentId ->
            viewHierarchy[parentId]?.remove(childId)
        }
        childToParent.remove(childId)

        // Note: We don't remove from views or other registries since we're just detaching like iOS

        Log.d(TAG, "Successfully detached view: $childId")
        return true
    }

    /**
     * Get root view
     */
    fun getRootView(): View? {
        return views["root"]
    }

    private fun deleteChildrenRecursively(parentId: String) {
        val children = viewHierarchy[parentId] ?: return

        val childrenCopy = children.toList()

        for (childId in childrenCopy) {
            deleteChildrenRecursively(childId)

            val childView = views[childId]
            if (childView != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                views.remove(childId)
                YogaShadowTree.shared.removeNode(childId)
                DCFLayoutManager.shared.unregisterView(childId)
            }

            childToParent.remove(childId)
        }

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
     * Cleanup all resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCMauiBridgeImpl")
        views.clear()
        viewHierarchy.clear()
        childToParent.clear()
        appContext = null
        Log.d(TAG, "DCMauiBridgeImpl cleanup complete")
    }
}
}

// CRITICAL FIX: Add JSONObject to Map extension
private fun JSONObject.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val keys = this.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        var value = this.get(key)

        if (value is JSONObject) {
            value = value.toMap()
        } else if (value is JSONArray) {
            value = value.toList()
        }

        map[key] = value
    }
    return map
}

// CRITICAL FIX: Add JSONArray to List extension
private fun JSONArray.toList(): List<Any?> {
    val list = mutableListOf<Any?>()
    for (i in 0 until length()) {
        var value = get(i)
        
        if (value is JSONObject) {
            value = value.toMap()
        } else if (value is JSONArray) {
            value = value.toList()
        }
        
        list.add(value)
    }
    return list
}