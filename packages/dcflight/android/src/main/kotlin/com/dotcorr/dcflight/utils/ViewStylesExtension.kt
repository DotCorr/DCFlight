/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.utils

import android.animation.ValueAnimator
import android.graphics.*
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import androidx.core.view.ViewCompat
import com.dotcorr.dcflight.components.R
import kotlin.math.max
import kotlin.math.min

/**
 * View extension for generic style application
 * Following iOS ViewStylesheet exactly
 */
fun View.applyStyles(props: Map<String, Any?>) {
    // Debug log for applied props
    Log.d("ViewStyles", "Applying styles to view with ${props.size} props")

    // Apply border radius FIRST before gradient to avoid override
    var hasCornerRadius = false
    var finalCornerRadius = 0f
    var cornerRadii: FloatArray? = null

    // Border Radius (Global)
    props["borderRadius"]?.let { radius ->
        val radiusValue = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        if (radiusValue > 0) {
            finalCornerRadius = radiusValue
            hasCornerRadius = true
            this.clipToOutline = true // Enable clipping when border radius is set
        }
    }

    // Per-corner Radius (Overrides global borderRadius if specific corners are set)
    var topLeftRadius = finalCornerRadius
    var topRightRadius = finalCornerRadius
    var bottomLeftRadius = finalCornerRadius
    var bottomRightRadius = finalCornerRadius

    props["borderTopLeftRadius"]?.let { radius ->
        val value = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        if (value >= 0) {
            topLeftRadius = value
            hasCornerRadius = true
        }
    }

    props["borderTopRightRadius"]?.let { radius ->
        val value = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        if (value >= 0) {
            topRightRadius = value
            hasCornerRadius = true
        }
    }

    props["borderBottomLeftRadius"]?.let { radius ->
        val value = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        if (value >= 0) {
            bottomLeftRadius = value
            hasCornerRadius = true
        }
    }

    props["borderBottomRightRadius"]?.let { radius ->
        val value = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        if (value >= 0) {
            bottomRightRadius = value
            hasCornerRadius = true
        }
    }

    if (hasCornerRadius) {
        cornerRadii = floatArrayOf(
            topLeftRadius, topLeftRadius,
            topRightRadius, topRightRadius,
            bottomRightRadius, bottomRightRadius,
            bottomLeftRadius, bottomLeftRadius
        )
        this.clipToOutline = true
    }

    // Border color and width - Apply only if specified
    var borderColor: Int? = null
    props["borderColor"]?.let { colorStr ->
        borderColor = when (colorStr) {
            is String -> ColorUtilities.color(colorStr)
            is Long -> colorStr.toInt()
            is Int -> colorStr
            else -> null
        }
    }

    var borderWidth = 0f
    props["borderWidth"]?.let { width ->
        borderWidth = when (width) {
            is Double -> width.toFloat()
            is Float -> width
            is Int -> width.toFloat()
            else -> 0f
        }
        if (borderWidth > 0) {
            this.clipToOutline = true
        }
    }

    // Background color - Apply only if specified
    var backgroundColor: Int? = null
    props["backgroundColor"]?.let { colorStr ->
        backgroundColor = when (colorStr) {
            is String -> ColorUtilities.color(colorStr)
            is Long -> colorStr.toInt()
            is Int -> colorStr
            else -> null
        }
        if (backgroundColor != null && props["backgroundGradient"] == null) {
            // Only set if no gradient
            this.setBackgroundColor(backgroundColor!!)
        }
    }

    // Apply gradient AFTER border radius and ensure it respects corner radius
    props["backgroundGradient"]?.let { gradientData ->
        if (gradientData is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            applyGradientBackground(
                gradientData as Map<String, Any?>,
                cornerRadii = if (hasCornerRadius) cornerRadii else null,
                borderWidth = borderWidth,
                borderColor = borderColor
            )
        }
    }

    // If we have border but no gradient, apply using GradientDrawable
    if ((borderWidth > 0 || hasCornerRadius) && props["backgroundGradient"] == null) {
        val drawable = GradientDrawable().apply {
            // Set background color
            backgroundColor?.let { setColor(it) }

            // Set border
            if (borderWidth > 0 && borderColor != null) {
                setStroke(borderWidth.toInt(), borderColor!!)
            }

            // Set corner radius
            if (hasCornerRadius) {
                if (cornerRadii != null) {
                    cornerRadii = cornerRadii
                } else {
                    cornerRadius = finalCornerRadius
                }
            }
        }
        this.background = drawable
    }

    // Opacity (Alpha) - Apply only if specified
    props["opacity"]?.let { opacity ->
        this.alpha = when (opacity) {
            is Double -> opacity.toFloat()
            is Float -> opacity
            is Int -> opacity.toFloat()
            else -> 1f
        }
    }

    // Shadow properties - Apply only if specified
    var needsShadow = false
    var shadowColor = Color.BLACK
    var shadowRadius = 0f
    var shadowDx = 0f
    var shadowDy = 0f

    props["shadowColor"]?.let { colorStr ->
        shadowColor = when (colorStr) {
            is String -> ColorUtilities.color(colorStr) ?: Color.BLACK
            is Long -> colorStr.toInt()
            is Int -> colorStr
            else -> Color.BLACK
        }
        needsShadow = true
    }

    props["shadowOpacity"]?.let { opacity ->
        val alpha = when (opacity) {
            is Double -> (opacity * 255).toInt()
            is Float -> (opacity * 255).toInt()
            is Int -> opacity
            else -> 255
        }
        shadowColor = Color.argb(alpha, Color.red(shadowColor), Color.green(shadowColor), Color.blue(shadowColor))
        needsShadow = true
    }

    props["shadowRadius"]?.let { radius ->
        shadowRadius = when (radius) {
            is Double -> radius.toFloat()
            is Float -> radius
            is Int -> radius.toFloat()
            else -> 0f
        }
        needsShadow = true
    }

    // Handle shadow offset
    props["shadowOffsetX"]?.let { offset ->
        shadowDx = when (offset) {
            is Double -> offset.toFloat()
            is Float -> offset
            is Int -> offset.toFloat()
            else -> 0f
        }
        needsShadow = true
    }

    props["shadowOffsetY"]?.let { offset ->
        shadowDy = when (offset) {
            is Double -> offset.toFloat()
            is Float -> offset
            is Int -> offset.toFloat()
            else -> 0f
        }
        needsShadow = true
    }

    // Apply shadow using elevation on Android
    if (needsShadow && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        this.elevation = shadowRadius
        // Android doesn't support shadow color/offset natively, would need custom drawable
        if (hasCornerRadius) {
            this.outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    if (cornerRadii != null) {
                        // Use the average radius for outline
                        val avgRadius = cornerRadii!!.average().toFloat()
                        outline.setRoundRect(0, 0, view.width, view.height, avgRadius)
                    } else {
                        outline.setRoundRect(0, 0, view.width, view.height, finalCornerRadius)
                    }
                }
            }
        }
    }

    // Hit Slop - Apply only if specified (extends touch area)
    props["hitSlop"]?.let { hitSlopMap ->
        if (hitSlopMap is Map<*, *>) {
            val top = (hitSlopMap["top"] as? Number)?.toInt() ?: 0
            val bottom = (hitSlopMap["bottom"] as? Number)?.toInt() ?: 0
            val left = (hitSlopMap["left"] as? Number)?.toInt() ?: 0
            val right = (hitSlopMap["right"] as? Number)?.toInt() ?: 0

            // Store hit slop for use in hit testing
            this.setTag(R.id.dcf_hit_slop_top, top)
            this.setTag(R.id.dcf_hit_slop_bottom, bottom)
            this.setTag(R.id.dcf_hit_slop_left, left)
            this.setTag(R.id.dcf_hit_slop_right, right)
        }
    }

    // Elevation (Android-style) - Convert to shadow for iOS compatibility
    props["elevation"]?.let { elevation ->
        val elevationValue = when (elevation) {
            is Double -> elevation.toFloat()
            is Float -> elevation
            is Int -> elevation.toFloat()
            else -> 0f
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            this.elevation = elevationValue

            if (elevationValue > 0 && hasCornerRadius) {
                this.outlineProvider = object : ViewOutlineProvider() {
                    override fun getOutline(view: View, outline: Outline) {
                        if (cornerRadii != null) {
                            val avgRadius = cornerRadii!!.average().toFloat()
                            outline.setRoundRect(0, 0, view.width, view.height, avgRadius)
                        } else {
                            outline.setRoundRect(0, 0, view.width, view.height, finalCornerRadius)
                        }
                    }
                }
            }
        }
    }

    // Accessibility properties - Apply only if specified
    props["accessible"]?.let { accessible ->
        this.importantForAccessibility = when (accessible) {
            true -> View.IMPORTANT_FOR_ACCESSIBILITY_YES
            false -> View.IMPORTANT_FOR_ACCESSIBILITY_NO
            else -> View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        }
    }

    props["accessibilityLabel"]?.let { label ->
        this.contentDescription = label.toString()
    }

    props["testID"]?.let { testID ->
        this.tag = testID
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
private fun View.applyGradientBackground(
    gradientData: Map<String, Any?>,
    cornerRadii: FloatArray? = null,
    borderWidth: Float = 0f,
    borderColor: Int? = null
) {
    // Ensure we have valid bounds before applying gradient
    if (width == 0 || height == 0) {
        // Store gradient data for later application when bounds are available
        this.setTag(R.id.dcf_pending_gradient_data, gradientData)
        this.setTag(R.id.dcf_pending_gradient_radii, cornerRadii)
        this.setTag(R.id.dcf_pending_gradient_border_width, borderWidth)
        this.setTag(R.id.dcf_pending_gradient_border_color, borderColor)
        return
    }

    val type = gradientData["type"] as? String ?: return
    val colorsArray = gradientData["colors"] as? List<*> ?: return

    // Convert color strings to Int colors
    val colors = colorsArray.mapNotNull { colorValue ->
        when (colorValue) {
            is String -> ColorUtilities.color(colorValue)
            is Long -> colorValue.toInt()
            is Int -> colorValue
            else -> null
        }
    }.toIntArray()

    if (colors.size < 2) {
        Log.w("ViewStyles", "Gradient needs at least 2 colors, got ${colors.size}")
        return
    }

    val gradientDrawable = GradientDrawable()

    // Set gradient colors
    gradientDrawable.colors = colors

    // Set gradient stops if provided
    gradientData["stops"]?.let { stops ->
        if (stops is List<*>) {
            // Android doesn't directly support stops, would need custom drawable
        }
    }

    // Configure gradient based on type
    when (type) {
        "linear" -> {
            val startX = (gradientData["startX"] as? Number)?.toFloat() ?: 0f
            val startY = (gradientData["startY"] as? Number)?.toFloat() ?: 0f
            val endX = (gradientData["endX"] as? Number)?.toFloat() ?: 1f
            val endY = (gradientData["endY"] as? Number)?.toFloat() ?: 1f

            // Convert normalized coordinates to angle
            val angle = Math.toDegrees(Math.atan2((endY - startY).toDouble(), (endX - startX).toDouble())).toFloat()

            val orientation = when {
                angle >= -22.5 && angle < 22.5 -> GradientDrawable.Orientation.LEFT_RIGHT
                angle >= 22.5 && angle < 67.5 -> GradientDrawable.Orientation.TL_BR
                angle >= 67.5 && angle < 112.5 -> GradientDrawable.Orientation.TOP_BOTTOM
                angle >= 112.5 && angle < 157.5 -> GradientDrawable.Orientation.TR_BL
                angle >= 157.5 || angle < -157.5 -> GradientDrawable.Orientation.RIGHT_LEFT
                angle >= -157.5 && angle < -112.5 -> GradientDrawable.Orientation.BR_TL
                angle >= -112.5 && angle < -67.5 -> GradientDrawable.Orientation.BOTTOM_TOP
                angle >= -67.5 && angle < -22.5 -> GradientDrawable.Orientation.BL_TR
                else -> GradientDrawable.Orientation.TOP_BOTTOM
            }

            gradientDrawable.orientation = orientation
            gradientDrawable.gradientType = GradientDrawable.LINEAR_GRADIENT
        }

        "radial" -> {
            val centerX = (gradientData["centerX"] as? Number)?.toFloat() ?: 0.5f
            val centerY = (gradientData["centerY"] as? Number)?.toFloat() ?: 0.5f
            val radius = (gradientData["radius"] as? Number)?.toFloat() ?: 0.5f

            gradientDrawable.gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientDrawable.setGradientCenter(centerX, centerY)

            // Set gradient radius (need to set after view is laid out)
            val maxDimension = max(width, height).toFloat()
            gradientDrawable.gradientRadius = maxDimension * radius
        }
    }

    // Apply corner radius to gradient layer if needed
    if (cornerRadii != null) {
        gradientDrawable.cornerRadii = cornerRadii
    }

    // Apply border if needed
    if (borderWidth > 0 && borderColor != null) {
        gradientDrawable.setStroke(borderWidth.toInt(), borderColor)
    }

    // Set the gradient as background
    this.background = gradientDrawable

    // Store gradient drawable for later updates
    this.setTag(R.id.dcf_gradient_drawable, gradientDrawable)
    this.setTag(R.id.dcf_gradient_corner_radii, cornerRadii)

    // Clear pending gradient data since we've applied it
    this.setTag(R.id.dcf_pending_gradient_data, null)
    this.setTag(R.id.dcf_pending_gradient_radii, null)
    this.setTag(R.id.dcf_pending_gradient_border_width, null)
    this.setTag(R.id.dcf_pending_gradient_border_color, null)

    Log.d("ViewStyles", "Applied gradient: $type with ${colors.size} colors")
}

/**
 * Update gradient frame when view bounds change
 */
fun View.updateGradientFrame() {
    if (width == 0 || height == 0) return // Skip empty bounds

    // Check for pending gradient data first
    val pendingData = this.getTag(R.id.dcf_pending_gradient_data) as? Map<String, Any?>
    if (pendingData != null) {
        val cornerRadii = this.getTag(R.id.dcf_pending_gradient_radii) as? FloatArray
        val borderWidth = this.getTag(R.id.dcf_pending_gradient_border_width) as? Float ?: 0f
        val borderColor = this.getTag(R.id.dcf_pending_gradient_border_color) as? Int

        applyGradientBackground(pendingData, cornerRadii, borderWidth, borderColor)
        return
    }

    // Update existing gradient if needed
    val gradientDrawable = this.getTag(R.id.dcf_gradient_drawable) as? GradientDrawable
    if (gradientDrawable != null && gradientDrawable.gradientType == GradientDrawable.RADIAL_GRADIENT) {
        // Update radial gradient radius based on new bounds
        val maxDimension = max(width, height).toFloat()
        gradientDrawable.gradientRadius = maxDimension * 0.5f // Default to 50% of max dimension

        Log.d("ViewStyles", "Updated gradient frame to ${width}x${height}")
    }
}

/**
 * Extension to be called when layout changes
 */
fun View.onLayoutChanged() {
    updateGradientFrame()
}

// Add these resource IDs to the framework's R.id
private object GradientTags {
    const val DCF_GRADIENT_DRAWABLE = 2001
    const val DCF_GRADIENT_CORNER_RADII = 2002
    const val DCF_PENDING_GRADIENT_DATA = 2003
    const val DCF_PENDING_GRADIENT_RADII = 2004
    const val DCF_PENDING_GRADIENT_BORDER_WIDTH = 2005
    const val DCF_PENDING_GRADIENT_BORDER_COLOR = 2006
}
