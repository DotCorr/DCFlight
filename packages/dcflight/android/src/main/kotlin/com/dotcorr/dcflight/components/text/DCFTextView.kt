package com.dotcorr.dcflight.components.text

import android.content.Context
import android.graphics.Canvas
import android.text.StaticLayout
import android.view.View

class DCFTextView(context: Context) : View(context) {
    
    private var _textLayout: StaticLayout? = null
    var textLayout: StaticLayout?
        get() = _textLayout
        set(value) {
            if (_textLayout != value) {
                _textLayout = value
                android.util.Log.d("DCFTextView", "🎨 Layout set: ${if (value != null) "width=${value.width}, height=${value.height}, lineCount=${value.lineCount}" else "NULL"}")
                // Force measure and layout update
                requestLayout()
                invalidate()
                // Post invalidate to ensure it happens
                postInvalidate()
            }
        }
    
    var textFrameLeft: Float = 0f
    var textFrameTop: Float = 0f
    
    init {
        setWillNotDraw(false)
        // CRITICAL: Set background to transparent so text is visible (matches iOS isOpaque = false)
        // This prevents black boxes from appearing behind text
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
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
    
    // CRITICAL: Don't override onMeasure - Yoga already handles measurement via measure function
    // The measure function returns layout size, and Yoga adds padding to get final view size
    // Overriding onMeasure would interfere with Yoga's layout calculations
    
    override fun onDraw(canvas: Canvas) {
        val layout = textLayout
        
        if (layout == null) {
            android.util.Log.w("DCFTextView", "⚠️ onDraw called but layout is NULL")
            return
        }
        
        android.util.Log.d("DCFTextView", "🖼️ onDraw: layout width=${layout.width}, height=${layout.height}, text='${layout.text}'")
        
        // CRITICAL: Match React Native's DrawTextLayout.onDraw exactly
        // React Native: canvas.translate(left, top); mLayout.draw(canvas); canvas.translate(-left, -top);
        // In our case, left/top are the padding offsets (textFrame position) relative to the view
        // The view is already positioned correctly by the layout system
        val left = textFrameLeft
        val top = textFrameTop
        
        android.util.Log.d("DCFTextView", "📍 Drawing at position: left=$left, top=$top")
        
        canvas.save()
        canvas.translate(left, top)
        layout.draw(canvas)
        canvas.translate(-left, -top)
        canvas.restore()
        
        android.util.Log.d("DCFTextView", "✅ onDraw complete")
    }
}