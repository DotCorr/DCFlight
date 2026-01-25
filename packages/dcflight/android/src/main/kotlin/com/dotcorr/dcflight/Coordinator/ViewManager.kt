/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
     * ⚡ PERFORMANCE OPTIMIZATION: Component Instance Caching
     * 
     * Android doesn't use view pooling (for stability), but we cache component class instances
     * to avoid repeated instantiation overhead. This provides similar performance benefits
     * to iOS view pooling but at the factory layer instead of the view layer.
     * 
     * Component instances are stateless factories, so caching them is safe and doesn't cause
     * the duplicate view issues that view pooling had.
     */
    private val componentInstanceCache = mutableMapOf<String, DCFComponent>()
    
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
     * Clean up for hot restart (simplified version)
     */
    fun cleanupForHotRestart() {
        Log.d(TAG, "🔥 DCF_ENGINE: ViewManager hot restart cleanup called")
        // Clear component instance cache on hot restart
        componentInstanceCache.clear()
        Log.d(TAG, "🔥 DCF_ENGINE: ViewManager cleanup for hot restart completed")
    }

    fun createView(viewId: Int, viewType: String, props: Map<String, Any?>): Boolean {
        val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
        if (componentClass == null) {
            Log.e(TAG, "Component type '$viewType' not found")
            return false
        }

        val rootView = ViewRegistry.shared.getView(0)
        val context = rootView?.context
        if (context == null) {
            Log.e(TAG, "No context available for creating view")
            return false
        }

        // ⚡ PERFORMANCE: Use cached component instance to avoid repeated instantiation
        val componentInstance = try {
            getCachedComponentInstance(viewType)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get component instance", e)
            return false
        } ?: return false

        val view = componentInstance.createView(context, props)

        // ✅ Use pure Kotlin tag keys instead of XML resource IDs
        view.setTag(com.dotcorr.dcflight.components.DCFTags.COMPONENT_TYPE_KEY, viewType)

        // CRITICAL: Prevent flash - keep views invisible until layout is applied
        // Root view (0) is always visible
        if (viewId == 0) {
            view.visibility = View.VISIBLE
            view.alpha = 1.0f
            Log.d(TAG, "🔍 ViewManager.createView: Root view (viewId=0) created, visibility=${view.visibility}, alpha=${view.alpha}")
        } else {
            // Non-root views start INVISIBLE to prevent flash of incorrect layout
            // They'll be made visible when layout is applied (in applyLayout)
            view.visibility = View.INVISIBLE
            view.alpha = 1.0f
            Log.d(TAG, "🔍 ViewManager.createView: viewId=$viewId created, visibility=${view.visibility}, alpha=${view.alpha} (will be made visible after layout)")
        }

        ViewRegistry.shared.registerView(view, viewId, viewType)
        Log.d(TAG, "✅ ViewManager.createView: viewId=$viewId registered, viewType=$viewType, hasParent=${view.parent != null}, visibility=${view.visibility}")

        val isScreen = (viewType == "Screen" || props["presentationStyle"] != null)
        if (isScreen) {
            YogaShadowTree.shared.createScreenRoot(viewId.toString(), viewType)
        } else {
            YogaShadowTree.shared.createNode(viewId.toString(), viewType)
        }

        YogaShadowTree.shared.updateNodeLayoutProps(viewId.toString(), props)

        // CRITICAL: Call DCFLayoutManager.registerView to trigger viewRegisteredWithShadowTree
        // This notifies the component that the view is registered and ready
        DCFLayoutManager.shared.registerView(view, viewId.toString(), viewType, componentInstance)

        return true
    }

    fun updateView(viewId: Int, props: Map<String, Any?>): Boolean {
        val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
        if (viewInfo == null) {
            Log.e(TAG, "View '$viewId' not found for update")
            return false
        }

        val view = viewInfo.view
        val type = viewInfo.type

        if (!YogaShadowTree.shared.isScreenRoot(viewId.toString())) {
            YogaShadowTree.shared.updateNodeLayoutProps(viewId.toString(), props)
        }

        val layoutProps = extractLayoutProps(props)
        val nonLayoutProps = extractNonLayoutProps(props)

        if (nonLayoutProps.isNotEmpty()) {
            // ⚡ PERFORMANCE: Use cached component instance
            val componentInstance = try {
                getCachedComponentInstance(type)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get component instance for update", e)
                return false
            } ?: return false

            val success = componentInstance.updateView(view, nonLayoutProps)

            if (!success) {
                Log.e(TAG, "Failed to update non-layout props for view '$viewId'")
                return false
            }
        }

        return true
    }

    fun deleteView(viewId: Int): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        val layoutAnimationEnabled = DCFLayoutManager.shared.layoutAnimationEnabled
        val animationDuration = DCFLayoutManager.shared.layoutAnimationDuration
        
        if (view != null && layoutAnimationEnabled && animationDuration > 0) {
            // Fade out animation before removing view
            view.animate()
                .alpha(0f)
                .setDuration(animationDuration)
                .setInterpolator(DCFLayoutManager.shared.layoutAnimationInterpolator)
                .withEndAction {
                    // Remove from registry and layout manager after animation
                    ViewRegistry.shared.removeView(viewId)
                    DCFLayoutManager.shared.unregisterView(viewId)
                    
                    // Remove from parent if still attached
                    (view.parent as? ViewGroup)?.removeView(view)
                }
                .start()
        } else {
            // No animation - remove immediately
            ViewRegistry.shared.removeView(viewId)
            DCFLayoutManager.shared.unregisterView(viewId)
        }

        return true
    }

    fun attachView(childId: Int, parentId: Int, index: Int): Boolean {
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

        if (!YogaShadowTree.shared.isScreenRoot(childId.toString())) {
            YogaShadowTree.shared.addChildNode(parentId, childId, index)
        }

        val screenWidth = android.content.res.Resources.getSystem().displayMetrics.widthPixels.toFloat()
        val screenHeight = android.content.res.Resources.getSystem().displayMetrics.heightPixels.toFloat()
        YogaShadowTree.shared.updateScreenRootDimensions(screenWidth, screenHeight)

        return true
    }

    fun detachView(viewId: Int): Boolean {
        val view = ViewRegistry.shared.getView(viewId)
        if (view == null) {
            Log.e(TAG, "View '$viewId' not found for detach")
            return false
        }

        val parentView = view.parent as? ViewGroup
        parentView?.removeView(view)

        YogaShadowTree.shared.removeNode(viewId.toString())

        return true
    }

    fun setChildren(viewId: Int, childrenIds: List<Int>): Boolean {
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

