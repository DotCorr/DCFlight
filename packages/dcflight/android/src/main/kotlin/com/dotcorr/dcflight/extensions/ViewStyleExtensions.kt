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
import com.dotcorr.dcflight.components.DCFTags

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
            this.setTag(DCFTags.SHADOW_COLOR_KEY, shadowColor)
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
            this.setTag(DCFTags.SHADOW_OFFSET_X_KEY, scaledOffsetX)
        }
        props["shadowOffsetY"]?.let { offsetY ->
            val scaledOffsetY = if (offsetY is Number) {
                applyStyleDensityScaling(offsetY.toFloat())
            } else offsetY
            this.setTag(DCFTags.SHADOW_OFFSET_Y_KEY, scaledOffsetY)
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

            this.setTag(DCFTags.HIT_SLOP_TOP_KEY, top)
            this.setTag(DCFTags.HIT_SLOP_BOTTOM_KEY, bottom)
            this.setTag(DCFTags.HIT_SLOP_LEFT_KEY, left)
            this.setTag(DCFTags.HIT_SLOP_RIGHT_KEY, right)
        }
    }

    var accessibilityDelegate: View.AccessibilityDelegate? = null

    props["accessible"]?.let { accessible ->
        this.importantForAccessibility = if (accessible as? Boolean == true) {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
    }

    props["importantForAccessibility"]?.let { important ->
        val importantStr = important.toString().lowercase()
        this.importantForAccessibility = when (importantStr) {
            "yes" -> View.IMPORTANT_FOR_ACCESSIBILITY_YES
            "no" -> View.IMPORTANT_FOR_ACCESSIBILITY_NO
            "no-hide-descendants" -> View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            else -> View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        }
    }

    props["accessibilityLabel"]?.let { label ->
        this.contentDescription = label.toString()
    } ?: props["ariaLabel"]?.let { label ->
        this.contentDescription = label.toString()
    }

    props["accessibilityHint"]?.let { hint ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val hintText = hint.toString()
            accessibilityDelegate = object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.hintText = hintText
                }
            }
        }
    }

    props["accessibilityValue"]?.let { value ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val valueText = when (value) {
                is String -> value
                is Map<*, *> -> (value["text"] as? String) ?: value.toString()
                else -> value.toString()
            }
            val existingDelegate = accessibilityDelegate
            accessibilityDelegate = object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    existingDelegate?.onInitializeAccessibilityNodeInfo(host, info)
                        ?: super.onInitializeAccessibilityNodeInfo(host, info)
                    info.text = valueText
                }
            }
        }
    }

    props["accessibilityState"]?.let { state ->
        if (state is Map<*, *> && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existingDelegate = accessibilityDelegate
            accessibilityDelegate = object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    existingDelegate?.onInitializeAccessibilityNodeInfo(host, info)
                        ?: super.onInitializeAccessibilityNodeInfo(host, info)
                    state["disabled"]?.let { if (it as? Boolean == true) info.isEnabled = false }
                    state["selected"]?.let { if (it as? Boolean == true) info.isSelected = true }
                    state["checked"]?.let {
                        when (it) {
                            is Boolean -> info.isChecked = it
                            is String -> if (it == "mixed") info.isCheckable = true
                        }
                    }
                    state["expanded"]?.let {
                        val expanded = it as? Boolean == true
                        val expandedText = if (expanded) "expanded" else "collapsed"
                        val currentDesc = info.contentDescription?.toString() ?: ""
                        if (currentDesc.isEmpty()) {
                            info.contentDescription = expandedText
                        } else if (!currentDesc.contains(expandedText)) {
                            info.contentDescription = "$currentDesc, $expandedText"
                        }
                    }
                }
            }
        }
    }

    props["accessibilityLiveRegion"]?.let { liveRegion ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val region = when (liveRegion.toString().lowercase()) {
                "polite" -> View.ACCESSIBILITY_LIVE_REGION_POLITE
                "assertive" -> View.ACCESSIBILITY_LIVE_REGION_ASSERTIVE
                else -> View.ACCESSIBILITY_LIVE_REGION_NONE
            }
            this.accessibilityLiveRegion = region
        }
    } ?: props["ariaLive"]?.let { ariaLive ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val region = when (ariaLive.toString().lowercase()) {
                "polite" -> View.ACCESSIBILITY_LIVE_REGION_POLITE
                "assertive" -> View.ACCESSIBILITY_LIVE_REGION_ASSERTIVE
                else -> View.ACCESSIBILITY_LIVE_REGION_NONE
            }
            this.accessibilityLiveRegion = region
        }
    }

    props["accessibilityRole"]?.let { role ->
        val roleString = role.toString().lowercase()
        when (roleString) {
            "button", "imagebutton" -> this.isClickable = true
            "link" -> this.isClickable = true
            "header" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val existingDelegate = accessibilityDelegate
                    accessibilityDelegate = object : View.AccessibilityDelegate() {
                        override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                            existingDelegate?.onInitializeAccessibilityNodeInfo(host, info)
                                ?: super.onInitializeAccessibilityNodeInfo(host, info)
                            info.isHeading = true
                        }
                    }
                }
            }
        }
    }

    if (accessibilityDelegate != null) {
        this.accessibilityDelegate = accessibilityDelegate
    }

    props["testID"]?.let { testID ->
        this.setTag(DCFTags.TEST_ID_KEY, testID)
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

    // Transforms - handled in styling like iOS (not in applyLayout)
    // Framework handles this uniformly - NO component-specific glue code needed
    var rotation = 0f
    var translateX = 0f
    var translateY = 0f
    var scaleX = 1f
    var scaleY = 1f
    var hasTransforms = false

    props["rotateInDegrees"]?.let {
        rotation = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        hasTransforms = true
    }

    props["translateX"]?.let {
        translateX = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        hasTransforms = true
    }

    props["translateY"]?.let {
        translateY = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        hasTransforms = true
    }

    props["scale"]?.let {
        val scale = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 1f
            else -> 1f
        }
        scaleX = scale
        scaleY = scale
        hasTransforms = true
    }

    props["scaleX"]?.let {
        scaleX = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 1f
            else -> 1f
        }
        hasTransforms = true
    }

    props["scaleY"]?.let {
        scaleY = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 1f
            else -> 1f
        }
        hasTransforms = true
    }

    if (hasTransforms) {
        // Apply pivot at center for rotation
        this.pivotX = this.width / 2f
        this.pivotY = this.height / 2f
        this.rotation = rotation
        this.translationX = translateX
        this.translationY = translateY
        this.scaleX = scaleX
        this.scaleY = scaleY
    } else {
        // Reset transforms if none specified
        this.rotation = 0f
        this.translationX = 0f
        this.translationY = 0f
        this.scaleX = 1f
        this.scaleY = 1f
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

    this.setTag(DCFTags.GRADIENT_DRAWABLE_KEY, drawable)
    this.background = drawable
}

/**
 * Update gradient layer frame when view bounds change - matching iOS
 */
fun View.updateGradientFrame() {
    val gradientDrawable = this.getTag(DCFTags.GRADIENT_DRAWABLE_KEY) as? GradientDrawable
    gradientDrawable?.let {
        this.invalidate()
    }
}

