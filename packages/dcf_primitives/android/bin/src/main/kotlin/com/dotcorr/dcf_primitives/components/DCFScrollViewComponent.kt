/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.widget.NestedScrollView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import android.util.AttributeSet
import com.dotcorr.dcflight.components.DCFFrameLayout

/**
 * Custom FrameLayout for ScrollView content container
 * Extends DCFFrameLayout to respect manually positioned children (positioned by Yoga)
 */
class ScrollContentContainer @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : DCFFrameLayout(context, attrs, defStyleAttr) {
    
    companion object {
        private const val TAG = "ScrollContentContainer"
    }
    
    // Inherits all functionality from DCFFrameLayout
}

/**
 * ScrollView component for Android
 * Matches iOS DCFScrollViewComponent behavior
 */
class DCFScrollViewComponent : DCFComponent() {
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val scrollView = DCFScrollableView(context)
        
        scrollView.setTag(DCFTags.COMPONENT_TYPE_KEY, "ScrollView")
        
        // Create content container (FrameLayout to hold children)
        val contentContainer = ScrollContentContainer(context)
        val containerParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        contentContainer.layoutParams = containerParams
        contentContainer.visibility = View.VISIBLE
        contentContainer.clipToPadding = false
        contentContainer.clipChildren = false
        scrollView.addView(contentContainer)
        scrollView.setContentContainer(contentContainer) // Register with ScrollView
        
        // Set up scroll listener for events
        scrollView.viewTreeObserver.addOnScrollChangedListener {
            val scrollX = scrollView.scrollX
            val scrollY = scrollView.scrollY
            val contentView = scrollView.getChildAt(0)
            
            // Only propagate event if there are registered listeners
            val eventTypes = scrollView.getTag(DCFTags.EVENT_TYPES_KEY) as? Set<String>
            if (eventTypes != null && (eventTypes.contains("onScroll") || eventTypes.contains("scroll"))) {
                // Match iOS event format exactly
                propagateEvent(scrollView, "onScroll", mapOf(
                    "contentOffset" to mapOf(
                        "x" to scrollX.toDouble(),
                        "y" to scrollY.toDouble()
                    ),
                    "contentSize" to mapOf(
                        "width" to (contentView?.width?.toDouble() ?: 0.0),
                        "height" to (contentView?.height?.toDouble() ?: 0.0)
                    ),
                    "layoutMeasurement" to mapOf(
                        "width" to scrollView.width.toDouble(),
                        "height" to scrollView.height.toDouble()
                    )
                ))
            }
            
            // CRITICAL: Built-in viewport detection - check all observed views in this scroll view
            com.dotcorr.dcflight.utils.DCFViewportObserver.checkViewsInScrollView(scrollView)
        }
        
        // Handle scroll begin/end drag events
        scrollView.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    propagateEvent(scrollView, "onScrollBeginDrag", mapOf(
                        "contentOffset" to mapOf(
                            "x" to scrollView.scrollX.toDouble(),
                            "y" to scrollView.scrollY.toDouble()
                        )
                    ))
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    propagateEvent(scrollView, "onScrollEndDrag", mapOf(
                        "contentOffset" to mapOf(
                            "x" to scrollView.scrollX.toDouble(),
                            "y" to scrollView.scrollY.toDouble()
                        ),
                        "willDecelerate" to (scrollView.canScrollVertically(1) || scrollView.canScrollVertically(-1))
                    ))
                    
