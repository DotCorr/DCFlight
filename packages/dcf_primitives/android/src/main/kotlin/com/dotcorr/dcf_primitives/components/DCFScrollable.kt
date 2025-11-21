/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.widget.NestedScrollView
import com.dotcorr.dcflight.components.DCFContentContainerProvider
import com.dotcorr.dcflight.components.propagateEvent

/**
 * Custom ScrollView that implements VirtualizedList content size management
 * Key insight: Yoga handles layout, but contentSize must be explicitly managed
 * 
 * Matches iOS DCFScrollableView behavior
 */
class DCFScrollableView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : NestedScrollView(context, attrs, defStyleAttr), DCFContentContainerProvider {
    
    var isHorizontal: Boolean = false
    var virtualizedContentOffsetStart: Float = 0f
    var virtualizedContentPaddingTop: Float = 0f
    var nodeId: String? = null
    
    private var explicitContentSize: Pair<Int, Int>? = null
    private var lastFrameSize: Pair<Int, Int> = Pair(0, 0)
    private var isUpdatingContentSize: Boolean = false // Prevent redundant calculations
    
    // Content container for children (NestedScrollView can only have one direct child)
    private var contentContainer: FrameLayout? = null
    
    init {
        setupDCFScrollableView()
    }
    
    private fun setupDCFScrollableView() {
        clipToPadding = true
        clipChildren = true
        
        // Create content container (will be added by component)
        contentContainer = FrameLayout(context)
    }
    
    /**
     * Set the content container (called by DCFScrollViewComponent)
     */
    fun setContentContainer(container: FrameLayout) {
        contentContainer = container
    }
    
    /**
     * DCFContentContainerProvider implementation
     * Returns the FrameLayout content container where children should be attached
     */
    override fun getContentContainer(): ViewGroup? {
        return contentContainer
    }
    
    /**
     * Update content size based on Yoga layout results - React Native VirtualizedList approach
     * Matches iOS updateContentSizeFromYogaLayout() behavior
     * 
     * CRITICAL: This calculates the content size from children's actual positions after Yoga layout
     */
    fun updateContentSizeFromYogaLayout() {
        if (isUpdatingContentSize) return
        isUpdatingContentSize = true
        
        try {
            if (explicitContentSize != null) {
                val (width, height) = explicitContentSize!!
                setContentSize(width, height)
                return
            }
            
            var maxWidth = 0
            var maxHeight = 0
            
            // Find the content container (FrameLayout that holds all children)
            val contentView = getChildAt(0) as? FrameLayout
            if (contentView != null && contentView.childCount > 0) {
                // Calculate max bounds from all children in content container
                for (i in 0 until contentView.childCount) {
                    val child = contentView.getChildAt(i)
                    // Use measured dimensions if layout hasn't happened yet
                    val childWidth = if (child.width > 0) child.width else child.measuredWidth
                    val childHeight = if (child.height > 0) child.height else child.measuredHeight
                    val childLeft = if (child.left > 0) child.left else child.left
                    val childTop = if (child.top > 0) child.top else child.top
                    
                    val right = childLeft + childWidth
                    val bottom = childTop + childHeight
                    
                    maxWidth = maxOf(maxWidth, right)
                    maxHeight = maxOf(maxHeight, bottom)
                }
            } else {
                // Fallback: if no content container or no children, use ScrollView's own size
                maxWidth = width
                maxHeight = height
            }
            
            // Handle virtualized content offset (for VirtualizedList)
            if (virtualizedContentOffsetStart > 0 || virtualizedContentPaddingTop > 0) {
                val extraPadding = maxOf(virtualizedContentOffsetStart, virtualizedContentPaddingTop).toInt()
                
                if (isHorizontal) {
                    maxWidth += extraPadding
                    // Adjust child positions
                    contentView?.let {
                        for (i in 0 until it.childCount) {
                            val child = it.getChildAt(i)
                            child.translationX = child.translationX + extraPadding
                        }
                    }
                } else {
                    maxHeight += extraPadding
                    // Adjust child positions
                    contentView?.let {
                        for (i in 0 until it.childCount) {
                            val child = it.getChildAt(i)
                            child.translationY = child.translationY + extraPadding
                        }
                    }
                }
            }
            
            // For vertical scrolling: width = ScrollView width, height = max content height
            // For horizontal scrolling: width = max content width, height = ScrollView height
            val availableWidth = if (width > 0) width else measuredWidth
            val availableHeight = if (height > 0) height else measuredHeight
            
            val finalWidth = if (isHorizontal) maxWidth else maxOf(availableWidth, maxWidth)
            val finalHeight = if (isHorizontal) maxOf(availableHeight, maxHeight) else maxHeight
            
            // Ensure minimum size matches ScrollView bounds
            val finalContentWidth = maxOf(finalWidth, availableWidth)
            val finalContentHeight = maxOf(finalHeight, availableHeight)
            
            setContentSize(finalContentWidth, finalContentHeight)
        } finally {
            isUpdatingContentSize = false
        }
    }
    
