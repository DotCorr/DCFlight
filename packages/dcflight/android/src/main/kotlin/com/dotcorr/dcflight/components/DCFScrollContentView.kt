/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.AttributeSet
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFFrameLayout

/**
 * DCFScrollContentView - Content view wrapper
 * This is a simple ViewGroup that serves as the container for ScrollView's children.
 * Yoga will layout this view and its children, and the ScrollView will use its
 * frame.size as the contentSize.
 * 
 * CRITICAL: This view does NOT automatically layout its children - Yoga handles all layout.
 * This matches iOS behavior where UIView doesn't automatically layout subviews.
 * 
 * CRITICAL: This view must report its size correctly during measurement so NestedScrollView
 * can determine the scrollable content size. We use the size calculated by Yoga (stored in
 * the frame or pendingFrame) rather than trying to measure children ourselves.
 */
class DCFScrollContentView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : DCFFrameLayout(context, attrs, defStyleAttr) {
    
    companion object {
        private const val TAG = "DCFScrollContentView"
    }
    
    init {
        // Don't clip content - allow children to be positioned outside bounds (negative coordinates)
        clipToPadding = false
        clipChildren = false
    }
    
    /**
     * CRITICAL: Override onMeasure to match React Native's ReactViewGroup behavior exactly
     * 
     * React Native's approach (ReactViewGroup.onMeasure):
     * - ALWAYS measure children during onMeasure() (standard Android measurement)
     * - Sum children's sizes to determine content view size
     * - Yoga positions children during layout (after measurement)
     * - Content view size is determined by measuring children, not by Yoga's calculated size
     * 
     * KEY DIFFERENCE FROM iOS:
     * - iOS: UIScrollView reads contentView.frame.size AFTER layout (in layoutSubviews)
     * - Android: NestedScrollView calls onMeasure() DURING measurement, BEFORE layout
     * 
     * React Native's ReactViewGroup:
     * - onMeasure() measures children and reports their total size
     * - onLayout() is overridden to do nothing (Yoga handles layout)
     * - Children are positioned by Yoga during layout, but size is already determined
     * 
     * This matches React Native's behavior exactly - we measure children first,
     * then Yoga positions them later. We don't rely on Yoga's calculated size during measurement.
     */
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val widthMode = android.view.View.MeasureSpec.getMode(widthMeasureSpec)
        val widthSize = android.view.View.MeasureSpec.getSize(widthMeasureSpec)
        val heightMode = android.view.View.MeasureSpec.getMode(heightMeasureSpec)
        val heightSize = android.view.View.MeasureSpec.getSize(heightMeasureSpec)
        
        // CRITICAL: Make all children visible BEFORE measuring (React Native approach)
        // Children are set to INVISIBLE during attachView to prevent flash
        // But we need them visible for accurate measurement
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility == android.view.View.INVISIBLE) {
                child.visibility = android.view.View.VISIBLE
                child.alpha = 1.0f
            }
        }
        
        // Measure width (React Native approach - always measure children)
        val measuredWidth = when (widthMode) {
            android.view.View.MeasureSpec.EXACTLY -> widthSize
            android.view.View.MeasureSpec.AT_MOST -> {
                // Measure children to determine width
                var maxChildWidth = 0
                for (i in 0 until childCount) {
                    val child = getChildAt(i)
                    if (child.visibility != android.view.View.GONE) {
                        val childLayoutParams = child.layoutParams ?: ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                        val childWidthMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            widthMeasureSpec,
                            paddingLeft + paddingRight,
                            childLayoutParams.width
                        )
                        val childHeightMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
                            paddingTop + paddingBottom,
                            childLayoutParams.height
                        )
                        child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
                        maxChildWidth = kotlin.math.max(maxChildWidth, child.measuredWidth)
                    }
                }
                kotlin.math.min(maxChildWidth + paddingLeft + paddingRight, widthSize)
            }
            else -> {
                // UNSPECIFIED - measure children
                var maxChildWidth = 0
                for (i in 0 until childCount) {
                    val child = getChildAt(i)
                    if (child.visibility != android.view.View.GONE) {
                        val childLayoutParams = child.layoutParams ?: ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                        val childWidthMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            widthMeasureSpec,
                            paddingLeft + paddingRight,
                            childLayoutParams.width
                        )
                        val childHeightMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
                            paddingTop + paddingBottom,
                            childLayoutParams.height
                        )
                        child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
                        maxChildWidth = kotlin.math.max(maxChildWidth, child.measuredWidth)
                    }
                }
                maxChildWidth + paddingLeft + paddingRight
            }
        }
        
        // Measure height (React Native approach - always measure children, sum heights for vertical scrolling)
        val measuredHeight = when (heightMode) {
            android.view.View.MeasureSpec.EXACTLY -> heightSize
            android.view.View.MeasureSpec.AT_MOST -> {
                // Measure children to determine height
                // For vertical scrolling, sum children's heights (they stack vertically)
                var totalHeight = 0
                for (i in 0 until childCount) {
                    val child = getChildAt(i)
                    if (child.visibility != android.view.View.GONE) {
                        val childLayoutParams = child.layoutParams ?: ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                        val childWidthMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(measuredWidth, android.view.View.MeasureSpec.EXACTLY),
                            paddingLeft + paddingRight,
                            childLayoutParams.width
                        )
                        val childHeightMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
                            paddingTop + paddingBottom,
                            childLayoutParams.height
                        )
                        child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
                        totalHeight += child.measuredHeight
                    }
                }
                kotlin.math.min(totalHeight + paddingTop + paddingBottom, heightSize)
            }
            else -> {
                // UNSPECIFIED - measure children
                var totalHeight = 0
                for (i in 0 until childCount) {
                    val child = getChildAt(i)
                    if (child.visibility != android.view.View.GONE) {
                        val childLayoutParams = child.layoutParams ?: ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                        val childWidthMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(measuredWidth, android.view.View.MeasureSpec.EXACTLY),
                            paddingLeft + paddingRight,
                            childLayoutParams.width
                        )
                        val childHeightMeasureSpec = android.view.ViewGroup.getChildMeasureSpec(
                            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
                            paddingTop + paddingBottom,
                            childLayoutParams.height
                        )
                        child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
                        totalHeight += child.measuredHeight
                    }
                }
                totalHeight + paddingTop + paddingBottom
            }
        }
        
        android.util.Log.d(TAG, "🔍 onMeasure (React Native mode): Measured size: width=$measuredWidth, height=$measuredHeight (childCount=$childCount, widthMode=$widthMode, heightMode=$heightMode)")
        
        setMeasuredDimension(measuredWidth, measuredHeight)
    }
    
    /**
     * CRITICAL: Override onLayout to NOT layout children automatically
     * Yoga handles all child layout - we just need to ensure this view itself is laid out
     * This matches iOS behavior where UIView doesn't automatically layout subviews
     */
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        // CRITICAL: Don't call super.onLayout() - that would layout children using FrameLayout's default behavior
        // Yoga has already laid out all children with their correct positions
        // We just need to ensure this view's own bounds are set (which is already done by the parent)
        // This matches iOS where UIView.onLayout() doesn't automatically position subviews
    }
}


