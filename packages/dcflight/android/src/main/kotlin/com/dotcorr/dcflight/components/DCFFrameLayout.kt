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
open class DCFFrameLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    companion object {
        private const val TAG = "DCFFrameLayout"
    }
    
    init {
        // CRITICAL: Don't clip children to allow text with font metrics to render fully
        // Text views have ascenders/descenders that extend beyond measured bounds
        // This matches iOS behavior where parent views don't clip text children
        clipChildren = false
        clipToPadding = false
    }

    private val manuallyPositionedChildren = mutableSetOf<View>()

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            
            if (manuallyPositionedChildren.contains(child)) {
                continue
            }
            
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
