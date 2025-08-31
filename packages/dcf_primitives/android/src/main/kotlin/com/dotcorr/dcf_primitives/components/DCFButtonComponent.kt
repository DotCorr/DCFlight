/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.Button
import androidx.appcompat.widget.AppCompatButton
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFButtonComponent - Button component matching iOS DCFButtonComponent
 */
class DCFButtonComponent : DCFComponent {

    override fun createView(context: Context, props: Map<String, Any>): View {
        val button = AppCompatButton(context)

        // Default button styling
        button.isAllCaps = false
        button.setPadding(
            dpToPx(context, 16f),
            dpToPx(context, 8f),
            dpToPx(context, 16f),
            dpToPx(context, 8f)
        )

        // Apply props
        updateView(button, props)

        // Apply StyleSheet properties
        button.applyStyles(props)

        // Store component type for identification
        button.setTag(R.id.dcf_component_type, "Button")

        return button
    }

    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        val button = view as? AppCompatButton ?: return false

        // Button title/text
        props["title"]?.let { title ->
            button.text = when (title) {
                is String -> title
                else -> title.toString()
            }
        }

        // Text color
        props["titleColor"]?.let { color ->
            when (color) {
                is String -> {
                    try {
                        button.setTextColor(Color.parseColor(color))
                    } catch (e: IllegalArgumentException) {
                        // Invalid color string
                    }
                }

                is Int -> button.setTextColor(color)
            }
        } ?: run {
            // Default text color
            button.setTextColor(Color.WHITE)
        }

