/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView

/**
 * DCFComposeContainerView - Wrapper for ComposeView with DCFlight integration
 * 
 * Uses composition instead of inheritance since ComposeView is final.
 * 
 * Provides:
 * - Pure Kotlin tag management (no XML resources)
 * - Event registration
 * - Proper measurement for Yoga layout
 * - Seamless integration with DCFComponent protocol
 * 
 * This allows Compose components to work perfectly with Yoga layout system
 * since ComposeView IS a View and Yoga can measure/position it natively
 */
class DCFComposeContainerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {
    
    companion object {
        private const val TAG = "DCFComposeContainerView"
    }
    
    private val composeView: ComposeView
    private var composableContent: (@Composable () -> Unit)? = null
    
    init {
        // Create ComposeView as a child
        composeView = ComposeView(context)
        composeView.layoutParams = LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT
        )
        // CRITICAL: Ensure ComposeView is visible
        composeView.visibility = View.VISIBLE
        composeView.alpha = 1.0f
        addView(composeView)
        
        // CRITICAL: Set visibility explicitly for container
        visibility = View.VISIBLE
        alpha = 1.0f
    }
    
    /**
     * Set the Compose content for this view
     * This is called by components to update the Compose UI
     */
    fun setComposableContent(content: @Composable () -> Unit) {
        composableContent = content
        composeView.setContent {
            // Pure Compose - no XML layouts needed!
            content()
        }
    }
    
    /**
     * Register events for this view
     * Uses pure Kotlin tag keys - NO XML resources
     */
    fun registerEvents(viewId: String, eventTypes: Set<String>, callback: (String, Map<String, Any?>) -> Unit) {
        setTag(DCFTags.VIEW_ID_KEY, viewId)
        setTag(DCFTags.EVENT_TYPES_KEY, eventTypes)
        setTag(DCFTags.EVENT_CALLBACK_KEY, callback)
        Log.d(TAG, "Registered events for view $viewId: $eventTypes")
    }
    
    /**
     * Get the current composable content (for debugging)
     */
    fun getComposableContent(): (@Composable () -> Unit)? = composableContent
    
    /**
     * Get the internal ComposeView (for measurement)
     */
    fun getComposeView(): ComposeView = composeView
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // CRITICAL: Measure the ComposeView child first
        // This ensures Compose can measure its content
        val widthMode = View.MeasureSpec.getMode(widthMeasureSpec)
        val heightMode = View.MeasureSpec.getMode(heightMeasureSpec)
        val widthSize = View.MeasureSpec.getSize(widthMeasureSpec)
        val heightSize = View.MeasureSpec.getSize(heightMeasureSpec)
        
        // If we have UNSPECIFIED, let ComposeView measure itself
        // Otherwise, pass the constraints to ComposeView
        val childWidthSpec = if (widthMode == View.MeasureSpec.UNSPECIFIED) {
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        } else {
            View.MeasureSpec.makeMeasureSpec(widthSize, widthMode)
        }
        
        val childHeightSpec = if (heightMode == View.MeasureSpec.UNSPECIFIED) {
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        } else {
            View.MeasureSpec.makeMeasureSpec(heightSize, heightMode)
        }
        
        // CRITICAL: Ensure content is set before measuring
        if (composableContent == null) {
            // If no content, measure as empty
            setMeasuredDimension(0, 0)
            return
        }
        
        composeView.measure(childWidthSpec, childHeightSpec)
        
        // Use the ComposeView's measured size
        // If ComposeView measured as 0, use a fallback based on available space
        var measuredWidth = composeView.measuredWidth
        var measuredHeight = composeView.measuredHeight
        
        // If ComposeView returns 0 (not ready yet), use the available space or minimum
        if (measuredWidth <= 0 && widthMode != View.MeasureSpec.UNSPECIFIED) {
            measuredWidth = widthSize.coerceAtLeast(1)
        } else if (measuredWidth <= 0) {
            measuredWidth = 1 // Minimum width
        }
        
        if (measuredHeight <= 0 && heightMode != View.MeasureSpec.UNSPECIFIED) {
            measuredHeight = heightSize.coerceAtLeast(1)
        } else if (measuredHeight <= 0) {
            measuredHeight = 20 // Minimum height for text (approximately 1 line)
        }
        
        setMeasuredDimension(measuredWidth, measuredHeight)
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        // CRITICAL: Layout the ComposeView to fill the container
        val width = right - left
        val height = bottom - top
        composeView.layout(0, 0, width, height)
    }
}
