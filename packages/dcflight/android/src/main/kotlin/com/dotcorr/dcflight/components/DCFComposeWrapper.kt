/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.compose.ui.platform.ComposeView

/**
 * Wrapper ViewGroup that prevents ComposeView from requesting layout during content-only updates.
 * 
 * This eliminates flickering by preventing double layout passes when only content changes.
 * Layout requests are only allowed when layout props (width, height, margin, padding) change.
 * 
 * Usage:
 * ```kotlin
 * val composeView = ComposeView(context)
 * val wrapper = DCFComposeWrapper(context, composeView)
 * // Use wrapper instead of composeView
 * ```
 */
class DCFComposeWrapper(
    context: Context,
    val composeView: ComposeView
) : ViewGroup(context) {
    private var allowLayoutRequests = true
    private var resetRunnable: Runnable? = null
    
    init {
        addView(composeView, LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }
    
    /**
     * Controls whether layout requests are allowed.
     * Set to false during content-only updates to prevent unnecessary layout passes.
     * The flag is automatically reset after the current frame.
     */
    fun setAllowLayoutRequests(allow: Boolean) {
        resetRunnable?.let { removeCallbacks(it) }
        resetRunnable = null
        allowLayoutRequests = allow
        
        if (!allow) {
            resetRunnable = Runnable {
                allowLayoutRequests = true
            }
            post(resetRunnable!!)
        }
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        composeView.measure(widthMeasureSpec, heightMeasureSpec)
        setMeasuredDimension(composeView.measuredWidth, composeView.measuredHeight)
    }
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        composeView.layout(0, 0, r - l, b - t)
    }
    
    override fun requestLayout() {
        if (allowLayoutRequests) {
            super.requestLayout()
        }
    }
    
    override fun invalidate() {
        super.invalidate()
    }
}

