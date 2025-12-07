package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import com.dotcorr.dcflight.layout.DCFShadowNode

abstract class DCFTextShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    private var mTextBegin: Int = 0
    private var mTextEnd: Int = 0
    
    var text: String = ""
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var fontSize: Float = 14f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var fontWeight: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var fontFamily: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var letterSpacing: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var lineHeight: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var numberOfLines: Int = 0
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var textAlign: String = "start"
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    protected fun notifyChanged(shouldRemeasure: Boolean) {
        val parent = superview
        if (parent is DCFTextShadowNode) {
            parent.notifyChanged(shouldRemeasure)
        }
    }
    
    final fun collectText(builder: SpannableStringBuilder) {
        mTextBegin = builder.length
        performCollectText(builder)
        mTextEnd = builder.length
    }
    
    protected open fun shouldAllowEmptySpans(): Boolean {
        return false
    }
    
    protected open fun isEditable(): Boolean {
        return false
    }
    
    final fun applySpans(builder: SpannableStringBuilder, isEditable: Boolean) {
        if (mTextBegin != mTextEnd || shouldAllowEmptySpans()) {
            performApplySpans(builder, mTextBegin, mTextEnd, isEditable)
        }
    }
    
    protected abstract fun performCollectText(builder: SpannableStringBuilder)
    protected abstract fun performApplySpans(
        builder: SpannableStringBuilder,
        begin: Int,
        end: Int,
        isEditable: Boolean
    )
    
    protected open fun performCollectAttachDetachListeners() {
    }
}

