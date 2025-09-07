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
        
        // Font cache to match iOS implementation
        private val fontCache = mutableMapOf<String, Typeface>()

        // Match iOS system font size (17sp on iOS = ~17sp on Android)
        private const val DEFAULT_TEXT_SIZE = 17f
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Create a TextView - match iOS UILabel
        val textView = TextView(context)

        // Apply adaptive default styling - let OS handle light/dark mode
        textView.maxLines = Int.MAX_VALUE // numberOfLines = 0 in iOS means unlimited
        
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system colors that automatically adapt to light/dark mode
            textView.setTextColor(
                com.dotcorr.dcflight.utils.AdaptiveColorHelper.getSystemTextColor(context)
            )
        } else {
            textView.setTextColor(Color.BLACK)
        }

        // Apply props - convert nullable to non-nullable
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(textView, nonNullProps)

        // Apply StyleSheet properties
        textView.applyStyles(nonNullProps)

        return textView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val textView = view as? TextView ?: return false
        
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(textView, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val textView = view as? TextView ?: return false

        Log.d(TAG, "Updating text view with props: $props")

        // Set content if specified - MATCH iOS "content" property EXACTLY
        props["content"]?.let { content ->
            textView.text = content.toString()
            Log.d(TAG, "Set text content: $content")
        }

        // Handle font properties only if they are provided (for incremental updates)
        val hasAnyFontProp = props.containsKey("fontSize") || props.containsKey("fontWeight") || 
                            props.containsKey("fontFamily") || props.containsKey("isFontAsset")

        if (hasAnyFontProp) {
            // Get current font as fallback
            val currentSize = textView.textSize / textView.context.resources.displayMetrics.scaledDensity
            val finalFontSize = (props["fontSize"] as? Number)?.toFloat() ?: currentSize

            // Determine font weight using centralized utility - MATCH iOS
            var finalFontWeight = Typeface.NORMAL
            props["fontWeight"]?.let { fontWeightString ->
                finalFontWeight = fontWeightFromString(fontWeightString.toString())
            }

            // Check if font is from an asset
            val isFontAsset = props["isFontAsset"] as? Boolean ?: false

            props["fontFamily"]?.let { fontFamily ->
                val fontFamilyStr = fontFamily.toString()
                
                if (isFontAsset) {
                    // Load font from assets - match iOS asset loading
                    loadFontFromAsset(textView.context, fontFamilyStr, finalFontSize, finalFontWeight) { typeface ->
                        typeface?.let {
                            textView.typeface = it
                            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                        } ?: run {
                            // Fallback to system font if custom font loading fails
                            textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                        }
                    }
                } else {
                    // Try to use a pre-installed font by name
                    try {
                        val typeface = Typeface.create(fontFamilyStr, finalFontWeight)
                        textView.typeface = typeface
                        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                    } catch (e: Exception) {
                        // Fallback to system font if font not found
                        textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
                    }
                }
            } ?: run {
                // Use system font with the specified size and weight
                textView.typeface = Typeface.defaultFromStyle(finalFontWeight)
                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, finalFontSize)
            }
        }

        // Handle color property - this is the key fix for incremental updates
        if (props.containsKey("color")) {
            props["color"]?.let { color ->
                val colorInt = ColorUtilities.color(color.toString())
                if (colorInt != null) {
                    textView.setTextColor(colorInt)
                    Log.d(TAG, "Set text color: $color")
                }
            }
        }

        // Handle adaptive color only if explicitly provided and no color is set
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

        // Set text alignment if specified (preserve current alignment if not in props)
        props["textAlign"]?.let { textAlign ->
            when (textAlign.toString()) {
                "center" -> textView.gravity = Gravity.CENTER_HORIZONTAL
                "right" -> textView.gravity = Gravity.END
                "justify" -> {
                    // Justified text alignment (API 26+)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        textView.justificationMode = android.text.Layout.JUSTIFICATION_MODE_INTER_WORD
                    }
                    textView.gravity = Gravity.START
                }
                else -> textView.gravity = Gravity.START
            }
            Log.d(TAG, "Set text alignment: $textAlign")
        }

        // Set number of lines if specified (preserve current numberOfLines if not in props)
        props["numberOfLines"]?.let { numberOfLines ->
            val lines = (numberOfLines as? Number)?.toInt() ?: Int.MAX_VALUE
            textView.maxLines = if (lines == 0) Int.MAX_VALUE else lines
            Log.d(TAG, "Set number of lines: $numberOfLines")
        }

        // Apply StyleSheet properties
        textView.applyStyles(props)

        return true
    }

    // MARK: - Font Utility Functions - MATCH iOS exactly

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
            // Legacy numeric support
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
        // Create a unique key for caching
        val cacheKey = "${fontAsset}_${fontSize}_${weight}"

        // Check cache first
        fontCache[cacheKey]?.let { cachedFont ->
            completion(cachedFont)
            return
        }

        try {
            // Load font from assets
            val typeface = Typeface.createFromAsset(context.assets, fontAsset)
            
            // Apply weight if needed
            val finalTypeface = if (weight != Typeface.NORMAL) {
                Typeface.create(typeface, weight)
            } else {
                typeface
            }

            // Cache the font
            fontCache[cacheKey] = finalTypeface

            completion(finalTypeface)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load font from asset: $fontAsset", e)
            completion(null)
        }
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS getIntrinsicSize

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val textView = view as? TextView ?: return PointF(0f, 0f)

        // Get the current text or use empty string
        val text = textView.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(0f, 0f)
        }

        // Measure the text content
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
        // Text components are typically leaf nodes and don't need special handling
        Log.d(TAG, "Text component registered with shadow tree: $nodeId")
    }
}

