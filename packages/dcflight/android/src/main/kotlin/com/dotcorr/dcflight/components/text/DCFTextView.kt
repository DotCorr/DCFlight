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
        super.onDraw(canvas)
        
        val layout = textLayout ?: return
        
        canvas.save()
        canvas.translate(textFrameLeft, textFrameTop)
        layout.draw(canvas)
        canvas.restore()
    }
}

