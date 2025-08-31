/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.HorizontalScrollView
import android.widget.ScrollView
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFScrollViewComponent - Scrollable container matching iOS DCFScrollViewComponent
 */
class DCFScrollViewComponent : DCFComponent {

    override fun createView(context: Context, props: Map<String, Any>): View {
        // Determine if horizontal or vertical scroll
        val isHorizontal = props["horizontal"] as? Boolean ?: false

        val scrollView: ViewGroup = if (isHorizontal) {
            HorizontalScrollView(context).apply {
                isFillViewport = true
                isHorizontalScrollBarEnabled = props["showsHorizontalScrollIndicator"] as? Boolean ?: true
            }
        } else {
            ScrollView(context).apply {
                isFillViewport = true
                isVerticalScrollBarEnabled = props["showsVerticalScrollIndicator"] as? Boolean ?: true
            }
        }

        // Create content container
        val contentView = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        // Add content view to scroll view
        scrollView.addView(contentView)

        // Apply props
        updateView(scrollView, props)

        // Apply StyleSheet properties
        scrollView.applyStyles(props)

        // Store component type
        scrollView.setTag(R.id.dcf_component_type, "ScrollView")

        return scrollView
    }

    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        val scrollView = view as? ViewGroup ?: return false

        // Scroll enabled
        props["scrollEnabled"]?.let { enabled ->
            when (enabled) {
                is Boolean -> {
                    when (scrollView) {
                        is ScrollView -> {
                            scrollView.isVerticalScrollBarEnabled = enabled
                            scrollView.setOnTouchListener(if (enabled) null else { _, _ -> true })
                        }

                        is HorizontalScrollView -> {
                            scrollView.isHorizontalScrollBarEnabled = enabled
                            scrollView.setOnTouchListener(if (enabled) null else { _, _ -> true })
                        }
                    }
                }
            }
        }

        // Content offset
        props["contentOffset"]?.let { offset ->
            when (offset) {
                is Map<*, *> -> {
                    val x = (offset["x"] as? Number)?.toInt() ?: 0
                    val y = (offset["y"] as? Number)?.toInt() ?: 0

                    when (scrollView) {
                        is ScrollView -> scrollView.scrollTo(x, y)
                        is HorizontalScrollView -> scrollView.scrollTo(x, y)
                    }
                }
            }
        }

        // Content inset
        props["contentInset"]?.let { inset ->
            when (inset) {
                is Map<*, *> -> {
                    val top = (inset["top"] as? Number)?.toInt() ?: 0
                    val left = (inset["left"] as? Number)?.toInt() ?: 0
                    val bottom = (inset["bottom"] as? Number)?.toInt() ?: 0
                    val right = (inset["right"] as? Number)?.toInt() ?: 0

                    scrollView.setPadding(left, top, right, bottom)
                }
            }
        }

        // Scroll indicators
        props["showsVerticalScrollIndicator"]?.let { show ->
            when (show) {
                is Boolean -> {
                    if (scrollView is ScrollView) {
                        scrollView.isVerticalScrollBarEnabled = show
                    }
                }
            }
        }

        props["showsHorizontalScrollIndicator"]?.let { show ->
            when (show) {
                is Boolean -> {
                    if (scrollView is HorizontalScrollView) {
                        scrollView.isHorizontalScrollBarEnabled = show
                    }
                }
            }
        }

        // Bounces (iOS specific - Android doesn't have built-in bounce)
        props["bounces"]?.let { bounces ->
            // Store for potential custom implementation
            scrollView.setTag(R.id.dcf_scroll_bounces, bounces)
        }

        // Always bounce vertical/horizontal (iOS specific)
        props["alwaysBounceVertical"]?.let { bounce ->
            scrollView.setTag(R.id.dcf_scroll_bounce_vertical, bounce)
        }

        props["alwaysBounceHorizontal"]?.let { bounce ->
            scrollView.setTag(R.id.dcf_scroll_bounce_horizontal, bounce)
        }

        // Paging enabled
        props["pagingEnabled"]?.let { paging ->
            when (paging) {
                is Boolean -> {
                    scrollView.setTag(R.id.dcf_scroll_paging, paging)
                    // Would need custom implementation for paging behavior
                }
            }
        }

        // Scroll to top on status bar tap (iOS specific)
        props["scrollsToTop"]?.let { scrollsToTop ->
            scrollView.setTag(R.id.dcf_scroll_to_top, scrollsToTop)
        }

        // Horizontal scroll
        props["horizontal"]?.let { horizontal ->
            when (horizontal) {
                is Boolean -> {
                    scrollView.setTag(R.id.dcf_scroll_horizontal, horizontal)
                    // Note: Can't change scroll direction after creation
                }
            }
        }

        // Directional lock enabled
        props["directionalLockEnabled"]?.let { lock ->
            scrollView.setTag(R.id.dcf_scroll_directional_lock, lock)
        }

