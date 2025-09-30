/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout

/**
 * Custom FrameLayout that respects manual layout() calls
 * This matches iOS behavior where frame assignments are respected exactly
 */
class DCFFrameLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    companion object {
        private const val TAG = "DCFFrameLayout"
    }

    // Track manually positioned children
    private val manuallyPositionedChildren = mutableSetOf<View>()

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        // Don't call super.onLayout() - we want full control like iOS
        
        // For each child, check if it has been manually positioned
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            
            // If this child was manually positioned via layout(), respect that
            if (manuallyPositionedChildren.contains(child)) {
                // Child is already positioned manually - don't override
                continue
            }
            
            // For children not manually positioned, use default FrameLayout behavior
            val lp = child.layoutParams as FrameLayout.LayoutParams
            val childLeft = paddingLeft + lp.leftMargin
            val childTop = paddingTop + lp.topMargin
            val childRight = childLeft + child.measuredWidth
            val childBottom = childTop + child.measuredHeight
            
            child.layout(childLeft, childTop, childRight, childBottom)
        }
    }

    /**
     * Mark a child as manually positioned - its layout() calls should be respected
     */
    fun setChildManuallyPositioned(child: View, isManual: Boolean) {
        if (isManual) {
            manuallyPositionedChildren.add(child)
        } else {
            manuallyPositionedChildren.remove(child)
        }
    }

    /**
     * Check if a child is manually positioned
     */
    fun isChildManuallyPositioned(child: View): Boolean {
        return manuallyPositionedChildren.contains(child)
    }

    override fun removeView(view: View?) {
        view?.let { manuallyPositionedChildren.remove(it) }
        super.removeView(view)
    }

    override fun removeViewAt(index: Int) {
        if (index >= 0 && index < childCount) {
            val child = getChildAt(index)
            manuallyPositionedChildren.remove(child)
        }
        super.removeViewAt(index)
    }

    override fun removeAllViews() {
        manuallyPositionedChildren.clear()
        super.removeAllViews()
    }
}
