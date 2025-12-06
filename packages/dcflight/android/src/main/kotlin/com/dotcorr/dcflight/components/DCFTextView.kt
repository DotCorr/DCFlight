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
    }
    
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        android.util.Log.d("DCFTextView", "🔍 onDraw: textLayout=${textLayout != null}, textFrame=$textFrame, view bounds=${left},${top},${right},${bottom}")
        
        val layout = textLayout ?: run {
            android.util.Log.w("DCFTextView", "⚠️ onDraw: textLayout is null, not drawing")
            return
        }
        
        android.util.Log.d("DCFTextView", "✅ onDraw: Drawing text layout (width=${layout.width}, height=${layout.height}) at textFrame=$textFrame")
        
        canvas.save()
        canvas.translate(textFrame.left.toFloat(), textFrame.top.toFloat())
        layout.draw(canvas)
        canvas.restore()
        
        android.util.Log.d("DCFTextView", "✅ onDraw: Text drawn successfully")
    }
    
    override fun toString(): String {
        val superDescription = super.toString()
        val text = textLayout?.text?.toString() ?: ""
        return "$superDescription; text: $text"
    }
}

