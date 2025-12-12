package com.dotcorr.dcflight.components.text

import android.graphics.Canvas
import android.text.Layout

class DCFTextLayoutDrawCommand(private var layout: Layout) {
    
    private var mLayoutWidth: Float = layout.width.toFloat()
    private var mLayoutHeight: Float = layout.height.toFloat()
    
    private var mLeft: Float = 0f
    private var mTop: Float = 0f
    private var mRight: Float = 0f
    private var mBottom: Float = 0f
    
    fun setLayout(layout: Layout) {
        this.layout = layout
        mLayoutWidth = layout.width.toFloat()
        mLayoutHeight = layout.height.toFloat()
    }
    
    fun getLayout(): Layout = layout
    
    fun getLayoutWidth(): Float = mLayoutWidth
    
    fun getLayoutHeight(): Float = mLayoutHeight
    
    fun setBounds(left: Float, top: Float, right: Float, bottom: Float) {
        mLeft = left
        mTop = top
        mRight = right
        mBottom = bottom
    }
    
    fun draw(canvas: Canvas) {
        canvas.save()
        canvas.translate(mLeft, mTop)
        layout.draw(canvas)
        canvas.restore()
    }
    
    fun getLeft(): Float = mLeft
    fun getTop(): Float = mTop
    fun getRight(): Float = mRight
    fun getBottom(): Float = mBottom
}


