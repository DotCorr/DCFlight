package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import com.dotcorr.dcflight.components.text.DCFTextShadowNode

class DCFRawTextShadowNode(viewId: Int) : DCFTextShadowNode(viewId) {
    
    private var mText: String? = null
    
    override fun performCollectText(builder: SpannableStringBuilder) {
        if (mText != null) {
            builder.append(mText)
        }
    }
    
    override fun performApplySpans(
        builder: SpannableStringBuilder,
        begin: Int,
        end: Int,
        isEditable: Boolean
    ) {
    }
    
    override fun performCollectAttachDetachListeners() {
    }
    
    fun setText(text: String?) {
        if (mText != text) {
            mText = text
            notifyChanged(true)
        }
    }
    
    fun getText(): String? = mText
}

