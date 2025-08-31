/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFComponentRegistry

/**
 * CRITICAL FIX: Main view manager that coordinates between all view-related systems
 * This was completely missing in Android - matches iOS DCFViewManager exactly
 */
class DCFViewManager private constructor() {

    companion object {
        private const val TAG = "DCFViewManager"
        
        @JvmField
        val shared = DCFViewManager()
    }

    /**
     * Create a view with automatic layout handling - EXACT iOS signature
     */
    fun createView(viewId: String, viewType: String, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Creating view: $viewId of type: $viewType")

        // Get component type
        val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
        if (componentClass == null) {
            Log.e(TAG, "Component type '$viewType' not found")
            return false
        }

        // Get context - try to get from existing root view
        val rootView = ViewRegistry.shared.getView("root")
        val context = rootView?.context
        if (context == null) {
            Log.e(TAG, "No context available for creating view")
            return false
        }

        // Create component instance and view
        val componentInstance = try {
            componentClass.getDeclaredConstructor().newInstance()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component instance", e)
            return false
        }

        val view = componentInstance.createView(context, props)

        // Tag the view with its component type for event registration like iOS
        view.setTag(com.dotcorr.dcflight.R.id.dcf_component_type, viewType)

        // Register the view
        ViewRegistry.shared.registerView(view, viewId, viewType)

        // CRITICAL FIX: Detect if this is a screen component like iOS
        val isScreen = (viewType == "Screen" || props["presentationStyle"] != null)

        if (isScreen) {
            Log.d(TAG, "🖼️ Creating screen '$viewId' with presentation style: ${props["presentationStyle"] ?: "unknown"}")

            // CRITICAL FIX: Create screen as its own Yoga root like iOS
            YogaShadowTree.shared.createScreenRoot(viewId, viewType)

            // Apply layout props to the screen root
            val layoutProps = extractLayoutProps(props)
            if (layoutProps.isNotEmpty()) {
                YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
                Log.d(TAG, "📐 Applied layout props to screen root '$viewId'")
            }

        } else {
            Log.d(TAG, "🧩 Creating regular component '$viewId' of type '$viewType'")

            // Regular components get added to the main Yoga tree
            YogaShadowTree.shared.createNode(viewId, viewType)

            // Apply layout props to regular component
            val layoutProps = extractLayoutProps(props)
            if (layoutProps.isNotEmpty()) {
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    viewId,
                    viewType,
                    layoutProps
                )
                Log.d(TAG, "📐 Applied layout props to component '$viewId'")
            }
        }

        // Register with layout manager like iOS
        DCFLayoutManager.shared.registerView(view, viewId, viewType, componentInstance)

        Log.d(TAG, "✅ Successfully created ${if (isScreen) "screen" else "component"} '$viewId'")
        return true
    }

    /**
     * Update a view with automatic layout handling - EXACT iOS signature
     */
    fun updateView(viewId: String, props: Map<String, Any?>): Boolean {
        val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
        if (viewInfo == null) {
            Log.e(TAG, "View '$viewId' not found for update")
            return false
        }

        val view = viewInfo.view
        val viewType = viewInfo.type

        Log.d(TAG, "🔄 Updating view '$viewId' of type '$viewType'")

        // Separate layout props from other props like iOS
        val layoutProps = extractLayoutProps(props)
        val nonLayoutProps = props.filter { !layoutProps.keys.contains(it.key) }

        // Update layout props if any
        if (layoutProps.isNotEmpty()) {
            // CRITICAL FIX: Use appropriate layout update method based on whether this is a screen like iOS
            val isScreen = YogaShadowTree.shared.isScreenRoot(viewId)

            if (isScreen) {
                Log.d(TAG, "📐 Updating layout props for screen root '$viewId'")
                YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
            } else {
                Log.d(TAG, "📐 Updating layout props for regular component '$viewId'")
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    viewId,
                    viewType,
                    layoutProps
                )
            }
        }

        // Update non-layout props
        if (nonLayoutProps.isNotEmpty()) {
            val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
            if (componentClass == null) {
                Log.e(TAG, "Component type '$viewType' not found for update")
                return false
            }

            val componentInstance = try {
                componentClass.getDeclaredConstructor().newInstance()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create component instance for update", e)
                return false
            }

            val success = componentInstance.updateView(view, nonLayoutProps)

            if (!success) {
                Log.e(TAG, "Failed to update non-layout props for view '$viewId'")
                return false
            }
        }

        Log.d(TAG, "✅ Successfully updated view '$viewId'")
        return true
    }

    /**
     * Delete a view with automatic cleanup - EXACT iOS signature
     */
    fun deleteView(viewId: String): Boolean {
        Log.d(TAG, "🗑️ Deleting view '$viewId'")

        // Remove from registries
        ViewRegistry.shared.removeView(viewId)
        DCFLayoutManager.shared.removeNode(viewId)

        Log.d(TAG, "✅ Successfully deleted view '$viewId'")
        return true
    }

    /**
     * CRITICAL FIX: Modified attachView to handle screen attachment properly like iOS
     */
    fun attachView(childId: String, parentId: String, index: Int): Boolean {
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

        // Add to view hierarchy like iOS
        if (index >= 0 && index < parentViewGroup.childCount) {
            parentViewGroup.addView(childView, index)
        } else {
            parentViewGroup.addView(childView)
        }
        Log.d(TAG, "🔗 Attached view '$childId' to parent '$parentId' at index $index")

        // CRITICAL FIX: Only update Yoga layout tree for non-screen components like iOS
        val childIsScreen = YogaShadowTree.shared.isScreenRoot(childId)

        if (!childIsScreen) {
            // Regular component can be added to Yoga tree
            DCFLayoutManager.shared.addChildNode(parentId, childId, index)
            Log.d(TAG, "📊 Added '$childId' to Yoga tree under parent '$parentId'")
        } else {
            Log.d(TAG, "🚫 Skipped Yoga tree update for screen '$childId' - screens are independent roots")
        }

        return true
    }

    /**
     * CRITICAL FIX: Add method to handle screen dimension updates like iOS
     */
    fun updateScreenDimensions(width: Float, height: Float) {
        Log.d(TAG, "📐 Updating all screen dimensions to ${width}x${height}")
        YogaShadowTree.shared.updateScreenRootDimensions(width, height)
    }

    /**
     * Extract layout properties from props dictionary - EXACT iOS pattern
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
}

