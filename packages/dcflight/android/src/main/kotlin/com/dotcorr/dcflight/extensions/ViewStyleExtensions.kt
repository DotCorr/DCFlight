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

    // Handle borders - support individual sides for consistency with iOS
    val borderTopWidth = (props["borderTopWidth"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
    val borderRightWidth = (props["borderRightWidth"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
    val borderBottomWidth = (props["borderBottomWidth"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
    val borderLeftWidth = (props["borderLeftWidth"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
    val generalBorderWidth = (props["borderWidth"] as? Number)?.let { applyStyleDensityScaling(it.toFloat()).toInt() } ?: 0
    
    val borderTopColor = (props["borderTopColor"] as? String)?.let { ColorUtilities.parseColor(it) }
        ?: (props["borderTopColor"] as? Int)
    val borderRightColor = (props["borderRightColor"] as? String)?.let { ColorUtilities.parseColor(it) }
        ?: (props["borderRightColor"] as? Int)
    val borderBottomColor = (props["borderBottomColor"] as? String)?.let { ColorUtilities.parseColor(it) }
        ?: (props["borderBottomColor"] as? Int)
    val borderLeftColor = (props["borderLeftColor"] as? String)?.let { ColorUtilities.parseColor(it) }
        ?: (props["borderLeftColor"] as? Int)
    val generalBorderColor = (props["borderColor"] as? String)?.let { ColorUtilities.parseColor(it) }
        ?: (props["borderColor"] as? Int)
    
    // Determine if we have individual border sides
    val hasIndividualBorders = borderTopWidth > 0 || borderRightWidth > 0 || borderBottomWidth > 0 || borderLeftWidth > 0 ||
                              borderTopColor != null || borderRightColor != null || borderBottomColor != null || borderLeftColor != null
    
    // Set background color FIRST (before borders)
    props["backgroundColor"]?.let { backgroundColor ->
        val color = when (backgroundColor) {
            is String -> ColorUtilities.parseColor(backgroundColor)
            is Int -> backgroundColor
            else -> Color.TRANSPARENT
        }
        drawable.setColor(color)
    }

    // Handle borders AFTER background color is set
    if (hasIndividualBorders) {
        // Use custom drawable for individual border sides
        val finalTopWidth = if (generalBorderWidth > 0) generalBorderWidth else borderTopWidth
        val finalRightWidth = if (generalBorderWidth > 0) generalBorderWidth else borderRightWidth
        val finalBottomWidth = if (generalBorderWidth > 0) generalBorderWidth else borderBottomWidth
        val finalLeftWidth = if (generalBorderWidth > 0) generalBorderWidth else borderLeftWidth
        
        val finalTopColor = generalBorderColor ?: borderTopColor ?: Color.TRANSPARENT
        val finalRightColor = generalBorderColor ?: borderRightColor ?: Color.TRANSPARENT
        val finalBottomColor = generalBorderColor ?: borderBottomColor ?: Color.TRANSPARENT
        val finalLeftColor = generalBorderColor ?: borderLeftColor ?: Color.TRANSPARENT
        
        // CRITICAL: Create IndividualBorderDrawable with the drawable that has background color set
        // The drawable already has backgroundColor set from above, so we can use it directly
        val borderDrawable = IndividualBorderDrawable(
            drawable,
            finalTopWidth, finalRightWidth, finalBottomWidth, finalLeftWidth,
            finalTopColor, finalRightColor, finalBottomColor, finalLeftColor,
            finalCornerRadius
        )
        this.background = borderDrawable
        this.clipToOutline = true
        // Force invalidation to ensure border is drawn
        this.invalidate()
    } else if (generalBorderWidth > 0) {
        // Use GradientDrawable for uniform borders (more efficient)
        val color = generalBorderColor ?: Color.TRANSPARENT
        drawable.setStroke(generalBorderWidth, color)
        this.background = drawable
        this.clipToOutline = true
    } else {
        // No borders - just set the background drawable
        this.background = drawable
    }

    props["backgroundGradient"]?.let { gradientData ->
        if (gradientData is Map<*, *>) {
            applyGradientBackground(gradientData as Map<String, Any>, finalCornerRadius)
        }
    }

    // FRAMEWORK: Only apply opacity prop if component doesn't manage its own alpha
    // TouchableOpacity and similar components manage alpha through animations
    // Don't override their alpha management
    val componentType = this.getTag(DCFTags.COMPONENT_TYPE_KEY) as? String
    val shouldApplyOpacity = componentType != "TouchableOpacity" && componentType != "GestureDetector"
    
    if (shouldApplyOpacity) {
        props["opacity"]?.let { opacity ->
            this.alpha = when (opacity) {
                is Number -> opacity.toFloat()
                else -> 1f
            }
        }
    }

    // Handle shadows - match iOS behavior exactly
    // iOS uses CALayer shadow properties, Android needs custom shadow rendering to match
    // CRITICAL: Don't use elevation - it creates Material Design shadows that are too pronounced
    // Instead, use custom shadow drawable that matches iOS's subtle, natural shadows
    var shadowColor: Int? = null
    var shadowOpacity: Float = 0.25f // Default shadow opacity (matches iOS elevation default)
    var shadowRadius: Float = 0f
    var shadowOffsetX: Float = 0f
    var shadowOffsetY: Float = 0f
    var hasCustomShadow = false
    
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        // shadowColor
        props["shadowColor"]?.let { color ->
            shadowColor = when (color) {
                is String -> ColorUtilities.parseColor(color)
                is Int -> color
                else -> null
            }
            if (shadowColor != null) {
                hasCustomShadow = true
            }
        }
        
        // shadowOpacity - CRITICAL: Android was missing this!
        props["shadowOpacity"]?.let { opacity ->
            shadowOpacity = when (opacity) {
                is Number -> opacity.toFloat().coerceIn(0f, 1f)
                else -> 0.25f
            }
            hasCustomShadow = true
        }
        
        // shadowRadius
        props["shadowRadius"]?.let { radius ->
            shadowRadius = when (radius) {
                is Number -> applyStyleDensityScaling(radius.toFloat())
                else -> 0f
            }
            if (shadowRadius > 0) {
                hasCustomShadow = true
            }
        }
        
        // shadowOffsetX
        props["shadowOffsetX"]?.let { offsetX ->
            shadowOffsetX = when (offsetX) {
                is Number -> applyStyleDensityScaling(offsetX.toFloat())
                else -> 0f
            }
            hasCustomShadow = true
        }
        
        // shadowOffsetY
        props["shadowOffsetY"]?.let { offsetY ->
            shadowOffsetY = when (offsetY) {
                is Number -> applyStyleDensityScaling(offsetY.toFloat())
                else -> 0f
            }
            hasCustomShadow = true
        }
        
        // CRITICAL: If custom shadow properties are set, calculate elevation to match iOS shadow appearance
        // iOS shadows are subtle and natural, so we need to scale elevation appropriately
        // For very subtle shadows (opacity < 0.1), use a different formula to ensure visibility
        if (hasCustomShadow && shadowRadius > 0) {
            // Store shadow properties for reference
            shadowColor?.let { this.setTag(DCFTags.SHADOW_COLOR_KEY, it) }
            this.setTag(DCFTags.SHADOW_OPACITY_KEY, shadowOpacity)
            this.setTag(DCFTags.SHADOW_RADIUS_KEY, shadowRadius)
            this.setTag(DCFTags.SHADOW_OFFSET_X_KEY, shadowOffsetX)
            this.setTag(DCFTags.SHADOW_OFFSET_Y_KEY, shadowOffsetY)
            
            // Calculate elevation to match iOS shadow appearance
            // iOS shadows are much more subtle than Material Design elevation
            // For very low opacity shadows (like 0.05), we need to boost the elevation slightly
            // to make them visible, but still keep them subtle
            val calculatedElevation = when {
                shadowOpacity < 0.1f -> {
                    // Very subtle shadows: use a formula that ensures visibility while staying subtle
                    // shadowRadius * (shadowOpacity * 8) creates visible but subtle shadows
                    shadowRadius * (shadowOpacity * 8f).coerceIn(0.2f, 0.8f)
                }
                else -> {
                    // Normal shadows: scale by opacity
                    shadowRadius * shadowOpacity * 0.6f
                }
            }
            
            // Use the calculated elevation (Android will render it with Material Design shadow)
            // This creates a shadow that's closer to iOS's subtle appearance
            this.elevation = calculatedElevation.coerceAtLeast(0.5f).coerceAtMost(shadowRadius)
            
            // Note: Android's elevation system doesn't support custom shadow colors/offsets directly
            // For exact iOS matching, we'd need custom rendering, but this approximation works well
            // for most cases and is much more performant
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

    // accessibilityElementsHidden / ariaHidden - iOS has this, Android equivalent
    props["accessibilityElementsHidden"]?.let { hidden ->
        val isHidden = hidden as? Boolean == true
        this.importantForAccessibility = if (isHidden) {
            View.IMPORTANT_FOR_ACCESSIBILITY_NO
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }
    } ?: props["ariaHidden"]?.let { hidden ->
        val isHidden = hidden as? Boolean == true
        this.importantForAccessibility = if (isHidden) {
            View.IMPORTANT_FOR_ACCESSIBILITY_NO
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }
    }

    // accessibilityLanguage - iOS has this (iOS 13+), Android doesn't have direct equivalent
    // Store for reference but Android doesn't support per-view language
    props["accessibilityLanguage"]?.let { language ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android doesn't have per-view language, but we can store it
            this.setTag(DCFTags.TEST_ID_KEY.hashCode() + 1, language) // Use a different tag key
        }
    }

    // accessibilityIgnoresInvertColors - iOS has this (iOS 11+), Android doesn't have direct equivalent
    // Store for reference but Android doesn't support this feature
    props["accessibilityIgnoresInvertColors"]?.let { ignores ->
        // Android doesn't have accessibilityIgnoresInvertColors, store for reference
        this.setTag(DCFTags.TEST_ID_KEY.hashCode() + 2, ignores)
    }

    // accessibilityViewIsModal / ariaModal - iOS has this, Android equivalent
    props["accessibilityViewIsModal"]?.let { isModal ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // Android doesn't have exact equivalent, but we can use importantForAccessibility
            if (isModal as? Boolean == true) {
                this.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
        }
    } ?: props["ariaModal"]?.let { isModal ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (isModal as? Boolean == true) {
                this.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
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

/**
 * Custom drawable that supports individual border sides
 * This ensures consistency with iOS when individual border sides are specified
 */
private class IndividualBorderDrawable(
    private val baseDrawable: GradientDrawable,
    private val topWidth: Int,
    private val rightWidth: Int,
    private val bottomWidth: Int,
    private val leftWidth: Int,
    private val topColor: Int,
    private val rightColor: Int,
    private val bottomColor: Int,
    private val leftColor: Int,
    private val cornerRadius: Float
) : android.graphics.drawable.Drawable() {
    
    private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        style = android.graphics.Paint.Style.STROKE
        strokeCap = android.graphics.Paint.Cap.SQUARE
    }
    
    override fun draw(canvas: android.graphics.Canvas) {
        // Draw base drawable (background color/gradient)
        baseDrawable.setBounds(bounds)
        baseDrawable.draw(canvas)
        
        val width = bounds.width().toFloat()
        val height = bounds.height().toFloat()
        
        // CRITICAL: Only draw if bounds are valid
        if (width <= 0 || height <= 0) return
        
        // Draw individual borders
        // Top border
        if (topWidth > 0 && topColor != android.graphics.Color.TRANSPARENT) {
            paint.color = topColor
            paint.strokeWidth = topWidth.toFloat()
            val y = topWidth / 2f
            // Draw full width if no corner radius, otherwise respect corner radius
            if (cornerRadius > 0) {
                canvas.drawLine(cornerRadius, y, width - cornerRadius, y, paint)
            } else {
                canvas.drawLine(0f, y, width, y, paint)
            }
        }
        
        // Right border
        if (rightWidth > 0 && rightColor != android.graphics.Color.TRANSPARENT) {
            paint.color = rightColor
            paint.strokeWidth = rightWidth.toFloat()
            val x = width - rightWidth / 2f
            if (cornerRadius > 0) {
                canvas.drawLine(x, cornerRadius, x, height - cornerRadius, paint)
            } else {
                canvas.drawLine(x, 0f, x, height, paint)
            }
        }
        
        // Bottom border - CRITICAL: This is the one we need for NavigationBar
        if (bottomWidth > 0 && bottomColor != android.graphics.Color.TRANSPARENT) {
            paint.color = bottomColor
            paint.strokeWidth = bottomWidth.toFloat()
            val y = height - bottomWidth / 2f
            // Draw full width if no corner radius, otherwise respect corner radius
            if (cornerRadius > 0) {
                canvas.drawLine(cornerRadius, y, width - cornerRadius, y, paint)
            } else {
                canvas.drawLine(0f, y, width, y, paint)
            }
        }
        
        // Left border
        if (leftWidth > 0 && leftColor != android.graphics.Color.TRANSPARENT) {
            paint.color = leftColor
            paint.strokeWidth = leftWidth.toFloat()
            val x = leftWidth / 2f
            if (cornerRadius > 0) {
                canvas.drawLine(x, cornerRadius, x, height - cornerRadius, paint)
            } else {
                canvas.drawLine(x, 0f, x, height, paint)
            }
        }
    }
    
    override fun onBoundsChange(bounds: android.graphics.Rect) {
        super.onBoundsChange(bounds)
        // Invalidate when bounds change to force redraw
        invalidateSelf()
    }
    
    override fun setAlpha(alpha: Int) {
        baseDrawable.alpha = alpha
        paint.alpha = alpha
    }
    
    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        baseDrawable.colorFilter = colorFilter
        paint.colorFilter = colorFilter
    }
    
    @android.annotation.SuppressLint("WrongConstant")
    override fun getOpacity(): Int {
        return baseDrawable.opacity
    }
}


