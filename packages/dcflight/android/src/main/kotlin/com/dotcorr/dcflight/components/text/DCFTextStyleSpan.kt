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
    private var mFontWeight: Int = 400 // Default to regular (400) to match iOS default
    private var mFontFamily: String? = null
    private var mLetterSpacing: Float = 0f
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
        letterSpacing: Float,
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
        mLetterSpacing = letterSpacing
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
            mLetterSpacing,
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
    
    fun getLetterSpacing(): Float = mLetterSpacing
    
    fun setLetterSpacing(letterSpacing: Float) {
        mLetterSpacing = letterSpacing
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
        // CRITICAL: Apply letter spacing in em units (matches iOS kern attribute behavior)
        // Android's letterSpacing is in em units (fraction of textSize), so divide by textSize
        if (mLetterSpacing != 0f && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            ds.letterSpacing = mLetterSpacing / ds.textSize
        }
    }
    
    private fun getNewStyle(oldStyle: Int): Int {
        var newStyle = oldStyle
        
        // Handle italic style
        when (mFontStyle) {
            Typeface.ITALIC -> newStyle = newStyle or Typeface.ITALIC
            Typeface.NORMAL -> newStyle = newStyle and Typeface.ITALIC.inv()
        }
        
        return newStyle
    }
    
    private fun updateTypeface(ds: TextPaint) {
        var typeface: Typeface? = null
        val isItalic = (mFontStyle and Typeface.ITALIC) != 0
        
        // Use numeric font weights (API 26+) to match iOS behavior
        // CRITICAL: Always use numeric weight API on API 26+ to ensure consistent rendering
        // Weight 400 (regular) is the default and should be explicitly applied to match iOS
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            // mFontWeight is now a numeric weight (0-1000), not a style flag
            // CRITICAL: If weight is 0 (uninitialized/legacy), default to 400 (regular) to match iOS
            val weight = if (mFontWeight == 0) 400 else mFontWeight.coerceIn(0, 1000)
            if (mFontFamily != null) {
                // First create base Typeface from font family string, then apply weight
                val baseTypeface = Typeface.create(mFontFamily, Typeface.NORMAL)
                typeface = Typeface.create(baseTypeface, weight, isItalic)
            } else {
                val oldTypeface = ds.typeface
                if (oldTypeface != null) {
                    // Try to preserve the base typeface while applying weight
                    typeface = Typeface.create(oldTypeface, weight, isItalic)
                } else {
                    typeface = Typeface.create(Typeface.DEFAULT, weight, isItalic)
                }
            }
        } else {
            // Fallback for older Android versions - convert weight to style flags
            val styleFlags = when {
                mFontWeight >= 700 -> Typeface.BOLD
                else -> Typeface.NORMAL
            } or (if (isItalic) Typeface.ITALIC else Typeface.NORMAL)
            
            if (mFontFamily != null) {
                typeface = Typeface.create(mFontFamily, styleFlags)
            } else {
                val oldTypeface = ds.typeface
                val oldStyle = oldTypeface?.style ?: Typeface.NORMAL
                typeface = Typeface.create(oldTypeface, getNewStyle(oldStyle) or (styleFlags and Typeface.BOLD))
            }
        }
        
        ds.typeface = typeface
        
        // CRITICAL: Always apply font size if set (mFontSize > 0)
        // If not set (mFontSize == -1), don't override the paint's existing textSize
        // This allows the base TextPaint to set a default, and spans can override if needed
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

