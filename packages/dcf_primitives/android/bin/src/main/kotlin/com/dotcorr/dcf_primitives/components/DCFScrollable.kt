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
    private var isUpdatingContentSize: Boolean = false // Prevent redundant calculations
    
    // Content container for children (NestedScrollView can only have one direct child)
    private var contentContainer: FrameLayout? = null
    
    init {
        setupDCFScrollableView()
    }
    
    private fun setupDCFScrollableView() {
        clipToPadding = true
        clipChildren = true
        
        // Prevent ScrollView from auto-scrolling to focused child on initial layout
        descendantFocusability = ViewGroup.FOCUS_BEFORE_DESCENDANTS
        isFocusable = true
        isFocusableInTouchMode = true
        
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
     * Update content size based on Yoga layout results
     * 
     * Simplified approach:
     * 1. The content container (FrameLayout) holds all children.
     * 2. Children are positioned by Yoga.
     * 3. We just need to ensure the container is large enough to hold them.
     * 4. NestedScrollView automatically handles scrolling if the child is larger than itself.
     */
    fun updateContentSizeFromYogaLayout() {
        if (isUpdatingContentSize) {
            return
        }
        isUpdatingContentSize = true
        
        post {
            try {
                if (explicitContentSize != null) {
                    val (width, height) = explicitContentSize!!
                    setContentSize(width, height)
                    return@post
                }
                
                val contentView = getChildAt(0) as? FrameLayout ?: return@post
                
                // Calculate max bounds from children's actual positions
                var maxWidth = 0
                var maxHeight = 0
                
                for (i in 0 until contentView.childCount) {
                    val child = contentView.getChildAt(i)
                    if (child.visibility != View.GONE) {
                        val right = child.left + child.width
                        val bottom = child.top + child.height
                        maxWidth = maxOf(maxWidth, right)
                        maxHeight = maxOf(maxHeight, bottom)
                    }
                }
                
                // Add padding
                maxWidth += contentView.paddingRight
                maxHeight += contentView.paddingBottom
                
                setContentSize(maxWidth, maxHeight)
                
            } finally {
                isUpdatingContentSize = false
            }
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
     * Updates the content container's size so ScrollView knows how much to scroll
     */
    private fun setContentSize(width: Int, height: Int) {
        val contentView = getChildAt(0) as? FrameLayout
        if (contentView != null) {
            val layoutParams = contentView.layoutParams
            if (layoutParams != null) {
                if (layoutParams.width != width || layoutParams.height != height) {
                    layoutParams.width = width
                    layoutParams.height = height
                    contentView.layoutParams = layoutParams
                    
                    // Request layout to apply changes
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
    
    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        // Clear explicit content size on configuration change (orientation, etc.)
        explicitContentSize = null
    }
}
