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
        super.onDraw(canvas)
        
        val viewId = getViewId() ?: -1
        android.util.Log.d("DCFTextView", "🔍 onDraw[viewId=$viewId]: textLayout=${textLayout != null}, textFrame=$textFrame")
        android.util.Log.d("DCFTextView", "   view bounds: left=$left, top=$top, right=$right, bottom=$bottom, width=$width, height=$height")
        android.util.Log.d("DCFTextView", "   visibility=${visibility}, alpha=$alpha, isAttached=${isAttachedToWindow}")
        android.util.Log.d("DCFTextView", "   parent: ${parent?.javaClass?.simpleName}, clipChildren=${(parent as? android.view.ViewGroup)?.clipChildren}")
        
        val layout = textLayout ?: run {
            android.util.Log.w("DCFTextView", "⚠️ onDraw[viewId=$viewId]: textLayout is null, not drawing")
            return
        }
        
        // Get the paint from the layout to check text color
        val paint = layout.paint
        val textColor = paint.color
        val text = layout.text?.toString() ?: ""
        
        // CRITICAL: Ensure text color is set (default to black if not set)
        if (textColor == 0) {
            paint.color = android.graphics.Color.BLACK
            android.util.Log.w("DCFTextView", "⚠️ onDraw[viewId=$viewId]: Text color was 0, setting to BLACK")
        }
        
        android.util.Log.d("DCFTextView", "✅ onDraw[viewId=$viewId]: Drawing text='$text'")
        android.util.Log.d("DCFTextView", "   layout: width=${layout.width}, height=${layout.height}")
        android.util.Log.d("DCFTextView", "   textFrame: $textFrame")
        android.util.Log.d("DCFTextView", "   textColor: 0x${Integer.toHexString(paint.color)}")
        android.util.Log.d("DCFTextView", "   view: width=$width, height=$height")
        
        // CRITICAL: Draw text at textFrame position relative to view
        // textFrame accounts for padding and text alignment
        canvas.save()
        
        // Translate to textFrame position (relative to view)
        val translateX = textFrame.left.toFloat()
        val translateY = textFrame.top.toFloat()
        
        android.util.Log.d("DCFTextView", "   Translating canvas by ($translateX, $translateY)")
        android.util.Log.d("DCFTextView", "   Canvas clip bounds before translate: ${canvas.clipBounds}")
        android.util.Log.d("DCFTextView", "   Canvas width: ${canvas.width}, height: ${canvas.height}")
        
        canvas.translate(translateX, translateY)
        
        android.util.Log.d("DCFTextView", "   Canvas clip bounds after translate: ${canvas.clipBounds}")
        
        // DEBUG: Draw a test rectangle to verify canvas is working
        val testPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.RED
            style = android.graphics.Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRect(0f, 0f, layout.width.toFloat(), layout.height.toFloat(), testPaint)
        android.util.Log.d("DCFTextView", "   ✅ Drew test red rectangle at (0, 0) with size (${layout.width}, ${layout.height})")
        
        // CRITICAL: Draw the text layout
        // StaticLayout.draw will draw the text using the paint color
        layout.draw(canvas)
        
        android.util.Log.d("DCFTextView", "   ✅ Called layout.draw(canvas)")
        
        canvas.restore()
        
        android.util.Log.d("DCFTextView", "✅ onDraw[viewId=$viewId]: Text drawn successfully at ($translateX, $translateY) relative to view")
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

