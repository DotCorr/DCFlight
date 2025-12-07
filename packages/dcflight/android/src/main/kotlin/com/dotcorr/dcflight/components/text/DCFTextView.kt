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
                invalidate()
            }
        }
    
    var textFrameLeft: Float = 0f
    var textFrameTop: Float = 0f
    
    init {
        isOpaque = false
        setWillNotDraw(false)
        clipToPadding = false
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

