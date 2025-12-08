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
    
    var textFrame: Rect = Rect(0, 0, 0, 0)
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }
    
    var contentInset: Rect = Rect(0, 0, 0, 0)
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
        // Note: setClipChildren/setClipToPadding are ViewGroup methods, not available on View
        // For View, we ensure proper drawing by using StaticLayout which handles text metrics correctly
        // iOS sets clipsToBounds = false, but on Android View we can't control parent clipping
    }
    
    override fun onDraw(canvas: Canvas) {
        val layout = textLayout ?: return
        
        // CRITICAL: Match React Native's DrawTextLayout.onDraw exactly
        // React Native: canvas.translate(left, top); mLayout.draw(canvas); canvas.translate(-left, -top);
        // In our case, left/top are the padding offsets (textFrame position) relative to the view
        // The view is already positioned correctly by the layout system
        val left = textFrame.left.toFloat()
        val top = textFrame.top.toFloat()
        
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

