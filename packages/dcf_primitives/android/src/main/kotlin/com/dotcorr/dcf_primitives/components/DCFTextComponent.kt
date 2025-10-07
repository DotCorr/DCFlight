/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.PointF
import android.graphics.Typeface
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R
import kotlin.math.max

/**
 * EXACT iOS DCFTextComponent port for Android
 * Matches iOS DCFTextComponent.swift behavior 1:1
 */
class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
        
        private val fontCache = mutableMapOf<String, Typeface>()

        private const val DEFAULT_TEXT_SIZE = 17f
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val textView = TextView(context)


        textView.maxLines = Int.MAX_VALUE // numberOfLines = 0 in iOS means unlimited
        
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            textView.setTextColor(
                com.dotcorr.dcflight.utils.AdaptiveColorHelper.getSystemTextColor(context)
            )
        } else {
            textView.setTextColor(Color.BLACK)
        }

        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(textView, nonNullProps)

        textView.applyStyles(nonNullProps)

        return textView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val textView = view as? TextView ?: return false
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(textView, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val textView = view as? TextView ?: return false

        Log.d(TAG, "Updating text view with props: $props")

        props["content"]?.let { content ->
            textView.text = content.toString()
            Log.d(TAG, "Set text content: $content")
        }

        val hasAnyFontProp = props.containsKey("fontSize") || props.containsKey("fontWeight") || 
                            props.containsKey("fontFamily") || props.containsKey("isFontAsset")

        if (hasAnyFontProp) {
            val currentSize = textView.textSize / textView.context.resources.displayMetrics.scaledDensity
            val finalFontSize = (props["fontSize"] as? Number)?.toFloat() ?: currentSize

            var finalFontWeight = Typeface.NORMAL
            props["fontWeight"]?.let { fontWeightString ->
                finalFontWeight = fontWeightFromString(fontWeightString.toString())
            }

            val isFontAsset = props["isFontAsset"] as? Boolean ?: false

            props["fontFamily"]?.let { fontFamily ->
                val fontFamilyStr = fontFamily.toString()
                
                if (isFontAsset) {
                    loadFontFromAsset(textView.context, fontFamilyStr, finalFontSize, finalFontWeight) { typeface ->
                        typeface?.let {
                            textView.typeface = it
                            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                        } ?: run {
                            textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                        }
                    }
                } else {
                    try {
                        val typeface = Typeface.create(fontFamilyStr, finalFontWeight)
                        textView.typeface = typeface
                        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                    } catch (e: Exception) {
                        textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                    }
                }
            } ?: run {
                textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
            }
        }

        if (props.containsKey("color")) {
            props["color"]?.let { color ->
                val colorInt = ColorUtilities.color(color.toString())
                if (colorInt != null) {
                    textView.setTextColor(colorInt)
                    Log.d(TAG, "Set text color: $color")
                }
            }
        }

        if (props.containsKey("adaptive") && !props.containsKey("color")) {
            val isAdaptive = props["adaptive"] as? Boolean ?: true
            if (isAdaptive) {
                try {
                    val typedValue = TypedValue()
                    if (textView.context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)) {
                        textView.setTextColor(typedValue.data)
                    } else {
                        textView.setTextColor(Color.BLACK)
                    }
                } catch (e: Exception) {
                    textView.setTextColor(Color.BLACK)
                }
            }
        }

        props["textAlign"]?.let { textAlign ->
            when (textAlign.toString()) {
                "center" -> {
                    textView.gravity = Gravity.CENTER_HORIZONTAL
                }
                "right", "end" -> {
                    textView.gravity = Gravity.END
                }
                "left", "start" -> {
                    textView.gravity = Gravity.START
                }
                "justify" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        textView.justificationMode = android.text.Layout.JUSTIFICATION_MODE_INTER_WORD
                    }
                    textView.gravity = Gravity.START
                }
                else -> {
                    textView.gravity = Gravity.START
                }
            }
            Log.d(TAG, "Set text alignment: $textAlign")
        }

        props["numberOfLines"]?.let { numberOfLines ->
            val lines = (numberOfLines as? Number)?.toInt() ?: Int.MAX_VALUE
            textView.maxLines = if (lines == 0) Int.MAX_VALUE else lines
            Log.d(TAG, "Set number of lines: $numberOfLines")
        }

        textView.applyStyles(props)

        return true
    }


    private fun fontWeightFromString(weight: String): Int {
        return when (weight.lowercase()) {
            "thin" -> Typeface.NORMAL  // Android doesn't have thin, use normal
            "ultralight" -> Typeface.NORMAL
            "light" -> Typeface.NORMAL
            "regular", "normal", "400" -> Typeface.NORMAL
            "medium" -> Typeface.NORMAL
            "semibold" -> Typeface.BOLD
            "bold" -> Typeface.BOLD
            "heavy" -> Typeface.BOLD
            "black" -> Typeface.BOLD
            "100" -> Typeface.NORMAL
            "200" -> Typeface.NORMAL
            "300" -> Typeface.NORMAL
            "500" -> Typeface.NORMAL
            "600" -> Typeface.BOLD
            "700" -> Typeface.BOLD
            "800" -> Typeface.BOLD
            "900" -> Typeface.BOLD
            else -> Typeface.NORMAL
        }
    }

    private fun loadFontFromAsset(
        context: Context,
        fontAsset: String,
        fontSize: Float,
        weight: Int,
        completion: (Typeface?) -> Unit
    ) {
        val cacheKey = "${fontAsset}_${fontSize}_${weight}"

        fontCache[cacheKey]?.let { cachedFont ->
            completion(cachedFont)
            return
        }

        try {
            val typeface = Typeface.createFromAsset(context.assets, fontAsset)
            
            val finalTypeface = if (weight != Typeface.NORMAL) {
                Typeface.create(typeface, weight)
            } else {
                typeface
            }

            fontCache[cacheKey] = finalTypeface

            completion(finalTypeface)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load font from asset: $fontAsset", e)
            completion(null)
        }
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val textView = view as? TextView ?: return PointF(0f, 0f)

        val text = textView.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(0f, 0f)
        }

        textView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = textView.measuredWidth.toFloat()
        val measuredHeight = textView.measuredHeight.toFloat()

        Log.d(TAG, "Text intrinsic size: ${measuredWidth}x${measuredHeight} for text: \"$text\"")

        return PointF(max(1f, measuredWidth), max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Text component registered with shadow tree: $nodeId")
    }
}

