/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.widget.NestedScrollView
import com.dotcorr.dcflight.components.DCFContentContainerProvider
import com.dotcorr.dcflight.components.DCFTags
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
    
    companion object {
        private const val TAG = "DCFScrollableView"
    }
    
    var isHorizontal: Boolean = false
    var virtualizedContentOffsetStart: Float = 0f
    var virtualizedContentPaddingTop: Float = 0f
    var nodeId: String? = null
    
    private var explicitContentSize: Pair<Int, Int>? = null
    private var lastFrameSize: Pair<Int, Int> = Pair(0, 0)
    private var isUpdatingContentSize: Boolean = false // Prevent redundant calculations
    private var lastSetContentSize: Pair<Int, Int>? = null // Track last set content size
    
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
        if (isUpdatingContentSize) {
            Log.d(TAG, "⏭️ updateContentSizeFromYogaLayout: Already updating, skipping")
            return
        }
        isUpdatingContentSize = true
        
        try {
            if (explicitContentSize != null) {
                val (width, height) = explicitContentSize!!
                Log.d(TAG, "📐 updateContentSizeFromYogaLayout: Using explicit size ${width}x${height}")
                setContentSize(width, height)
                return
            }
            
            var maxWidth = 0
            var maxHeight = 0
            
            // Find the content container (FrameLayout that holds all children)
            val contentView = getChildAt(0) as? FrameLayout
            Log.d(TAG, "🔍 updateContentSizeFromYogaLayout: contentView=$contentView, childCount=${contentView?.childCount ?: 0}")
            
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
                    
                    Log.d(TAG, "  Child $i: pos=($childLeft, $childTop), size=${childWidth}x${childHeight}, bounds=($right, $bottom)")
                    
                    maxWidth = maxOf(maxWidth, right)
                    maxHeight = maxOf(maxHeight, bottom)
                }
                Log.d(TAG, "📊 Calculated max bounds: ${maxWidth}x${maxHeight}")
            } else {
                // Fallback: if no content container or no children, use ScrollView's own size
                maxWidth = width
                maxHeight = height
                Log.d(TAG, "⚠️ No children found, using ScrollView size: ${maxWidth}x${maxHeight}")
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
            
            // For vertical scrolling: width = ScrollView width (fill), height = max content height
            // For horizontal scrolling: width = max content width, height = ScrollView height (fill)
            val availableWidth = if (width > 0) width else measuredWidth
            val availableHeight = if (height > 0) height else measuredHeight
            
            // CRITICAL: For vertical scrolling, width must match ScrollView width exactly (fill it)
            // Height should be the max content height (not ScrollView height) to allow scrolling
            val finalContentWidth = if (isHorizontal) maxOf(availableWidth, maxWidth) else availableWidth
            // CRITICAL: For vertical scrolling, height MUST be the max content height (maxHeight), not ScrollView height
            // This ensures all content is scrollable. Content can be shorter or taller than viewport.
            val finalContentHeight = if (isHorizontal) availableHeight else maxHeight
            
            Log.d(TAG, "✅ Final content size: ${finalContentWidth}x${finalContentHeight} (available=${availableWidth}x${availableHeight}, max=${maxWidth}x${maxHeight})")
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
        // Store the content size so we can restore it after layout passes
        lastSetContentSize = Pair(width, height)
        
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null) {
            val layoutParams = contentView.layoutParams as? android.view.ViewGroup.LayoutParams
            if (layoutParams != null) {
                val oldWidth = layoutParams.width
                val oldHeight = layoutParams.height
                // Only update if size actually changed
                if (layoutParams.width != width || layoutParams.height != height) {
                    Log.d(TAG, "📦 setContentSize: Updating from ${oldWidth}x${oldHeight} to ${width}x${height}")
                    layoutParams.width = width
                    layoutParams.height = height
                    contentView.layoutParams = layoutParams
                    
                    // CRITICAL: Force remeasure and relayout of the container
                    // NestedScrollView needs to remeasure its child when layoutParams change
                    contentView.measure(
                        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
                    )
                    
                    // CRITICAL: Request layout on both container and ScrollView
                    // This ensures NestedScrollView re-lays out its child with the new size
                    contentView.requestLayout()
                    this@DCFScrollableView.requestLayout()
                    
                    Log.d(TAG, "✅ setContentSize: Updated container to ${width}x${height}, measured=${contentView.measuredWidth}x${contentView.measuredHeight}, layoutParams=${contentView.layoutParams.width}x${contentView.layoutParams.height}")
                } else {
                    Log.d(TAG, "⏭️ setContentSize: Size unchanged (${width}x${height}), skipping")
                }
            } else {
                Log.w(TAG, "⚠️ setContentSize: contentView.layoutParams is null")
            }
        } else {
            Log.w(TAG, "⚠️ setContentSize: contentView is null")
        }
        
        // Notify Dart side of content size update
        notifyContentSizeUpdate(width, height)
    }
    
    /**
     * Notify Dart side of content size updates through propagateEvent
     * Matches iOS notifyContentSizeUpdate() behavior
     */
    private fun notifyContentSizeUpdate(width: Int, height: Int) {
        // Only propagate event if there are registered listeners
        val eventTypes = getTag(DCFTags.EVENT_TYPES_KEY) as? Set<String>
        if (eventTypes != null && (eventTypes.contains("onContentSizeChange") || eventTypes.contains("contentSizeChange"))) {
            propagateEvent(this, "onContentSizeChange", mapOf(
                "contentSize" to mapOf(
                    "width" to width.toDouble(),
                    "height" to height.toDouble()
                )
            ))
        }
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        
        // CRITICAL: If content container has explicit height, ensure it's measured correctly
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null && contentView.layoutParams.height > 0 && 
            contentView.layoutParams.height != ViewGroup.LayoutParams.WRAP_CONTENT &&
            contentView.layoutParams.height != ViewGroup.LayoutParams.MATCH_PARENT) {
            // Container has explicit height - remeasure it
            val containerWidth = measuredWidth - paddingLeft - paddingRight
            val containerHeight = contentView.layoutParams.height
            contentView.measure(
                View.MeasureSpec.makeMeasureSpec(containerWidth, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(containerHeight, View.MeasureSpec.EXACTLY)
            )
        }
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        // CRITICAL: After super.onLayout(), restore container size if it has a fixed height
        // This ensures the container maintains its correct size across hot restarts and state changes
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null) {
            val layoutParams = contentView.layoutParams
            val hasFixedHeight = layoutParams.height > 0 && 
                layoutParams.height != ViewGroup.LayoutParams.WRAP_CONTENT &&
                layoutParams.height != ViewGroup.LayoutParams.MATCH_PARENT
            
            // If we have a stored size, use it; otherwise use layoutParams if it's a fixed value
            val targetSize = if (lastSetContentSize != null) {
                lastSetContentSize!!
            } else if (hasFixedHeight) {
                Pair(layoutParams.width, layoutParams.height)
            } else {
                null
            }
            
            if (targetSize != null) {
                val (targetWidth, targetHeight) = targetSize
                
                // Check if container's layoutParams match our target size
                if (layoutParams.width != targetWidth || layoutParams.height != targetHeight) {
                    // Restore layoutParams
                    layoutParams.width = targetWidth
                    layoutParams.height = targetHeight
                    contentView.layoutParams = layoutParams
                    Log.d(TAG, "🔧 onLayout: Restored container layoutParams to ${targetWidth}x${targetHeight}")
                }
                
                // Always ensure container is laid out with the correct size
                val containerWidth = width - paddingLeft - paddingRight
                val containerHeight = targetHeight
                if (contentView.width != containerWidth || contentView.height != containerHeight) {
                    contentView.measure(
                        View.MeasureSpec.makeMeasureSpec(containerWidth, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(containerHeight, View.MeasureSpec.EXACTLY)
                    )
                    contentView.layout(
                        paddingLeft,
                        paddingTop,
                        paddingLeft + containerWidth,
                        paddingTop + containerHeight
                    )
                    Log.d(TAG, "🔧 onLayout: Forced container layout to ${containerWidth}x${containerHeight} (was ${contentView.width}x${contentView.height})")
                }
            } else if (lastSetContentSize == null && childCount > 0) {
                // CRITICAL: After hot restart, if we don't have a stored size but have children,
                // trigger content size update to recalculate and set the size
                post {
                    if (lastSetContentSize == null && childCount > 0) {
                        Log.d(TAG, "🔄 onLayout: No stored size after hot restart, triggering content size update")
                        updateContentSizeFromYogaLayout()
                    }
                }
            }
        }
        
        // CRITICAL: NestedScrollView.onLayout() automatically lays out its direct child (the container)
        // We don't need to manually lay it out - that would reset children positions to (0, 0)
        // Just ensure content size is updated after Yoga has laid out all children
        
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

