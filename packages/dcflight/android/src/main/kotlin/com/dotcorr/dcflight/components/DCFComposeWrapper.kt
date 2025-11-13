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
    
    // Track if ComposeView has been composed and is ready
    @Volatile
    private var isCompositionReady = false
    
    init {
        addView(composeView, LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }
    
    /**
     * Mark that ComposeView has been composed and is ready
     */
    fun markCompositionReady() {
        isCompositionReady = true
    }
    
    /**
     * Check if ComposeView composition is ready
     */
    fun isCompositionReady(): Boolean {
        return isCompositionReady
    }
    
    /**
     * Force composition to complete by requesting layout and measuring
     * This ensures ComposeView is ready before layout calculation
     * 
     * Note: ComposeView.setContent is async, so we can't force it to be truly synchronous.
     * However, we can trigger a layout pass which helps ComposeView compose faster.
     */
    fun ensureCompositionReady() {
        if (!isCompositionReady && composeView.parent != null) {
            // Force a layout pass to trigger composition
            // This helps ComposeView compose faster, though it's still async
            composeView.requestLayout()
            
            // Try to measure to trigger composition
            // Use a reasonable constraint to allow ComposeView to measure properly
            val maxWidth = 10000
            composeView.measure(
                android.view.View.MeasureSpec.makeMeasureSpec(maxWidth, android.view.View.MeasureSpec.AT_MOST),
                android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED)
            )
            
            // Mark as ready if measurement succeeded
            // Even if measurement returns 0, we mark as ready to avoid infinite loops
            // The fallback estimate in getIntrinsicSize will handle the 0 case
            if (composeView.measuredWidth > 0 || composeView.measuredHeight > 0) {
                isCompositionReady = true
            } else {
                // Still mark as ready to prevent blocking - fallback will handle it
                isCompositionReady = true
            }
        } else if (isCompositionReady) {
            // Already ready - ensure it's still valid by re-measuring
            composeView.requestLayout()
        }
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

