package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import android.graphics.Typeface
import com.dotcorr.dcflight.components.text.DCFTextShadowNode
import com.dotcorr.dcflight.layout.DCFShadowNode

class DCFVirtualTextShadowNode(viewId: Int) : DCFTextShadowNode(viewId) {
    
    private var mFontStylingSpan: DCFTextStyleSpan = DCFTextStyleSpan.INSTANCE.mutableCopy()
    
    override fun canHaveSubviews(): Boolean = true
    
    override fun performCollectText(builder: SpannableStringBuilder) {
        for (i in 0 until subviews.size) {
            val child = subviews[i]
            if (child is DCFTextShadowNode) {
                child.collectText(builder)
            }
        }
    }
    
    override fun performApplySpans(
        builder: SpannableStringBuilder,
        begin: Int,
        end: Int,
        isEditable: Boolean
    ) {
        mFontStylingSpan.freeze()
        
        val flag = if (isEditable) {
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        } else {
            if (begin == 0) {
                Spannable.SPAN_INCLUSIVE_INCLUSIVE
            } else {
                Spannable.SPAN_EXCLUSIVE_INCLUSIVE
            }
        }
        
        builder.setSpan(mFontStylingSpan, begin, end, flag)
        
        for (i in 0 until subviews.size) {
            val child = subviews[i]
            if (child is DCFTextShadowNode) {
                child.applySpans(builder, isEditable)
            }
        }
    }
    
    fun getSpan(): DCFTextStyleSpan {
        if (mFontStylingSpan.isFrozen()) {
            mFontStylingSpan = mFontStylingSpan.mutableCopy()
        }
        return mFontStylingSpan
    }
    
    fun setFontSize(fontSize: Int) {
        if (mFontStylingSpan.getFontSize() != fontSize) {
            getSpan().setFontSize(fontSize)
            notifyChanged(true)
        }
    }
    
    fun setTextColor(textColor: Double) {
        if (mFontStylingSpan.getTextColor() != textColor) {
            getSpan().setTextColor(textColor)
            notifyChanged(false)
        }
    }
    
    fun setFontFamily(fontFamily: String?) {
        if (mFontStylingSpan.getFontFamily() != fontFamily) {
            getSpan().setFontFamily(fontFamily)
            notifyChanged(true)
        }
    }
    
    fun setFontWeight(fontWeight: String?) {
        val weight = parseFontWeight(fontWeight)
        if (mFontStylingSpan.getFontWeight() != weight) {
            getSpan().setFontWeight(weight)
            notifyChanged(true)
        }
    }
    
    fun setFontStyle(fontStyle: String?) {
        val style = parseFontStyle(fontStyle)
        if (mFontStylingSpan.getFontStyle() != style) {
            getSpan().setFontStyle(style)
            notifyChanged(true)
        }
    }
    
    fun getFontSize(): Int {
        val fontSize = mFontStylingSpan.getFontSize()
        return if (fontSize > 0) fontSize else getDefaultFontSize()
    }
    
    fun getFontStyle(): Int = mFontStylingSpan.getFontStyle()
    
    protected fun getDefaultFontSize(): Int {
        return 14
    }
    
    private fun parseFontWeight(fontWeight: String?): Int {
        if (fontWeight == null) return Typeface.NORMAL
        
        return when (fontWeight.lowercase()) {
            "bold", "700", "800", "900" -> Typeface.BOLD
            else -> Typeface.NORMAL
        }
    }
    
    private fun parseFontStyle(fontStyle: String?): Int {
        if (fontStyle == null) return Typeface.NORMAL
        
        return when (fontStyle.lowercase()) {
            "italic" -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }
    }
    
    override fun performCollectAttachDetachListeners() {
        for (i in 0 until subviews.size) {
            val child = subviews[i]
            if (child is DCFTextShadowNode) {
                child.performCollectAttachDetachListeners()
            }
        }
    }
}

