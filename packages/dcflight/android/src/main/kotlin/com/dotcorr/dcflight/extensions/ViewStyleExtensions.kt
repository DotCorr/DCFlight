/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.extensions

import android.content.res.Configuration
import android.content.res.Resources
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.DisplayMetrics
import android.view.View
import android.view.ViewGroup
import android.util.TypedValue
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcflight.R

/**
 * CRITICAL FIX: Apply density scaling to style properties for cross-platform consistency
 * iOS uses logical points that are automatically scaled by the system
 * Android needs manual scaling to achieve the same visual result
 */
private fun applyStyleDensityScaling(value: Float): Float {
    return try {
        val displayMetrics = Resources.getSystem().displayMetrics
        value * displayMetrics.density
    } catch (e: Exception) {
        value // Fallback to original value if scaling fails
    }
}

/**
 * View extension for style application
 * Apply common style properties to views
 */

fun View.applyStyles(props: Map<String, Any>) {
    var hasCornerRadius = false
    var finalCornerRadius = 0f

    val drawable = (this.background as? GradientDrawable) ?: GradientDrawable()

    props["borderRadius"]?.let { borderRadius ->
        val radius = when (borderRadius) {
            is Number -> {
                applyStyleDensityScaling(borderRadius.toFloat())
            }
            else -> 0f
        }
        drawable.cornerRadius = radius
        finalCornerRadius = radius
        hasCornerRadius = true
        this.clipToOutline = true
    }

    val topLeft = (props["borderTopLeftRadius"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()) }
    val topRight = (props["borderTopRightRadius"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()) }
    val bottomLeft = (props["borderBottomLeftRadius"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()) }
    val bottomRight = (props["borderBottomRightRadius"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()) }

    if (topLeft != null || topRight != null || bottomLeft != null || bottomRight != null) {
        val radii = floatArrayOf(
            topLeft ?: finalCornerRadius, topLeft ?: finalCornerRadius,
            topRight ?: finalCornerRadius, topRight ?: finalCornerRadius,
            bottomRight ?: finalCornerRadius, bottomRight ?: finalCornerRadius,
            bottomLeft ?: finalCornerRadius, bottomLeft ?: finalCornerRadius
        )
        drawable.cornerRadii = radii
        hasCornerRadius = true
        this.clipToOutline = true
    }

    props["borderColor"]?.let { borderColor ->
        val color = when (borderColor) {
            is String -> ColorUtilities.parseColor(borderColor)
            is Int -> borderColor
            else -> Color.TRANSPARENT
        }

        val borderWidth = (props["borderWidth"] as? Number)?.let { 
            applyStyleDensityScaling(it.toFloat()).toInt()
        } ?: 0
        if (borderWidth > 0) {
            drawable.setStroke(borderWidth, color)
            this.clipToOutline = true
        }
    }

    props["backgroundColor"]?.let { backgroundColor ->
        val color = when (backgroundColor) {
            is String -> ColorUtilities.parseColor(backgroundColor)
            is Int -> backgroundColor
            else -> Color.TRANSPARENT
        }
        drawable.setColor(color)
    }

    this.background = drawable

    props["backgroundGradient"]?.let { gradientData ->
        if (gradientData is Map<*, *>) {
            applyGradientBackground(gradientData as Map<String, Any>, finalCornerRadius)
        }
    }

    props["opacity"]?.let { opacity ->
        this.alpha = when (opacity) {
            is Number -> opacity.toFloat()
            else -> 1f
        }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        props["shadowColor"]?.let { shadowColor ->
            this.setTag(R.id.dcf_shadow_color, shadowColor)
        }

    props["shadowRadius"]?.let { shadowRadius ->
        val radius = when (shadowRadius) {
            is Number -> {
                applyStyleDensityScaling(shadowRadius.toFloat())
            }
            else -> 0f
        }
        this.elevation = radius
    }

        props["shadowOffsetX"]?.let { offsetX ->
            val scaledOffsetX = if (offsetX is Number) {
                applyStyleDensityScaling(offsetX.toFloat())
            } else offsetX
            this.setTag(R.id.dcf_shadow_offset_x, scaledOffsetX)
        }
        props["shadowOffsetY"]?.let { offsetY ->
            val scaledOffsetY = if (offsetY is Number) {
                applyStyleDensityScaling(offsetY.toFloat())
            } else offsetY
            this.setTag(R.id.dcf_shadow_offset_y, scaledOffsetY)
        }
    }

    props["elevation"]?.let { elevation ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            this.elevation = when (elevation) {
                is Number -> {
                    applyStyleDensityScaling(elevation.toFloat())
                }
                else -> 0f
            }
        }
    }

    props["hitSlop"]?.let { hitSlop ->
        if (hitSlop is Map<*, *>) {
            val top = (hitSlop["top"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
            val bottom = (hitSlop["bottom"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
            val left = (hitSlop["left"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
            val right = (hitSlop["right"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0

            this.setTag(R.id.dcf_hit_slop_top, top)
            this.setTag(R.id.dcf_hit_slop_bottom, bottom)
            this.setTag(R.id.dcf_hit_slop_left, left)
            this.setTag(R.id.dcf_hit_slop_right, right)
        }
    }

    props["accessible"]?.let { accessible ->
        this.importantForAccessibility = if (accessible as? Boolean == true) {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
    }

    props["accessibilityLabel"]?.let { label ->
        this.contentDescription = label.toString()
    }

    props["accessibilityHint"]?.let { hint ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            this.setAccessibilityDelegate(object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.hintText = hint.toString()
                }
            })
        }
    }

    props["accessibilityValue"]?.let { value ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            this.setAccessibilityDelegate(object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.text = value.toString()
                }
            })
        }
    }

    props["accessibilityRole"]?.let { role ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val roleString = role.toString().lowercase()
            when (roleString) {
                "button" -> this.isClickable = true
                "link" -> this.isClickable = true
                "header" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        this.accessibilityHeading = true
                    }
                }
            }
        }
    }

    props["testID"]?.let { testID ->
        this.setTag(R.id.dcf_test_id, testID)
    }

    props["pointerEvents"]?.let { pointerEvents ->
        when (pointerEvents) {
            "none" -> {
                this.isClickable = false
                this.isFocusable = false
            }

            "box-none" -> {
                this.isClickable = false
                this.isFocusable = false
            }

            "box-only" -> {
                this.isClickable = true
                this.isFocusable = true
            }

            "auto", "all" -> {
                this.isClickable = true
                this.isFocusable = true
            }
        }
    }
}

