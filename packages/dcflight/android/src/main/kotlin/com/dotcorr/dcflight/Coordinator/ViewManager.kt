/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.Coordinator

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

/**
 * Main view manager that coordinates between all view-related systems
 */
class DCFViewManager private constructor() {

    companion object {
        private const val TAG = "DCFViewManager"
        
        @JvmField
        val shared = DCFViewManager()
    }

    /**
     * Clean up for hot restart (simplified version)
     */
    fun cleanupForHotRestart() {
        Log.d(TAG, "🔥 DCF_ENGINE: ViewManager hot restart cleanup called")
        Log.d(TAG, "🔥 DCF_ENGINE: ViewManager cleanup for hot restart completed")
    }

    fun createView(viewId: String, viewType: String, props: Map<String, Any?>): Boolean {
        val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
        if (componentClass == null) {
            Log.e(TAG, "Component type '$viewType' not found")
            return false
        }

        val rootView = ViewRegistry.shared.getView("root")
        val context = rootView?.context
        if (context == null) {
            Log.e(TAG, "No context available for creating view")
            return false
        }

        val componentInstance = try {
            componentClass.getDeclaredConstructor().newInstance()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component instance", e)
            return false
        }

        val view = componentInstance.createView(context, props)

        view.setTag(com.dotcorr.dcflight.R.id.dcf_component_type, viewType)

        ViewRegistry.shared.registerView(view, viewId, viewType)

        val isScreen = (viewType == "Screen" || props["presentationStyle"] != null)

        if (isScreen) {
            YogaShadowTree.shared.createScreenRoot(viewId, viewType)
        } else {
            YogaShadowTree.shared.createNode(viewId, viewType)
        }

        YogaShadowTree.shared.updateNodeLayoutProps(viewId, props)

        return true
    }

    fun updateView(viewId: String, props: Map<String, Any?>): Boolean {
        val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
        if (viewInfo == null) {
            Log.e(TAG, "View '$viewId' not found for update")
            return false
        }

        val view = viewInfo.view
        val type = viewInfo.type

        if (!YogaShadowTree.shared.isScreenRoot(viewId)) {
            YogaShadowTree.shared.updateNodeLayoutProps(viewId, props)
        }

        val layoutProps = extractLayoutProps(props)
        val nonLayoutProps = extractNonLayoutProps(props)

        if (nonLayoutProps.isNotEmpty()) {
            val componentClass = DCFComponentRegistry.shared.getComponentType(type)
            if (componentClass == null) {
                Log.e(TAG, "Component type '$type' not found for update")
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

        return true
    }

    fun deleteView(viewId: String): Boolean {
        ViewRegistry.shared.removeView(viewId)
        DCFLayoutManager.shared.unregisterView(viewId)

        return true
    }

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

        if (childView.parent != null) {
            (childView.parent as? ViewGroup)?.removeView(childView)
        }

        if (index >= 0 && index <= parentViewGroup.childCount) {
            parentViewGroup.addView(childView, index)
        } else {
            parentViewGroup.addView(childView)
        }

        if (!YogaShadowTree.shared.isScreenRoot(childId)) {
            YogaShadowTree.shared.addChildNode(parentId, childId, index)
        }

        val screenWidth = android.content.res.Resources.getSystem().displayMetrics.widthPixels.toFloat()
        val screenHeight = android.content.res.Resources.getSystem().displayMetrics.heightPixels.toFloat()
        YogaShadowTree.shared.updateScreenRootDimensions(screenWidth, screenHeight)

        return true
    }

    fun detachView(viewId: String): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View '$viewId' not found for detach")
            return false
        }

        val parentView = view.parent as? ViewGroup
        parentView?.removeView(view)

        YogaShadowTree.shared.removeNode(viewId)

        return true
    }

    fun setChildren(viewId: String, childrenIds: List<String>): Boolean {
        val parentView = ViewRegistry.shared.getView(viewId)
        val parentViewGroup = parentView as? ViewGroup

        if (parentViewGroup == null) {
            Log.e(TAG, "Parent view '$viewId' is not a ViewGroup")
            return false
        }

        parentViewGroup.removeAllViews()

        childrenIds.forEach { childId ->
            val childView = ViewRegistry.shared.getView(childId)
            if (childView != null) {
                parentViewGroup.addView(childView)
            }
        }

        for (childId in childrenIds) {
        }

        return true
    }

    private fun extractLayoutProps(props: Map<String, Any?>): Map<String, Any?> {
        val layoutProps = mutableMapOf<String, Any?>()
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

        props.forEach { (key, value) ->
            if (supportedLayoutProps.contains(key)) {
                layoutProps[key] = value
            }
        }

        return layoutProps
    }

    private fun extractNonLayoutProps(props: Map<String, Any?>): Map<String, Any?> {
        val nonLayoutProps = mutableMapOf<String, Any?>()
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

        props.forEach { (key, value) ->
            if (!supportedLayoutProps.contains(key)) {
                nonLayoutProps[key] = value
            }
        }

        return nonLayoutProps
    }
}

