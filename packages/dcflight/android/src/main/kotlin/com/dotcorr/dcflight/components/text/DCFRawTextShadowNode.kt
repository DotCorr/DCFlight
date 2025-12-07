package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import com.dotcorr.dcflight.components.text.DCFTextShadowNode

class DCFRawTextShadowNode(viewId: Int) : DCFTextShadowNode(viewId) {
    
    override fun performCollectText(builder: SpannableStringBuilder) {
        if (text.isNotEmpty()) {
            builder.append(text)
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
}