/**
 * Apply gradient background with proper corner radius support
 */
private fun View.applyGradientBackground(gradientData: Map<String, Any>, cornerRadius: Float = 0f) {
    val type = gradientData["type"] as? String ?: return
    val colors = (gradientData["colors"] as? List<*>)?.mapNotNull { colorStr ->
        when (colorStr) {
            is String -> ColorUtilities.parseColor(colorStr)
            else -> null
        }
    }?.toIntArray() ?: return

    if (colors.size < 2) return

    val drawable = GradientDrawable()

    when (type) {
        "linear" -> {
            val startX = (gradientData["startX"] as? Number)?.toFloat() ?: 0f
            val startY = (gradientData["startY"] as? Number)?.toFloat() ?: 0f
            val endX = (gradientData["endX"] as? Number)?.toFloat() ?: 1f
            val endY = (gradientData["endY"] as? Number)?.toFloat() ?: 1f

            val orientation = when {
                startY == 0f && endY == 1f -> GradientDrawable.Orientation.TOP_BOTTOM
                startY == 1f && endY == 0f -> GradientDrawable.Orientation.BOTTOM_TOP
                startX == 0f && endX == 1f -> GradientDrawable.Orientation.LEFT_RIGHT
                startX == 1f && endX == 0f -> GradientDrawable.Orientation.RIGHT_LEFT
                else -> GradientDrawable.Orientation.TOP_BOTTOM
            }

            drawable.orientation = orientation
        }

        "radial" -> {
            drawable.gradientType = GradientDrawable.RADIAL_GRADIENT
            val radius = (gradientData["radius"] as? Number)?.toFloat() ?: 0.5f
            drawable.gradientRadius = radius * this.width.coerceAtLeast(1)
        }
    }

    drawable.colors = colors

    if (cornerRadius > 0) {
        drawable.cornerRadius = cornerRadius
    }

    this.setTag(R.id.dcf_gradient_drawable, drawable)
    this.background = drawable
}

/**
 * Apply adaptive defaults based on view type - matches iOS behavior
 */
private fun View.applyAdaptiveDefaults() {
    val context = this.context
    try {
        when (this) {
            is android.widget.TextView -> {
                val typedValue = TypedValue()
                if (context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)) {
                    this.setTextColor(typedValue.data)
                }
            }
            else -> {
                val typedValue = TypedValue()
                if (context.theme.resolveAttribute(android.R.attr.colorBackground, typedValue, true)) {
                    this.setBackgroundColor(typedValue.data)
                }
            }
        }
    } catch (e: Exception) {
        val isDarkTheme = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        when (this) {
            is android.widget.TextView -> {
                this.setTextColor(if (isDarkTheme) Color.WHITE else Color.BLACK)
            }
            else -> {
                this.setBackgroundColor(if (isDarkTheme) Color.BLACK else Color.WHITE)
            }
        }
    }
}

/**
 * Apply adaptive background color based on current theme
 */
fun View.applyAdaptiveBackgroundColor() {
    val context = this.context
    try {
        val typedValue = TypedValue()
        if (context.theme.resolveAttribute(android.R.attr.colorBackground, typedValue, true)) {
            this.setBackgroundColor(typedValue.data)
        } else {
            val isDarkTheme = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            this.setBackgroundColor(if (isDarkTheme) Color.BLACK else Color.WHITE)
        }
    } catch (e: Exception) {
        this.setBackgroundColor(Color.WHITE)
    }
}

/**
 * Apply adaptive text color based on current theme
 */
fun View.applyAdaptiveTextColor() {
    if (this is android.widget.TextView) {
        val context = this.context
        try {
            val typedValue = TypedValue()
            if (context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)) {
                this.setTextColor(typedValue.data)
            } else {
                val isDarkTheme = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
                this.setTextColor(if (isDarkTheme) Color.WHITE else Color.BLACK)
            }
        } catch (e: Exception) {
            this.setTextColor(Color.BLACK)
        }
    }
}

/**
 * Apply adaptive accent color (for buttons, etc.)
 */
fun View.applyAdaptiveAccentColor() {
    val context = this.context
    try {
        val typedValue = TypedValue()
        val attrId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            android.R.attr.colorAccent
        } else {
            android.R.attr.colorAccent
        }
        if (context.theme.resolveAttribute(attrId, typedValue, true)) {
            this.setBackgroundColor(typedValue.data)
        } else {
            this.setBackgroundColor(Color.parseColor("#2196F3")) // Material Blue
        }
    } catch (e: Exception) {
        this.setBackgroundColor(Color.parseColor("#2196F3"))
    }
}

/**
 * Update gradient layer frame when view bounds change - matching iOS
 */
fun View.updateGradientFrame() {
    val gradientDrawable = this.getTag(R.id.dcf_gradient_drawable) as? GradientDrawable
    gradientDrawable?.let {
        this.invalidate()
    }
}