                    // Also fire onScrollEnd after a delay (when deceleration stops)
                    scrollView.postDelayed({
                        propagateEvent(scrollView, "onScrollEnd", mapOf(
                            "contentOffset" to mapOf(
                                "x" to scrollView.scrollX.toDouble(),
                                "y" to scrollView.scrollY.toDouble()
                            )
                        ))
                    }, 100)
                }
            }
            false // Don't consume the event, let ScrollView handle it
        }
        
        updateView(scrollView, props)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        scrollView.applyStyles(nonNullProps)
        
        return scrollView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val scrollView = view as? DCFScrollableView ?: return false
        
        // CRITICAL: Merge new props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Scroll indicator
        mergedProps["showsScrollIndicator"]?.let {
            val shows = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            scrollView.isVerticalScrollBarEnabled = shows
            scrollView.isHorizontalScrollBarEnabled = shows
        }
        
        // Tertiary color for scroll indicator
        mergedProps["tertiaryColor"]?.let { colorStr ->
            if (colorStr is String) {
                val color = ColorUtilities.parseColor(colorStr)
                scrollView.setTag(DCFPrimitiveTags.SCROLL_INDICATOR_COLOR_KEY, color)
            }
        }
        
        // Scroll indicator size
        mergedProps["scrollIndicatorSize"]?.let {
            scrollView.setTag(DCFPrimitiveTags.SCROLL_INDICATOR_SIZE_KEY, it)
        }
        
        // Bounces
        mergedProps["bounces"]?.let {
            val bounces = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            scrollView.isSmoothScrollingEnabled = bounces
            scrollView.overScrollMode = if (bounces) View.OVER_SCROLL_ALWAYS else View.OVER_SCROLL_NEVER
        }
        
        // Horizontal scrolling
        mergedProps["horizontal"]?.let {
            val horizontal = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            scrollView.isHorizontal = horizontal
        }
        
        // Paging enabled
        mergedProps["pagingEnabled"]?.let {
            val paging = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            scrollView.setTag(DCFPrimitiveTags.PAGING_ENABLED_KEY, paging)
        }
        
        // Scroll enabled
        mergedProps["scrollEnabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            scrollView.isNestedScrollingEnabled = enabled
        }
        
        // Clips to bounds
        mergedProps["clipsToBounds"]?.let {
            val clips = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            scrollView.clipToPadding = clips
            scrollView.clipChildren = clips
        }
        
        // Background color
        mergedProps["backgroundColor"]?.let { bgColor ->
            if (bgColor is String) {
                val color = ColorUtilities.parseColor(bgColor)
                scrollView.setBackgroundColor(color)
            }
        }
        
        // Border radius
        mergedProps["borderRadius"]?.let {
            val radius = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            scrollView.setTag(DCFPrimitiveTags.BORDER_RADIUS_KEY, radius)
        }
        
        // Border width
        mergedProps["borderWidth"]?.let {
            val width = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            scrollView.setTag(DCFPrimitiveTags.BORDER_WIDTH_KEY, width)
        }
        
        // Border color
        mergedProps["borderColor"]?.let { colorStr ->
            if (colorStr is String) {
                val color = ColorUtilities.parseColor(colorStr)
                scrollView.setTag(DCFPrimitiveTags.BORDER_COLOR_KEY, color)
            }
        }
        
        // Opacity
        mergedProps["opacity"]?.let {
            val opacity = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 1f
                else -> 1f
            }
            scrollView.alpha = opacity
        }
        
        // Virtualized content offset start
        mergedProps["contentOffsetStart"]?.let {
            val offset = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            if (offset > 0) {
                scrollView.virtualizedContentOffsetStart = offset
            }
        }
        
        // Virtualized content padding top
        mergedProps["contentPaddingTop"]?.let {
            val padding = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            if (padding > 0) {
                scrollView.virtualizedContentPaddingTop = padding
            }
        }
        
        // Handle commands
        handleCommand(scrollView, mergedProps)
        
        scrollView.applyStyles(nonNullProps)
        
        return true
    }
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        val scrollView = view as? DCFScrollableView ?: return
        
        // Apply layout to ScrollView itself
        scrollView.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        
        // Update content size after layout
        scrollView.post {
            scrollView.updateContentSizeFromYogaLayout()
            
            // Also trigger viewport check after content size update
            com.dotcorr.dcflight.utils.DCFViewportObserver.checkViewsInScrollView(scrollView)
        }
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val scrollView = view as? DCFScrollableView
        scrollView?.nodeId = nodeId
        
        // Update content size after registration
        scrollView?.post {
            scrollView.updateContentSizeFromYogaLayout()
        }
    }
    
    /**
     * Handle commands passed as props
     */
    private fun handleCommand(scrollView: DCFScrollableView, props: Map<String, Any?>) {
        val commandData = props["command"] as? Map<String, Any?> ?: return
        
        // Scroll to position
        commandData["scrollToPosition"]?.let { data ->
            if (data is Map<*, *>) {
                val x = (data["x"] as? Number)?.toDouble() ?: 0.0
                val y = (data["y"] as? Number)?.toDouble() ?: 0.0
                val animated = (data["animated"] as? Boolean) ?: true
                
                if (animated) {
                    scrollView.smoothScrollTo(x.toInt(), y.toInt())
                } else {
                    scrollView.scrollTo(x.toInt(), y.toInt())
                }
            }
        }
        
        // Scroll to top
        commandData["scrollToTop"]?.let { data ->
            if (data is Map<*, *>) {
                val animated = (data["animated"] as? Boolean) ?: true
                if (animated) {
                    scrollView.smoothScrollTo(0, 0)
                } else {
                    scrollView.scrollTo(0, 0)
                }
            }
        }
        
        // Scroll to bottom
        commandData["scrollToBottom"]?.let { data ->
            if (data is Map<*, *>) {
                val animated = (data["animated"] as? Boolean) ?: true
                val contentView = scrollView.getChildAt(0)
                val bottomY = if (contentView != null) {
                    contentView.height - scrollView.height
                } else {
                    0
                }
                if (animated) {
                    scrollView.smoothScrollTo(0, bottomY)
                } else {
                    scrollView.scrollTo(0, bottomY)
                }
            }
        }
        
        // Flash scroll indicators
        commandData["flashScrollIndicators"]?.let {
            if (it is Boolean && it) {
                scrollView.isVerticalScrollBarEnabled = true
                scrollView.postDelayed({
                    // Scrollbars will auto-hide
                }, 2000)
            }
        }
        
        // Update content size
        commandData["updateContentSize"]?.let {
            if (it is Boolean && it) {
                scrollView.updateContentSizeFromYogaLayout()
            }
        }
        
        // Set explicit content size
        commandData["setContentSize"]?.let { data ->
            if (data is Map<*, *>) {
                val width = (data["width"] as? Number)?.toInt() ?: 0
                val height = (data["height"] as? Number)?.toInt() ?: 0
                scrollView.setExplicitContentSize(width, height)
            }
        }
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f) // ScrollView has no intrinsic size
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}
