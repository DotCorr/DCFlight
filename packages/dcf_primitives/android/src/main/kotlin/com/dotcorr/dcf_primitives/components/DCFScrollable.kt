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
            
            // Find the content container (usually the first child FrameLayout)
            val contentView = getChildAt(0) as? FrameLayout
            if (contentView != null) {
                for (i in 0 until contentView.childCount) {
                    val child = contentView.getChildAt(i)
                    val right = child.left + child.width
                    val bottom = child.top + child.height
                    
                    maxWidth = maxOf(maxWidth, right)
                    maxHeight = maxOf(maxHeight, bottom)
                }
            } else {
                // Fallback: check all direct children
                for (i in 0 until childCount) {
                    val child = getChildAt(i)
                    val right = child.left + child.width
                    val bottom = child.top + child.height
                    
                    maxWidth = maxOf(maxWidth, right)
                    maxHeight = maxOf(maxHeight, bottom)
                }
            }
            
            if (virtualizedContentOffsetStart > 0 || virtualizedContentPaddingTop > 0) {
                val extraPadding = maxOf(virtualizedContentOffsetStart, virtualizedContentPaddingTop).toInt()
                
                if (isHorizontal) {
                    maxWidth += extraPadding
                    // Adjust child positions
                    val contentView = getChildAt(0) as? FrameLayout
                    contentView?.let {
                        for (i in 0 until it.childCount) {
                            val child = it.getChildAt(i)
                            child.x = child.x + extraPadding
                        }
                    }
                } else {
                    maxHeight += extraPadding
                    // Adjust child positions
                    val contentView = getChildAt(0) as? FrameLayout
                    contentView?.let {
                        for (i in 0 until it.childCount) {
                            val child = it.getChildAt(i)
                            child.y = child.y + extraPadding
                        }
                    }
                }
            }
            
            val availableWidth = width
            val availableHeight = height
            
            val finalWidth = if (isHorizontal) maxWidth else availableWidth
            val finalHeight = if (isHorizontal) availableHeight else maxHeight
            
            setContentSize(finalWidth, finalHeight)
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
     */
    private fun setContentSize(width: Int, height: Int) {
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null) {
            val layoutParams = contentView.layoutParams as? android.view.ViewGroup.LayoutParams
            if (layoutParams != null) {
                layoutParams.width = width
                layoutParams.height = height
                contentView.layoutParams = layoutParams
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

