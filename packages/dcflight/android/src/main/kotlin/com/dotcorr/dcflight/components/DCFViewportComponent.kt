/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.graphics.Rect
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import androidx.core.view.ViewCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFFrameLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles

class DCFViewportComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFViewportComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = DCFFrameLayout(context)

        view.setTag(DCFTags.COMPONENT_TYPE_KEY, "Viewport")

        updateView(view, props)

        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullProps)
        return true
    }

    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        // Apply layout
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        
        // Trigger measure callbacks after layout
        triggerMeasureCallbacks(view)
    }

    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        Log.d(TAG, "Viewport component registered with shadow tree: $nodeId")
        
        val props = getStoredProps(view)
        val hasViewportCallbacks = props.containsKey("onViewportEnter") || props.containsKey("onViewportLeave")
        
        if (hasViewportCallbacks) {
            setupViewportDetection(view, props)
        }
        
        // Trigger initial measurement after layout
        view.post {
            triggerMeasureCallbacks(view)
            if (hasViewportCallbacks) {
                checkViewportVisibility(view, props)
            }
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    /// Trigger measure() and measureInWindow() callbacks
    private fun triggerMeasureCallbacks(view: View) {
        val props = getStoredProps(view)
        
        // measure() callback - viewport coordinates
        if (props.containsKey("onMeasure")) {
            val measureData = getMeasureData(view)
            propagateEvent(view, "onMeasure", measureData)
        }
        
        // measureInWindow() callback - window coordinates
        if (props.containsKey("onMeasureInWindow")) {
            val measureInWindowData = getMeasureInWindowData(view)
            propagateEvent(view, "onMeasureInWindow", measureInWindowData)
        }
    }
    
    /// Get measure data (viewport coordinates)
    private fun getMeasureData(view: View): Map<String, Any> {
        val frame = Rect()
        view.getHitRect(frame)
        
        // Get position relative to parent (viewport)
        val x = frame.left.toDouble()
        val y = frame.top.toDouble()
        
        // Get position relative to window (page coordinates)
        val location = IntArray(2)
        view.getLocationInWindow(location)
        val pageX = location[0].toDouble()
        val pageY = location[1].toDouble()
        
        return mapOf(
            "x" to x,
            "y" to y,
            "width" to frame.width().toDouble(),
            "height" to frame.height().toDouble(),
            "pageX" to pageX,
            "pageY" to pageY,
        )
    }
    
    /// Get measureInWindow data (window coordinates)
    private fun getMeasureInWindowData(view: View): Map<String, Any> {
        val location = IntArray(2)
        view.getLocationInWindow(location)
        
        return mapOf(
            "x" to location[0].toDouble(),
            "y" to location[1].toDouble(),
            "width" to view.width.toDouble(),
            "height" to view.height.toDouble(),
        )
    }
    
    /// Setup viewport detection
    /// 
    /// Viewport detection works in two modes:
    /// 1. If view is inside a ScrollView: detects visibility within scroll view's visible area
    /// 2. If view is NOT in a ScrollView: detects visibility within window/screen bounds
    private fun setupViewportDetection(view: View, props: Map<String, Any?>) {
        // Find containing scroll view
        val scrollView = findContainingScrollView(view)
        
        if (scrollView != null) {
            // Add scroll listener
            val listener = ViewportScrollListener(view, props, this)
            view.setTag("viewportListener".hashCode(), listener)
            
            // Register scroll listener (if scroll view supports it)
            // For now, we'll use a ViewTreeObserver for layout changes
        }
        
        // Use ViewTreeObserver to detect when view enters/leaves viewport
        val observer = view.viewTreeObserver
        observer.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                checkViewportVisibility(view, props)
                // Remove listener after first check to avoid memory leaks
                // We'll re-add it if needed
            }
        })
        
        // Also check on scroll if in a scroll view
        if (scrollView != null) {
            scrollView.viewTreeObserver.addOnScrollChangedListener {
                checkViewportVisibility(view, props)
            }
        }
    }
    
    /// Find containing scroll view by walking up the hierarchy
    private fun findContainingScrollView(view: View): ViewGroup? {
        var parent = view.parent
        while (parent is ViewGroup) {
            if (parent.javaClass.simpleName.contains("ScrollView") || 
                parent.javaClass.simpleName.contains("RecyclerView")) {
                return parent
            }
            parent = parent.parent
        }
        return null
    }
    
    /// Check if view is visible in viewport
    private fun checkViewportVisibility(view: View, props: Map<String, Any?>) {
        if (view.width == 0 || view.height == 0) return
        
        val viewportConfig = props["viewport"] as? Map<*, *>
        val once = (viewportConfig?.get("once") as? Boolean) ?: false
        val amount = ((viewportConfig?.get("amount") as? Number)?.toDouble()) ?: 0.0
        val margin = ((viewportConfig?.get("margin") as? Number)?.toDouble()) ?: 0.0
        
        // Check if view is in viewport
        val isVisible = isViewInViewport(view, amount, margin)
        
        // Get previous visibility state
        val wasVisible = view.getTag("wasInViewport".hashCode()) as? Boolean ?: false
        
        if (isVisible && !wasVisible) {
            // Entered viewport
            view.setTag("wasInViewport".hashCode(), true)
            
            if (props.containsKey("onViewportEnter")) {
                propagateEvent(view, "onViewportEnter", mapOf())
            }
        } else if (!isVisible && wasVisible) {
            // Left viewport
            if (!once) {
                view.setTag("wasInViewport".hashCode(), false)
                
                if (props.containsKey("onViewportLeave")) {
                    propagateEvent(view, "onViewportLeave", mapOf())
                }
            }
        }
    }
    
    /// Check if view is in viewport
    private fun isViewInViewport(view: View, amount: Double, margin: Double): Boolean {
        if (!view.isAttachedToWindow) {
            return false
        }
        
        val viewRect = Rect()
        view.getGlobalVisibleRect(viewRect)
        
        if (viewRect.isEmpty) {
            return false
        }
        
        // Get window bounds (viewport)
        val windowRect = Rect()
        view.getWindowVisibleDisplayFrame(windowRect)
        windowRect.inset((-margin).toInt(), (-margin).toInt())
        
        // Calculate intersection
        val intersection = Rect()
        if (!intersection.setIntersect(viewRect, windowRect)) {
            return false
        }
        
        // Calculate visible area
        val visibleArea = intersection.width() * intersection.height()
        val totalArea = viewRect.width() * viewRect.height()
        
        if (totalArea == 0) {
            return false
        }
        
        val visibleRatio = visibleArea.toDouble() / totalArea
        return visibleRatio >= amount
    }
    
    /// Scroll listener for viewport detection
    private class ViewportScrollListener(
        private val view: View,
        private val props: Map<String, Any?>,
        private val component: DCFViewportComponent
    ) {
        fun onScroll() {
            component.checkViewportVisibility(view, props)
        }
    }
}

