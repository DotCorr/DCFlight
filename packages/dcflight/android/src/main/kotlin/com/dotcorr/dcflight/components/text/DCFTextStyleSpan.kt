package com.dotcorr.dcflight.components.text

import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import android.text.style.CharacterStyle

class DCFTextStyleSpan private constructor() : MetricAffectingSpan() {
    
    private var mTextColor: Double = Double.NaN
    private var mBackgroundColor: Int = 0
    private var mHasUnderline: Boolean = false
    private var mHasStrikeThrough: Boolean = false
    private var mFontSize: Int = -1
    private var mFontStyle: Int = Typeface.NORMAL
    private var mFontWeight: Int = Typeface.NORMAL
    private var mFontFamily: String? = null
    private var mFrozen: Boolean = false
    
    companion object {
        val INSTANCE = DCFTextStyleSpan()
    }
    
    private constructor(
        textColor: Double,
        backgroundColor: Int,
        fontSize: Int,
        fontStyle: Int,
        fontWeight: Int,
        hasUnderline: Boolean,
        hasStrikeThrough: Boolean,
        fontFamily: String?,
        frozen: Boolean
    ) : this() {
        mTextColor = textColor
        mBackgroundColor = backgroundColor
        mFontSize = fontSize
        mFontStyle = fontStyle
        mFontWeight = fontWeight
        mHasUnderline = hasUnderline
        mHasStrikeThrough = hasStrikeThrough
        mFontFamily = fontFamily
        mFrozen = frozen
    }
    
    fun mutableCopy(): DCFTextStyleSpan {
        return DCFTextStyleSpan(
            mTextColor,
            mBackgroundColor,
            mFontSize,
            mFontStyle,
            mFontWeight,
            mHasUnderline,
            mHasStrikeThrough,
            mFontFamily,
            false
        )
    }
    
    fun isFrozen(): Boolean = mFrozen
    
    fun freeze() {
        mFrozen = true
    }
    
    fun getTextColor(): Double = mTextColor
    
    fun setTextColor(textColor: Double) {
        mTextColor = textColor
    }
    
    fun getBackgroundColor(): Int = mBackgroundColor
    
    fun setBackgroundColor(backgroundColor: Int) {
        mBackgroundColor = backgroundColor
    }
    
    fun getFontSize(): Int = mFontSize
    
    fun setFontSize(fontSize: Int) {
        mFontSize = fontSize
    }
    
    fun getFontStyle(): Int = mFontStyle
    
    fun setFontStyle(fontStyle: Int) {
        mFontStyle = fontStyle
    }
    
    fun getFontWeight(): Int = mFontWeight
    
    fun setFontWeight(fontWeight: Int) {
        mFontWeight = fontWeight
    }
    
    fun getFontFamily(): String? = mFontFamily
    
    fun setFontFamily(fontFamily: String?) {
        mFontFamily = fontFamily
    }
    
    fun hasUnderline(): Boolean = mHasUnderline
    
    fun setHasUnderline(hasUnderline: Boolean) {
        mHasUnderline = hasUnderline
    }
    
    fun hasStrikeThrough(): Boolean = mHasStrikeThrough
    
    fun setHasStrikeThrough(hasStrikeThrough: Boolean) {
        mHasStrikeThrough = hasStrikeThrough
    }
    
    override fun updateDrawState(ds: TextPaint) {
        updateTypeface(ds)
        
        if (!java.lang.Double.isNaN(mTextColor)) {
            ds.color = colorFromDouble(mTextColor)
        }
        
        if (mHasUnderline) {
            ds.isUnderlineText = true
        }
        
        if (mHasStrikeThrough) {
            ds.flags = ds.flags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
        }
        
        if (mBackgroundColor != 0) {
            ds.bgColor = mBackgroundColor
        }
    }
    
    override fun updateMeasureState(ds: TextPaint) {
        updateTypeface(ds)
    }
    
    private fun getNewStyle(oldStyle: Int): Int {
        var newStyle = oldStyle
        
        when (mFontWeight) {
            Typeface.BOLD -> newStyle = newStyle or Typeface.BOLD
            Typeface.NORMAL -> newStyle = newStyle and Typeface.BOLD.inv()
        }
        
        when (mFontStyle) {
            Typeface.ITALIC -> newStyle = newStyle or Typeface.ITALIC
            Typeface.NORMAL -> newStyle = newStyle and Typeface.ITALIC.inv()
        }
        
        return newStyle
    }
    
    private fun updateTypeface(ds: TextPaint) {
        var typeface: Typeface? = null
        
        if (mFontFamily != null) {
            typeface = Typeface.create(mFontFamily, getNewStyle(Typeface.NORMAL))
        } else {
            val oldTypeface = ds.typeface
            val oldStyle = oldTypeface?.style ?: Typeface.NORMAL
            typeface = Typeface.create(oldTypeface, getNewStyle(oldStyle))
        }
        
        ds.typeface = typeface
        
        if (mFontSize > 0) {
            ds.textSize = mFontSize.toFloat()
        }
    }
    
    private fun colorFromDouble(value: Double): Int {
        val longValue = value.toLong()
        return if (longValue > Int.MAX_VALUE) {
            Int.MAX_VALUE
        } else {
            longValue.toInt()
        }
    }
}

