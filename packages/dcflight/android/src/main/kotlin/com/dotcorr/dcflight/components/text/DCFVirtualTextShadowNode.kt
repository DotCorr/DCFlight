package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import android.graphics.Typeface
import com.dotcorr.dcflight.components.text.DCFTextShadowNode
import com.dotcorr.dcflight.layout.DCFShadowNode

class DCFVirtualTextShadowNode(viewId: Int) : DCFTextShadowNode(viewId) {
    
    companion object {
        private const val DEFAULT_FONT_SIZE = 17 // Match iOS default (iOS uses 17, React Native uses 14)
    }
    
    private var mFontStylingSpan: DCFTextStyleSpan = DCFTextStyleSpan.INSTANCE.mutableCopy().apply {
        // CRITICAL: Initialize span with default font size (matches iOS behavior)
        // iOS defaults to 17, but React Native typically uses 14
        // This ensures the span has a valid font size even before props are set
        setFontSize(DEFAULT_FONT_SIZE)
    }
    
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
    
    // CRITICAL: Override fontSize property setter to also update span
    // This ensures span font size stays in sync when fontSize is set directly
    // fontSize comes in logical points (like iOS), but span stores pixels (TextPaint uses pixels)
    // So we need to convert points to pixels before storing in span
    override var fontSize: Float
        get() = super.fontSize
        set(value) {
            if (super.fontSize != value) {
                super.fontSize = value
                // Convert points to pixels (like iOS points -> Android pixels)
                // Points scale with display density, so convert via SP
                val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
                val fontSizePixels = android.util.TypedValue.applyDimension(
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    value,
                    displayMetrics
                ).toInt()
                if (mFontStylingSpan.getFontSize() != fontSizePixels) {
                    getSpan().setFontSize(fontSizePixels)
                    notifyChanged(true)
                }
            }
        }
    
    // CRITICAL: Override letterSpacing property setter to also update span
    // This ensures span letter spacing stays in sync when letterSpacing is set directly
    override var letterSpacing: Float
        get() = super.letterSpacing
        set(value) {
            if (super.letterSpacing != value) {
                super.letterSpacing = value
                if (mFontStylingSpan.getLetterSpacing() != value) {
                    getSpan().setLetterSpacing(value)
                    notifyChanged(true)
                }
            }
        }
    
    override fun canHaveSubviews(): Boolean = true
    
    override fun performCollectText(builder: SpannableStringBuilder) {
        // CRITICAL: Also collect text from this node itself (matches iOS behavior)
        // iOS DCFTextShadowView stores text directly on the node, not just in children
        // This allows text to be set via the "content" prop directly on Text components
        if (text.isNotEmpty()) {
            builder.append(text)
        }
        
        // Then collect text from children (for nested Text components)
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
        // CRITICAL: Also update the base fontSize property for consistency
        // This ensures fontSize is available for measurement even if span isn't applied yet
        if (super.fontSize != fontSize.toFloat()) {
            super.fontSize = fontSize.toFloat()
        }
        
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
        return DEFAULT_FONT_SIZE
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

