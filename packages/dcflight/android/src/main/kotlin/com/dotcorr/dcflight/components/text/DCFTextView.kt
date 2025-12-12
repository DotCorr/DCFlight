package com.dotcorr.dcflight.components.text

import android.content.Context
import android.graphics.Canvas
import android.text.Layout
import android.view.View

class DCFTextView(context: Context) : View(context) {
    
    private var _textLayout: Layout? = null
    var textLayout: Layout?
        get() = _textLayout
        set(value) {
            if (_textLayout != value) {
                _textLayout = value
                requestLayout()
                invalidate()
            }
        }
    
    var textFrameLeft: Float = 0f
    var textFrameTop: Float = 0f
    
    init {
        setWillNotDraw(false)
        // CRITICAL: Set background to transparent so text is visible (matches iOS isOpaque = false)
        // This prevents black boxes from appearing behind text
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val layout = textLayout
        if (layout != null) {
            // Use layout dimensions for measurement
            val width = layout.width.coerceAtLeast(0)
            val height = layout.height.coerceAtLeast(0)
            
            val widthSize = View.MeasureSpec.getSize(widthMeasureSpec)
            val widthMode = View.MeasureSpec.getMode(widthMeasureSpec)
            val heightSize = View.MeasureSpec.getSize(heightMeasureSpec)
            val heightMode = View.MeasureSpec.getMode(heightMeasureSpec)
            
            val measuredWidth = when (widthMode) {
                View.MeasureSpec.EXACTLY -> widthSize
                View.MeasureSpec.AT_MOST -> width.coerceAtMost(widthSize)
                else -> width
            }
            
            val measuredHeight = when (heightMode) {
                View.MeasureSpec.EXACTLY -> heightSize
                View.MeasureSpec.AT_MOST -> height.coerceAtMost(heightSize)
                else -> height
            }
            
            setMeasuredDimension(measuredWidth, measuredHeight)
        } else {
            // No layout yet, measure as empty
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        }
    }
    
    override fun onDraw(canvas: Canvas) {
        val layout = textLayout ?: return
        
        // CRITICAL: Match React Native's DrawTextLayout.onDraw exactly
        // React Native: canvas.translate(left, top); mLayout.draw(canvas); canvas.translate(-left, -top);
        // In our case, left/top are the padding offsets (textFrame position) relative to the view
        // The view is already positioned correctly by the layout system
        val left = textFrameLeft
        val top = textFrameTop
        
        canvas.save()
        canvas.translate(left, top)
        layout.draw(canvas)
        canvas.translate(-left, -top)
        canvas.restore()
    }
}