        // Font size
        props["fontSize"]?.let { size ->
            when (size) {
                is Number -> button.setTextSize(TypedValue.COMPLEX_UNIT_SP, size.toFloat())
                is String -> {
                    size.removeSuffix("sp").toFloatOrNull()?.let { fontSize ->
                        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize)
                    }
                }
            }
        }

        // Background color
        props["backgroundColor"]?.let { bgColor ->
            val color = when (bgColor) {
                is String -> {
                    try {
                        Color.parseColor(bgColor)
                    } catch (e: IllegalArgumentException) {
                        Color.parseColor("#007AFF") // iOS default blue
                    }
                }

                is Int -> bgColor
                else -> Color.parseColor("#007AFF")
            }

            // Create background with ripple effect
            val background = createButtonBackground(button.context, color, props)
            button.background = background
        } ?: run {
            // Default iOS-style blue button
            val background = createButtonBackground(button.context, Color.parseColor("#007AFF"), props)
            button.background = background
        }

        // Disabled state
        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    button.isEnabled = !disabled
                    button.alpha = if (disabled) 0.5f else 1.0f
                }
            }
        }

        // Handle press events
        props["onPress"]?.let { onPress ->
            button.setOnClickListener {
                // Store the callback for event handling
                button.setTag(R.id.dcf_button_pressed_state, true)
                // The actual callback would be handled by the framework
                // For now, just mark that button was pressed
            }
            button.setTag(R.id.dcf_event_callback, onPress)
        } ?: run {
            button.setOnClickListener(null)
            button.setTag(R.id.dcf_event_callback, null)
        }

        // Button style variants
        props["variant"]?.let { variant ->
            when (variant) {
                "outlined" -> {
                    // Outlined button style
                    button.setTextColor(props["titleColor"]?.let { parseColor(it) } ?: Color.parseColor("#007AFF"))
                    val background = createOutlinedButtonBackground(button.context, props)
                    button.background = background
                }

                "text" -> {
                    // Text-only button style
                    button.setTextColor(props["titleColor"]?.let { parseColor(it) } ?: Color.parseColor("#007AFF"))
                    button.background = createTextButtonBackground(button.context)
                }

                "filled", "contained" -> {
                    // Default filled style (already handled above)
                }
            }
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            button.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            button.setTag(R.id.dcf_test_id, testId)
        }

        // Store button title for potential reuse
        button.setTag(R.id.dcf_button_title, props["title"])

        return true
    }

    private fun createButtonBackground(
        context: Context,
        color: Int,
        props: Map<String, Any>
    ): android.graphics.drawable.Drawable {
        val cornerRadius = props["borderRadius"]?.let { radius ->
            when (radius) {
                is Number -> dpToPx(context, radius.toFloat()).toFloat()
                else -> dpToPx(context, 4f).toFloat()
            }
        } ?: dpToPx(context, 4f).toFloat()

        val normalDrawable = GradientDrawable().apply {
            setColor(color)
            setCornerRadius(cornerRadius)
        }

        val pressedDrawable = GradientDrawable().apply {
            setColor(darkenColor(color, 0.8f))
            setCornerRadius(cornerRadius)
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // Use ripple effect for Lollipop and above
            val rippleColor = lightenColor(color, 1.3f)
            RippleDrawable(
                android.content.res.ColorStateList.valueOf(rippleColor),
                normalDrawable,
                null
            )
        } else {
            // Use state list drawable for older versions
            StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_pressed), pressedDrawable)
                addState(intArrayOf(), normalDrawable)
            }
        }
    }

    private fun createOutlinedButtonBackground(
        context: Context,
        props: Map<String, Any>
    ): android.graphics.drawable.Drawable {
        val borderColor = props["borderColor"]?.let { parseColor(it) } ?: Color.parseColor("#007AFF")
        val borderWidth = props["borderWidth"]?.let { width ->
            when (width) {
                is Number -> dpToPx(context, width.toFloat())
                else -> dpToPx(context, 1f)
            }
        } ?: dpToPx(context, 1f)

        val cornerRadius = props["borderRadius"]?.let { radius ->
            when (radius) {
                is Number -> dpToPx(context, radius.toFloat()).toFloat()
                else -> dpToPx(context, 4f).toFloat()
            }
        } ?: dpToPx(context, 4f).toFloat()

        val normalDrawable = GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            setStroke(borderWidth, borderColor)
            setCornerRadius(cornerRadius)
        }

        val pressedDrawable = GradientDrawable().apply {
            setColor(Color.argb(20, Color.red(borderColor), Color.green(borderColor), Color.blue(borderColor)))
            setStroke(borderWidth, borderColor)
            setCornerRadius(cornerRadius)
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            RippleDrawable(
                android.content.res.ColorStateList.valueOf(borderColor),
                normalDrawable,
                null
            )
        } else {
            StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_pressed), pressedDrawable)
                addState(intArrayOf(), normalDrawable)
            }
        }
    }

    private fun createTextButtonBackground(context: Context): android.graphics.drawable.Drawable {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            RippleDrawable(
                android.content.res.ColorStateList.valueOf(Color.parseColor("#1E007AFF")),
                null,
                null
            )
        } else {
            StateListDrawable().apply {
                addState(
                    intArrayOf(android.R.attr.state_pressed),
                    GradientDrawable().apply {
                        setColor(Color.parseColor("#1E007AFF"))
                    }
                )
                addState(
                    intArrayOf(),
                    GradientDrawable().apply {
                        setColor(Color.TRANSPARENT)
                    }
                )
            }
        }
    }

    private fun parseColor(color: Any): Int {
        return when (color) {
            is String -> {
                try {
                    Color.parseColor(color)
                } catch (e: IllegalArgumentException) {
                    Color.BLACK
                }
            }

            is Int -> color
            else -> Color.BLACK
        }
    }

    private fun darkenColor(color: Int, factor: Float): Int {
        val r = (Color.red(color) * factor).toInt()
        val g = (Color.green(color) * factor).toInt()
        val b = (Color.blue(color) * factor).toInt()
        return Color.argb(Color.alpha(color), r, g, b)
    }

    private fun lightenColor(color: Int, factor: Float): Int {
        val r = Math.min((Color.red(color) * factor).toInt(), 255)
        val g = Math.min((Color.green(color) * factor).toInt(), 255)
        val b = Math.min((Color.blue(color) * factor).toInt(), 255)
        return Color.argb(Color.alpha(color), r, g, b)
    }

    private fun dpToPx(context: Context, dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            context.resources.displayMetrics
        ).toInt()
    }
}
