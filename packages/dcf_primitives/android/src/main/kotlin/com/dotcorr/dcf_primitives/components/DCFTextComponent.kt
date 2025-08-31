/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFTextComponent - Text rendering component for DCFlight
 * Matches iOS DCFTextComponent functionality
 */
class DCFTextComponent : DCFComponent {

    companion object {
        // Font cache to match iOS implementation
        private val fontCache = mutableMapOf<String, Typeface>()

        private const val DEFAULT_TEXT_SIZE = 14f
    }

    override fun createView(context: Context, props: Map<String, Any>): View {
        val textView = TextView(context)

        // Apply adaptive default styling - let OS handle light/dark mode
        textView.maxLines = Int.MAX_VALUE // numberOfLines = 0 in iOS means unlimited

        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use theme colors that automatically adapt to light/dark mode
            val typedValue = TypedValue()
            context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)
            textView.setTextColor(typedValue.data)
        } else {
            textView.setTextColor(Color.BLACK)
        }

        // Apply props
        updateView(textView, props)

        // Apply StyleSheet properties
        textView.applyStyles(props)

        // Store component type for identification
        textView.setTag(R.id.dcf_component_type, "Text")

        return textView
    }

    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        val textView = view as? TextView ?: return false

        // Update text content
        props["text"]?.let { text ->
            textView.text = when (text) {
                is String -> text
                else -> text.toString()
            }
        }

        // Update text color
        props["color"]?.let { color ->
            when (color) {
                is String -> {
                    try {
                        textView.setTextColor(Color.parseColor(color))
                    } catch (e: IllegalArgumentException) {
                        // Invalid color string, ignore
                    }
                }

                is Int -> textView.setTextColor(color)
            }
        }

        // Update font size
        props["fontSize"]?.let { size ->
            when (size) {
                is Number -> textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, size.toFloat())
                is String -> {
                    size.removeSuffix("sp").toFloatOrNull()?.let { fontSize ->
                        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize)
                    }
                }
            }
        }

        // Update font weight/style
        props["fontWeight"]?.let { weight ->
            val currentTypeface = textView.typeface ?: Typeface.DEFAULT
            val style = when (weight) {
                "bold", "700", "800", "900" -> Typeface.BOLD
                "normal", "400" -> Typeface.NORMAL
                else -> currentTypeface.style
            }

            // Handle font family if specified
            val fontFamily = props["fontFamily"] as? String
            val typeface = if (fontFamily != null) {
                getFontTypeface(fontFamily, style)
            } else {
                Typeface.create(currentTypeface, style)
            }
            textView.typeface = typeface
        } ?: run {
            // Just handle font family without weight
            props["fontFamily"]?.let { family ->
                textView.typeface = getFontTypeface(family as String, textView.typeface?.style ?: Typeface.NORMAL)
            }
        }

        // Update font style (italic)
        props["fontStyle"]?.let { style ->
            when (style) {
                "italic" -> {
                    val currentTypeface = textView.typeface ?: Typeface.DEFAULT
                    val newStyle = if (currentTypeface.isBold) {
                        Typeface.BOLD_ITALIC
                    } else {
                        Typeface.ITALIC
                    }
                    textView.typeface = Typeface.create(currentTypeface, newStyle)
                }

                "normal" -> {
                    val currentTypeface = textView.typeface ?: Typeface.DEFAULT
                    val newStyle = if (currentTypeface.isBold) {
                        Typeface.BOLD
                    } else {
                        Typeface.NORMAL
                    }
                    textView.typeface = Typeface.create(currentTypeface, newStyle)
                }
            }
        }

        // Update text alignment
        props["textAlign"]?.let { align ->
            textView.gravity = when (align) {
                "center" -> Gravity.CENTER
                "left", "start" -> Gravity.START or Gravity.TOP
                "right", "end" -> Gravity.END or Gravity.TOP
                "justify" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        textView.justificationMode = TextView.JUSTIFICATION_MODE_INTER_WORD
                        Gravity.START or Gravity.TOP
                    } else {
                        Gravity.START or Gravity.TOP
                    }
                }

                else -> textView.gravity
            }
        }

        // Update number of lines
        props["numberOfLines"]?.let { lines ->
            when (lines) {
                is Int -> {
                    textView.maxLines = if (lines == 0) Int.MAX_VALUE else lines
                    if (lines == 1) {
                        textView.ellipsize = TextUtils.TruncateAt.END
                    }
                }
            }
        }

        // Update line height/spacing
        props["lineHeight"]?.let { height ->
            when (height) {
                is Number -> {
                    val lineHeight = height.toFloat()
                    val fontHeight = textView.paint.getFontMetricsInt(null)
                    textView.setLineSpacing(lineHeight - fontHeight, 1f)
                }
            }
        }

        // Update letter spacing
        props["letterSpacing"]?.let { spacing ->
            when (spacing) {
                is Number -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                        textView.letterSpacing = spacing.toFloat()
                    }
                }
            }
        }

        // Update text decoration
        props["textDecorationLine"]?.let { decoration ->
            when (decoration) {
                "underline" -> textView.paintFlags = textView.paintFlags or android.graphics.Paint.UNDERLINE_TEXT_FLAG
                "line-through" -> textView.paintFlags =
                    textView.paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG

                "none" -> {
                    textView.paintFlags = textView.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG.inv()
                    textView.paintFlags = textView.paintFlags and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG.inv()
                }
            }
        }

        // Update selectable
        props["selectable"]?.let { selectable ->
            when (selectable) {
                is Boolean -> textView.setTextIsSelectable(selectable)
            }
        }

        // Store text data for potential reuse
        textView.setTag(R.id.dcf_text_data, props["text"])

        return true
    }

    private fun getFontTypeface(fontFamily: String, style: Int): Typeface {
        val cacheKey = "$fontFamily-$style"

        return fontCache[cacheKey] ?: run {
            val typeface = try {
                // Try to load custom font
                when {
                    fontFamily == "monospace" -> Typeface.MONOSPACE
                    fontFamily == "serif" -> Typeface.SERIF
                    fontFamily == "sans-serif" -> Typeface.SANS_SERIF
                    else -> {
                        // Try to create typeface from font family name
                        Typeface.create(fontFamily, style)
                    }
                }
            } catch (e: Exception) {
                // Fallback to default with style
                Typeface.create(Typeface.DEFAULT, style)
            }

            fontCache[cacheKey] = typeface
            typeface
        }
    }
}