        // Deceleration rate
        props["decelerationRate"]?.let { rate ->
            when (rate) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_deceleration, rate.toFloat())
                is String -> {
                    val rateValue = when (rate) {
                        "normal" -> 0.998f
                        "fast" -> 0.99f
                        else -> 0.998f
                    }
                    scrollView.setTag(R.id.dcf_scroll_deceleration, rateValue)
                }
            }
        }

        // Indicator style (iOS specific)
        props["indicatorStyle"]?.let { style ->
            // Android doesn't have different indicator styles
            scrollView.setTag(R.id.dcf_scroll_indicator_style, style)
        }

        // Maximum/minimum zoom scale
        props["maximumZoomScale"]?.let { scale ->
            when (scale) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_max_zoom, scale.toFloat())
            }
        }

        props["minimumZoomScale"]?.let { scale ->
            when (scale) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_min_zoom, scale.toFloat())
            }
        }

        props["zoomScale"]?.let { scale ->
            when (scale) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_zoom, scale.toFloat())
            }
        }

        // Keyboard dismiss mode
        props["keyboardDismissMode"]?.let { mode ->
            when (mode) {
                "none" -> {
                    // Default behavior
                }

                "on-drag", "interactive" -> {
                    // Would need to implement scroll listener to hide keyboard
                    scrollView.setTag(R.id.dcf_scroll_keyboard_dismiss, mode)
                }
            }
        }

        // Refresh control
        props["refreshControl"]?.let { refreshControl ->
            // Would need SwipeRefreshLayout for pull-to-refresh
            scrollView.setTag(R.id.dcf_scroll_refresh_control, refreshControl)
        }

        // Content size (read-only in iOS, but we can store it)
        props["contentSize"]?.let { size ->
            when (size) {
                is Map<*, *> -> {
                    val width = (size["width"] as? Number)?.toInt()
                    val height = (size["height"] as? Number)?.toInt()
                    scrollView.setTag(R.id.dcf_scroll_content_size, Pair(width, height))
                }
            }
        }

        // Scroll event throttle
        props["scrollEventThrottle"]?.let { throttle ->
            when (throttle) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_event_throttle, throttle.toInt())
            }
        }

        // OnScroll handler
        props["onScroll"]?.let { onScroll ->
            scrollView.setTag(R.id.dcf_event_callback, onScroll)

            // Set up scroll listener
            when (scrollView) {
                is ScrollView -> {
                    scrollView.setOnScrollChangeListener { _, scrollX, scrollY, _, _ ->
                        // Would trigger callback with contentOffset
                        scrollView.setTag(R.id.dcf_scroll_content_offset, Pair(scrollX, scrollY))
                    }
                }

                is HorizontalScrollView -> {
                    scrollView.setOnScrollChangeListener { _, scrollX, scrollY, _, _ ->
                        // Would trigger callback with contentOffset
                        scrollView.setTag(R.id.dcf_scroll_content_offset, Pair(scrollX, scrollY))
                    }
                }
            }
        }

        // OnScrollBeginDrag
        props["onScrollBeginDrag"]?.let { handler ->
            scrollView.setTag(R.id.dcf_scroll_begin_drag, handler)
        }

        // OnScrollEndDrag
        props["onScrollEndDrag"]?.let { handler ->
            scrollView.setTag(R.id.dcf_scroll_end_drag, handler)
        }

        // OnMomentumScrollBegin
        props["onMomentumScrollBegin"]?.let { handler ->
            scrollView.setTag(R.id.dcf_scroll_momentum_begin, handler)
        }

        // OnMomentumScrollEnd
        props["onMomentumScrollEnd"]?.let { handler ->
            scrollView.setTag(R.id.dcf_scroll_momentum_end, handler)
        }

        // Nested scroll enabled
        props["nestedScrollEnabled"]?.let { enabled ->
            when (enabled) {
                is Boolean -> scrollView.isNestedScrollingEnabled = enabled
            }
        }

        // Scroll performance optimization
        props["removeClippedSubviews"]?.let { remove ->
            when (remove) {
                is Boolean -> {
                    // Android doesn't have direct equivalent
                    scrollView.setTag(R.id.dcf_scroll_remove_clipped, remove)
                }
            }
        }

        // Sticky headers (would need custom implementation)
        props["stickyHeaderIndices"]?.let { indices ->
            scrollView.setTag(R.id.dcf_scroll_sticky_headers, indices)
        }

        // Snap to alignment
        props["snapToAlignment"]?.let { alignment ->
            scrollView.setTag(R.id.dcf_scroll_snap_alignment, alignment)
        }

        props["snapToInterval"]?.let { interval ->
            when (interval) {
                is Number -> scrollView.setTag(R.id.dcf_scroll_snap_interval, interval.toFloat())
            }
        }

        props["snapToOffsets"]?.let { offsets ->
            scrollView.setTag(R.id.dcf_scroll_snap_offsets, offsets)
        }

        props["snapToStart"]?.let { snap ->
            when (snap) {
                is Boolean -> scrollView.setTag(R.id.dcf_scroll_snap_start, snap)
            }
        }

        props["snapToEnd"]?.let { snap ->
            when (snap) {
                is Boolean -> scrollView.setTag(R.id.dcf_scroll_snap_end, snap)
            }
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            scrollView.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            scrollView.setTag(R.id.dcf_test_id, testId)
        }

        // Store scroll data
        scrollView.setTag(R.id.dcf_scroll_data, props)

        return true
    }

    /**
     * Helper method to add child views to the scroll view's content container
     */
    fun addChildView(scrollView: View, child: View) {
        when (scrollView) {
            is ScrollView -> {
                val contentView = scrollView.getChildAt(0) as? ViewGroup
                contentView?.addView(child)
            }

            is HorizontalScrollView -> {
                val contentView = scrollView.getChildAt(0) as? ViewGroup
                contentView?.addView(child)
            }
        }
    }

    /**
     * Helper method to remove child views from the scroll view's content container
     */
    fun removeChildView(scrollView: View, child: View) {
        when (scrollView) {
            is ScrollView -> {
                val contentView = scrollView.getChildAt(0) as? ViewGroup
                contentView?.removeView(child)
            }

            is HorizontalScrollView -> {
                val contentView = scrollView.getChildAt(0) as? ViewGroup
                contentView?.removeView(child)
            }
        }
    }
}
