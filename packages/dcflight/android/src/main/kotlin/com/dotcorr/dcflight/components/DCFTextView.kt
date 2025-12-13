/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.Canvas
import android.graphics.Rect
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.AttributeSet
import android.view.View

class DCFTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {
    
    var textLayout: StaticLayout? = null
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }
    
    var textFrameLeft: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }
    
    var textFrameTop: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }
    
    init {
        setupView()
    }
    
    private fun setupView() {
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        setWillNotDraw(false)
        // CRITICAL: Set background to transparent so text is visible (matches iOS isOpaque = false)
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
        // CRITICAL: Ensure view is visible and not clipped
        visibility = View.VISIBLE
        alpha = 1.0f
        // CRITICAL: Disable clipping to match iOS clipsToBounds = false
        // Text has font metrics (ascenders/descenders) that extend beyond measured bounds
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            clipToOutline = false
        }
    }
    
    // CRITICAL: Override getClipBounds to prevent clipping (matches iOS clipsToBounds = false)
    // This allows text with font metrics (ascenders/descenders) to render fully
    // Text glyphs can extend beyond their measured bounds (ascenders above, descenders below)
    // By returning null, we disable view-level clipping, allowing full glyph rendering
    override fun getClipBounds(): android.graphics.Rect? {
        // Return null to disable clipping (matches iOS clipsToBounds = false)
        // This is critical for text rendering - fonts have metrics that extend beyond bounds
        return null
    }
    
    override fun onDraw(canvas: Canvas) {
        val layout = textLayout ?: return
        
        // CRITICAL: Match React Native's DrawTextLayout.onDraw exactly
        // React Native: canvas.translate(left, top); mLayout.draw(canvas); canvas.translate(-left, -top);
        // left/top are the padding offsets (textFrame position) relative to the view
        // The view is already positioned correctly by the layout system
        val left = textFrameLeft
        val top = textFrameTop
        
        // Save canvas state to prevent any existing transformations from affecting text drawing
        canvas.save()
        try {
            canvas.translate(left, top)
            layout.draw(canvas)
        } finally {
            canvas.restore()
        }
    }
    
    private fun getViewId(): Int? {
        // Try to get viewId from ViewRegistry
        for (viewId in com.dotcorr.dcflight.layout.ViewRegistry.shared.allViewIds) {
            val viewInfo = com.dotcorr.dcflight.layout.ViewRegistry.shared.getViewInfo(viewId)
            if (viewInfo?.view === this) {
                return viewId
            }
        }
        return null
    }
    
    override fun toString(): String {
        val superDescription = super.toString()
        val text = textLayout?.text?.toString() ?: ""
        return "$superDescription; text: $text"
    }
}

