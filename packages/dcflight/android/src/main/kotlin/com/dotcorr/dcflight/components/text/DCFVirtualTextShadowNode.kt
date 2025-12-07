package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import android.graphics.Typeface
import com.dotcorr.dcflight.components.text.DCFTextShadowNode
import com.dotcorr.dcflight.layout.DCFShadowNode

class DCFVirtualTextShadowNode(viewId: Int) : DCFTextShadowNode(viewId) {
    
    private var mFontStylingSpan: DCFTextStyleSpan = DCFTextStyleSpan.INSTANCE.mutableCopy()
    
    // Override property setters to update span
    override var fontFamily: String?
        get() = super.fontFamily
        set(value) {
            if (super.fontFamily != value) {
                super.fontFamily = value
                if (mFontStylingSpan.getFontFamily() != value) {
                    getSpan().setFontFamily(value)
                    notifyChanged(true)
                }
            }
        }
    
    override var fontWeight: String?
        get() = super.fontWeight
        set(value) {
            if (super.fontWeight != value) {
                super.fontWeight = value
                val weight = parseFontWeight(value)
                if (mFontStylingSpan.getFontWeight() != weight) {
                    getSpan().setFontWeight(weight)
                    notifyChanged(true)
                }
            }
        }
    
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
    
    /**
     * Returns a new SpannableStringBuilder that includes all the text and styling information.
     * This is used to create the Layout for measurement and rendering.
     * Matches React Native's RCTVirtualText.getText() exactly.
     */
    fun getText(): SpannableStringBuilder {
        val sb = SpannableStringBuilder()
        collectText(sb)
        applySpans(sb, isEditable())
        return sb
    }
}

