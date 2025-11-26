/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.utils

import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import androidx.core.widget.NestedScrollView
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcf_primitives.components.DCFScrollableView

/**
 * Low-level viewport detection system - similar to web IntersectionObserver
 * Any view can register for viewport visibility callbacks
 */
object DCFViewportObserver {
    private val observedViews = mutableMapOf<View, ViewportConfig>()
    private val scrollViewObservers = mutableMapOf<ViewGroup, MutableSet<View>>()
    
    /**
     * Register a view for viewport detection
     */
    fun observe(view: View, config: ViewportConfig) {
        observedViews[view] = config
        
        // Find parent scroll view
        val scrollView = findParentScrollView(view)
        if (scrollView != null) {
            if (!scrollViewObservers.containsKey(scrollView)) {
                scrollViewObservers[scrollView] = mutableSetOf()
                setupScrollObserver(scrollView)
            }
            scrollViewObservers[scrollView]?.add(view)
        } else {
            // No scroll view - check initial visibility
            checkVisibility(view, config)
        }
    }
    
    /**
     * Unregister a view
     */
    fun unobserve(view: View) {
        observedViews.remove(view)
        
        // Remove from scroll view observers
        scrollViewObservers.forEach { (scrollView, views) ->
            if (views.contains(view)) {
                views.remove(view)
                if (views.isEmpty()) {
                    scrollViewObservers.remove(scrollView)
                }
            }
        }
    }
    
    /**
     * Find parent scroll view
     */
    private fun findParentScrollView(view: View): ViewGroup? {
        var current: View? = view.parent as? View
        while (current != null) {
            if (current is NestedScrollView || current is DCFScrollableView) {
                return current as ViewGroup
            }
            current = current.parent as? View
        }
        return null
    }
    
    /**
     * Setup scroll observer for a scroll view
     */
    private fun setupScrollObserver(scrollView: ViewGroup) {
        if (scrollView is NestedScrollView) {
            scrollView.viewTreeObserver.addOnScrollChangedListener {
                checkViewsInScrollView(scrollView)
            }
        }
    }
    
    /**
     * Check visibility of views in a scroll view
     */
    private fun checkViewsInScrollView(scrollView: ViewGroup) {
        val views = scrollViewObservers[scrollView] ?: return
        
        views.forEach { view ->
            observedViews[view]?.let { config ->
                checkVisibility(view, inScrollView = scrollView, config)
            }
        }
    }
    
    /**
     * Check if view is visible (no scroll view)
     */
    private fun checkVisibility(view: View, config: ViewportConfig) {
        val windowRect = Rect()
        view.getGlobalVisibleRect(windowRect)
        
        val isVisible = windowRect.width() > 0 && windowRect.height() > 0
        val intersectionRatio = if (isVisible) {
            val viewArea = view.width * view.height
            if (viewArea > 0) {
                (windowRect.width() * windowRect.height()).toDouble() / viewArea
            } else {
                0.0
            }
        } else {
            0.0
        }
        
        handleVisibilityChange(view, isVisible, intersectionRatio, config)
    }
    
    /**
     * Check if view is visible in scroll view
     */
    private fun checkVisibility(view: View, inScrollView: ViewGroup, config: ViewportConfig) {
        val scrollViewRect = Rect()
        inScrollView.getGlobalVisibleRect(scrollViewRect)
        
        val viewRect = Rect()
        view.getGlobalVisibleRect(viewRect)
        
        val intersection = Rect()
        val isVisible = intersection.setIntersect(scrollViewRect, viewRect)
        val intersectionRatio = if (isVisible) {
            val viewArea = view.width * view.height
            if (viewArea > 0) {
                (intersection.width() * intersection.height()).toDouble() / viewArea
            } else {
                0.0
            }
        } else {
            0.0
        }
        
        handleVisibilityChange(view, isVisible, intersectionRatio, config)
    }
    
    /**
     * Calculate intersection ratio (0.0 to 1.0)
     */
    private fun calculateIntersectionRatio(viewRect: Rect, containerRect: Rect): Double {
        val intersection = Rect()
        val intersects = intersection.setIntersect(viewRect, containerRect)
        
        if (!intersects) {
            return 0.0
        }
        
        val viewArea = viewRect.width() * viewRect.height()
        if (viewArea == 0) {
            return 0.0
        }
        
        val intersectionArea = intersection.width() * intersection.height()
        return intersectionArea.toDouble() / viewArea
    }
    
    /**
     * Handle visibility change
     */
    private fun handleVisibilityChange(view: View, isVisible: Boolean, ratio: Double, config: ViewportConfig) {
        // Check threshold
        val threshold = config.amount ?: 0.0
        val meetsThreshold = ratio >= threshold
        
        // Get current state
        val wasVisible = view.getTag(DCFTags.VIEWPORT_VISIBLE_KEY) as? Boolean ?: false
        
        if (isVisible && meetsThreshold && !wasVisible) {
            // Entered viewport
            view.setTag(DCFTags.VIEWPORT_VISIBLE_KEY, true)
            propagateEvent(view, "onViewportEnter", mapOf(
                "intersectionRatio" to ratio,
                "isIntersecting" to true
            ))
        } else if ((!isVisible || !meetsThreshold) && wasVisible) {
            // Left viewport
            if (!config.once) {
                view.setTag(DCFTags.VIEWPORT_VISIBLE_KEY, false)
                propagateEvent(view, "onViewportLeave", mapOf(
                    "intersectionRatio" to ratio,
                    "isIntersecting" to false
                ))
            }
        }
    }
}

data class ViewportConfig(
    val once: Boolean = false,
    val amount: Double? = null // 0.0 to 1.0
)

