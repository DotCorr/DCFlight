/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.extensions

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcflight.R

/**
 * View extension for generic style application - matching iOS UIView extension
 * Apply common style properties to this view, driven only by explicit props
 */
fun View.applyStyles(props: Map<String, Any>) {
    // CRITICAL: Apply border radius FIRST before gradient to avoid override
    var hasCornerRadius = false
    var finalCornerRadius = 0f

    // Create or get existing drawable
    val drawable = (this.background as? GradientDrawable) ?: GradientDrawable()

    // Border Radius (Global)
    props["borderRadius"]?.let { borderRadius ->
        val radius = when (borderRadius) {
            is Number -> borderRadius.toFloat()
            else -> 0f
        }
        drawable.cornerRadius = radius
        finalCornerRadius = radius
        hasCornerRadius = true
        this.clipToOutline = true // Enable clipping when border radius is set
    }

    // Per-corner Radius (Android supports uniform corners only in GradientDrawable)
    val topLeft = (props["borderTopLeftRadius"] as? Number)?.toFloat()
    val topRight = (props["borderTopRightRadius"] as? Number)?.toFloat()
    val bottomLeft = (props["borderBottomLeftRadius"] as? Number)?.toFloat()
    val bottomRight = (props["borderBottomRightRadius"] as? Number)?.toFloat()

    if (topLeft != null || topRight != null || bottomLeft != null || bottomRight != null) {
        // Android GradientDrawable supports per-corner radii
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

    // Border color and width - Apply only if specified
    props["borderColor"]?.let { borderColor ->
        val color = when (borderColor) {
            is String -> ColorUtilities.parseColor(borderColor)
            is Int -> borderColor
            else -> Color.TRANSPARENT
        }

        val borderWidth = (props["borderWidth"] as? Number)?.toInt() ?: 0
        if (borderWidth > 0) {
            drawable.setStroke(borderWidth, color)
            this.clipToOutline = true
        }
    }

    // Background color - Apply only if specified
    props["backgroundColor"]?.let { backgroundColor ->
        val color = when (backgroundColor) {
            is String -> ColorUtilities.parseColor(backgroundColor)
            is Int -> backgroundColor
            else -> Color.TRANSPARENT
        }
        drawable.setColor(color)
    }

    // Apply the drawable
    this.background = drawable

    // Gradient background - Apply AFTER border radius
    props["backgroundGradient"]?.let { gradientData ->
        if (gradientData is Map<*, *>) {
            applyGradientBackground(gradientData as Map<String, Any>, finalCornerRadius)
        }
    }

    // Opacity (Alpha) - Apply only if specified
    props["opacity"]?.let { opacity ->
        this.alpha = when (opacity) {
            is Number -> opacity.toFloat()
            else -> 1f
        }
    }

    // Shadow properties - Apply only if specified
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        props["shadowColor"]?.let { shadowColor ->
            // Android uses elevation for shadows, can't set color directly
            // Store for potential custom shadow implementation
            this.setTag(R.id.dcf_shadow_color, shadowColor)
        }

        props["shadowRadius"]?.let { shadowRadius ->
            val radius = when (shadowRadius) {
                is Number -> shadowRadius.toFloat()
                else -> 0f
            }
            this.elevation = radius
        }

        props["shadowOffsetX"]?.let { offsetX ->
            this.setTag(R.id.dcf_shadow_offset_x, offsetX)
        }
        props["shadowOffsetY"]?.let { offsetY ->
            this.setTag(R.id.dcf_shadow_offset_y, offsetY)
        }
    }

    // Elevation (Android-style) - Convert to elevation
    props["elevation"]?.let { elevation ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            this.elevation = when (elevation) {
                is Number -> elevation.toFloat()
                else -> 0f
            }
        }
    }

    // Hit Slop - Apply only if specified (extends touch area)
    props["hitSlop"]?.let { hitSlop ->
        if (hitSlop is Map<*, *>) {
            val top = (hitSlop["top"] as? Number)?.toInt() ?: 0
            val bottom = (hitSlop["bottom"] as? Number)?.toInt() ?: 0
            val left = (hitSlop["left"] as? Number)?.toInt() ?: 0
            val right = (hitSlop["right"] as? Number)?.toInt() ?: 0

            // Store hit slop for custom hit testing
            this.setTag(R.id.dcf_hit_slop_top, top)
            this.setTag(R.id.dcf_hit_slop_bottom, bottom)
            this.setTag(R.id.dcf_hit_slop_left, left)
            this.setTag(R.id.dcf_hit_slop_right, right)
        }
    }

    // Accessibility properties - Apply only if specified
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

    props["testID"]?.let { testID ->
        this.setTag(R.id.dcf_test_id, testID)
    }

    // Pointer Events - Apply only if specified
    props["pointerEvents"]?.let { pointerEvents ->
        when (pointerEvents) {
            "none" -> {
                this.isClickable = false
                this.isFocusable = false
            }

            "box-none" -> {
                // View itself doesn't receive events, but children can
                this.isClickable = false
                this.isFocusable = false
            }

            "box-only" -> {
                // View receives events, children do not
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

    // Apply gradient orientation based on type
    when (type) {
        "linear" -> {
            val startX = (gradientData["startX"] as? Number)?.toFloat() ?: 0f
            val startY = (gradientData["startY"] as? Number)?.toFloat() ?: 0f
            val endX = (gradientData["endX"] as? Number)?.toFloat() ?: 1f
            val endY = (gradientData["endY"] as? Number)?.toFloat() ?: 1f

            // Convert to Android gradient orientation
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

    // Apply corner radius if specified
    if (cornerRadius > 0) {
        drawable.cornerRadius = cornerRadius
    }

    // Store gradient drawable
    this.setTag(R.id.dcf_gradient_drawable, drawable)
    this.background = drawable
}

/**
 * Update gradient layer frame when view bounds change - matching iOS
 */
fun View.updateGradientFrame() {
    val gradientDrawable = this.getTag(R.id.dcf_gradient_drawable) as? GradientDrawable
    gradientDrawable?.let {
        // Android handles this automatically unlike iOS
        // But we can trigger a redraw if needed
        this.invalidate()
    }
}