    /**
     * Set explicit content size from Dart side - VirtualizedList approach
     * Matches iOS setExplicitContentSize() behavior
     */
    fun setExplicitContentSize(width: Int, height: Int) {
        explicitContentSize = Pair(width, height)
        setContentSize(width, height)
    }
    
    /**
     * Set content size and notify Dart side
     * CRITICAL: Updates the content container's size so ScrollView knows how much to scroll
     */
    private fun setContentSize(width: Int, height: Int) {
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null) {
            val layoutParams = contentView.layoutParams as? android.view.ViewGroup.LayoutParams
            if (layoutParams != null) {
                // Only update if size actually changed
                if (layoutParams.width != width || layoutParams.height != height) {
                    layoutParams.width = width
                    layoutParams.height = height
                    contentView.layoutParams = layoutParams
                    // CRITICAL: Explicitly lay out the container at (0, 0) with new size
                    contentView.layout(0, 0, width, height)
                    // Force layout to apply new size
                    contentView.requestLayout()
                }
            }
        }
        
        // Notify Dart side of content size update
        notifyContentSizeUpdate(width, height)
    }
    
    /**
     * Notify Dart side of content size updates through propagateEvent
     * Matches iOS notifyContentSizeUpdate() behavior
     */
    private fun notifyContentSizeUpdate(width: Int, height: Int) {
        propagateEvent(this, "onContentSizeChange", mapOf(
            "contentSize" to mapOf(
                "width" to width.toDouble(),
                "height" to height.toDouble()
            )
        ))
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        // CRITICAL: Ensure content container is positioned at (0, 0) and sized correctly
        val contentContainer = getChildAt(0) as? FrameLayout
        contentContainer?.let { container ->
            val scrollWidth = right - left
            val scrollHeight = bottom - top
            if (scrollWidth > 0 && scrollHeight > 0) {
                // Update layout params to match explicit layout
                val layoutParams = container.layoutParams
                if (layoutParams != null) {
                    // For vertical scrolling: width = ScrollView width, height = at least ScrollView height
                    // For horizontal scrolling: width = at least ScrollView width, height = ScrollView height
                    if (!isHorizontal) {
                        layoutParams.width = scrollWidth
                        // Height will be updated by updateContentSizeFromYogaLayout, but ensure minimum
                        if (layoutParams.height == ViewGroup.LayoutParams.WRAP_CONTENT || layoutParams.height < scrollHeight) {
                            layoutParams.height = scrollHeight
                        }
                    } else {
                        // Horizontal scrolling (not fully implemented yet)
                        if (layoutParams.width == ViewGroup.LayoutParams.WRAP_CONTENT || layoutParams.width < scrollWidth) {
                            layoutParams.width = scrollWidth
                        }
                        layoutParams.height = scrollHeight
                    }
                    container.layoutParams = layoutParams
                }
                // Explicitly lay out the container at (0, 0) with current size
                // Use actual dimensions, not layout params (which might be WRAP_CONTENT constants)
                val containerWidth = if (layoutParams.width > 0) layoutParams.width else scrollWidth
                val containerHeight = if (layoutParams.height > 0) layoutParams.height else scrollHeight
                container.layout(0, 0, containerWidth, containerHeight)
            }
        }
        
        val currentWidth = right - left
        val currentHeight = bottom - top
        val currentFrameSize = Pair(currentWidth, currentHeight)
        
        if (lastFrameSize != currentFrameSize && !isUpdatingContentSize) {
            lastFrameSize = currentFrameSize
            
            if (currentWidth > 0 && currentHeight > 0 && childCount > 0) {
                // CRITICAL: Delay to ensure Yoga layout is complete after orientation change
                postDelayed({
                    if (!isUpdatingContentSize) {
                        updateContentSizeFromYogaLayout()
                    }
                }, 100) // 100ms delay, matches iOS 0.1s
            }
        }
    }
    
    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        // Clear explicit content size on configuration change (orientation, etc.)
        explicitContentSize = null
    }
}

