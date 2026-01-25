/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
        
        // CRITICAL: Check for pendingFrame from Yoga FIRST (matches iOS behavior)
        // iOS uses contentView.frame.size directly because it's set by applyLayout BEFORE layoutSubviews
        // On Android, we need to use pendingFrame during onMeasure() because NestedScrollView
        // calls onMeasure() BEFORE layout, but applyLayout() sets pendingFrame before measurement
        // This is the key fix - use Yoga's calculated size if available, fall back to measuring children
        val pendingFrameKey = "pendingFrame".hashCode()
        val pendingFrame = getTag(pendingFrameKey) as? android.graphics.Rect
        
        // If we have a valid pendingFrame from Yoga, use it directly (matches iOS exactly)
        // This ensures we report the correct size even if children haven't been measured yet
        if (pendingFrame != null && pendingFrame.width() > 0 && pendingFrame.height() > 0) {
            val measuredWidth = when (widthMode) {
                android.view.View.MeasureSpec.EXACTLY -> widthSize
                android.view.View.MeasureSpec.AT_MOST -> kotlin.math.min(pendingFrame.width(), widthSize)
                else -> pendingFrame.width()
            }
            
            val measuredHeight = when (heightMode) {
                android.view.View.MeasureSpec.EXACTLY -> heightSize
                android.view.View.MeasureSpec.AT_MOST -> kotlin.math.min(pendingFrame.height(), heightSize)
                else -> pendingFrame.height()
            }
            
            
            // CRITICAL: Set expectedContentHeight on parent NestedScrollView
            // Only set if different to prevent layout loops
            if (measuredHeight > 0) {
                var parentView: android.view.ViewParent? = parent
                while (parentView != null) {
                    if (parentView is androidx.core.widget.NestedScrollView) {
                        val scrollView = parentView as androidx.core.widget.NestedScrollView
                        if (scrollView is com.dotcorr.dcflight.components.DCFCustomScrollView) {
                            val customScrollView = scrollView as com.dotcorr.dcflight.components.DCFCustomScrollView
                            // Only set if different - prevents infinite loops
                            if (customScrollView.expectedContentHeight != measuredHeight) {
                                customScrollView.expectedContentHeight = measuredHeight
                            }
                        }
                        break
                    }
                    parentView = parentView.parent
                }
            }
            
            setMeasuredDimension(measuredWidth, measuredHeight)
            return
        }
        
        // FALLBACK: Measure children if pendingFrame is not available
        // This happens when NestedScrollView.onMeasure() is called BEFORE applyLayout() sets pendingFrame
        // CRITICAL: Make all children visible BEFORE measuring (React Native approach)
        // Children are set to INVISIBLE during attachView to prevent flash
        // But we need them visible for accurate measurement
        // CRITICAL: Also ensure children have proper layout params before measuring
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility == android.view.View.INVISIBLE) {
                child.visibility = android.view.View.VISIBLE
                child.alpha = 1.0f
            }
            // CRITICAL: Ensure child has layout params - without them, measurement will fail
            if (child.layoutParams == null) {
                child.layoutParams = ViewGroup.MarginLayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
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
        
        
        // CRITICAL FIX: Set expectedContentHeight on parent NestedScrollView if not already set
        // 🔥 CRITICAL: Set expectedContentHeight on parent NestedScrollView
        // This ensures that if NestedScrollView measures again, it will use the correct height
        // This is especially important when onMeasure() is called BEFORE pendingFrame is set
        // Only set if different to prevent layout loops
        if (measuredHeight > 0) {
            var parentView: android.view.ViewParent? = parent
            while (parentView != null) {
                if (parentView is androidx.core.widget.NestedScrollView) {
                    val scrollView = parentView as androidx.core.widget.NestedScrollView
                    if (scrollView is com.dotcorr.dcflight.components.DCFCustomScrollView) {
                        val customScrollView = scrollView as com.dotcorr.dcflight.components.DCFCustomScrollView
                        // CRITICAL: Always set if expectedContentHeight is 0 (initial measurement)
                        // This ensures we have SOME height even if pendingFrame isn't available yet
                        // This fixes the red background issue when navigating to examples
                        if (customScrollView.expectedContentHeight == 0) {
                            customScrollView.expectedContentHeight = measuredHeight
                            android.util.Log.d("DCFScrollContentView", "✅ onMeasure (fallback): Set expectedContentHeight=$measuredHeight from measured children (initial measurement, pendingFrame not available)")
                        } else if (customScrollView.expectedContentHeight != measuredHeight) {
                            // Only update if significantly different (more than 10% difference)
                            // This prevents layout loops while still allowing updates
                            val difference = kotlin.math.abs(customScrollView.expectedContentHeight - measuredHeight)
                            val threshold = customScrollView.expectedContentHeight / 10
                            if (difference > threshold) {
                                customScrollView.expectedContentHeight = measuredHeight
                                android.util.Log.d("DCFScrollContentView", "✅ onMeasure (fallback): Updated expectedContentHeight=$measuredHeight from measured children (significant change, pendingFrame not available)")
                            }
                        }
                    }
                    break
                }
                parentView = parentView.parent
            }
        } else if (measuredHeight == 0 && childCount > 0) {
            // CRITICAL: If we measured to 0 but have children, something is wrong
            // This can happen if children are invisible or not properly set up
            // Log a warning but don't set expectedContentHeight to 0 (keep previous value if any)
            android.util.Log.w("DCFScrollContentView", "⚠️ onMeasure (fallback): Measured to 0 height but have $childCount children - children may not be visible or properly set up")
        }
        
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


