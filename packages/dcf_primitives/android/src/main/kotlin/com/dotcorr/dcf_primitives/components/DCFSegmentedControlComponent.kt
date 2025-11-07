/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.animation.ValueAnimator
import android.animation.ArgbEvaluator
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcflight.utils.ColorUtilities

/**
 * DCFSegmentedControlComponent - Material Design segmented control for Android
 * Uses proper Material Design segmented button style (not RadioGroup)
 */
class DCFSegmentedControlComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val container = LinearLayout(context)
        container.orientation = LinearLayout.HORIZONTAL
        container.setTag(R.id.dcf_component_type, "SegmentedControl")
        
        updateView(container, props)
        return container
    }

    // Remove override - let base class handle props merging

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val container = view as LinearLayout
        var hasUpdates = false

        // Get colors from StyleSheet
        val primaryColor = props["primaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val secondaryColor = props["secondaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val selectedIndex = when (val idx = props["selectedIndex"]) {
            is Number -> idx.toInt()
            is String -> idx.toIntOrNull() ?: 0
            else -> 0
        }
        val enabled = when (val en = props["enabled"]) {
            is Boolean -> en
            is String -> en.toBoolean()
            else -> true
        }

        // Framework-level helper: Only update segments if they actually changed
        if (hasPropChanged("segments", existingProps, props)) {
            props["segments"]?.let { segments ->
                when (segments) {
                    is List<*> -> {
                        container.removeAllViews()
                        
                        segments.forEachIndexed { index, segment ->
                            if (segment is Map<*, *>) {
                                val segmentMap = segment as Map<String, Any?>
                                val segmentButton = createSegmentButton(
                                    container.context, 
                                    segmentMap, 
                                    index,
                                    index == selectedIndex,
                                    primaryColor,
                                    secondaryColor,
                                    enabled
                                )
                                container.addView(segmentButton)
                            }
                        }
                        hasUpdates = true
                    }
                }
            }
        } else {
            // Update existing segments if selectedIndex or colors changed
            if (hasPropChanged("selectedIndex", existingProps, props) || 
                hasPropChanged("primaryColor", existingProps, props) ||
                hasPropChanged("secondaryColor", existingProps, props) ||
                hasPropChanged("enabled", existingProps, props)) {
                for (i in 0 until container.childCount) {
                    val segmentButton = container.getChildAt(i) as? TextView
                    segmentButton?.let {
                        updateSegmentButton(it, i == selectedIndex, primaryColor, secondaryColor, enabled)
                    }
                }
                hasUpdates = true
            }
        }

        view.applyStyles(props)

        return hasUpdates
    }

    private fun createSegmentButton(
        context: Context, 
        segmentData: Map<String, Any?>, 
        index: Int,
        isSelected: Boolean,
        primaryColor: Int?,
        secondaryColor: Int?,
        enabled: Boolean
    ): TextView {
        val button = TextView(context)
        button.id = View.generateViewId()
        
        segmentData["title"]?.let {
            button.text = it.toString()
        }
        
        segmentData["iconAsset"]?.let {
            val iconName = it.toString()
            button.text = "${button.text} ⚡" // Placeholder for icon
        }

        val segmentEnabled = when (val en = segmentData["enabled"]) {
            is Boolean -> en && enabled
            is String -> en.toBoolean() && enabled
            else -> enabled
        }
        button.isEnabled = segmentEnabled
        button.alpha = if (segmentEnabled) 1.0f else 0.38f // Material Design disabled opacity
        
        // Material Design 3 segmented button styling
        val density = context.resources.displayMetrics.density
        val horizontalPadding = (16 * density).toInt()
        val verticalPadding = (12 * density).toInt()
        button.setPadding(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding)
        button.gravity = Gravity.CENTER
        button.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) // Material Design medium weight
        button.textSize = 14f // Material Design body2 text size
        
        // Set click listener with ripple effect
        button.setOnClickListener {
            if (!segmentEnabled) return@setOnClickListener
            
            val container = button.parent as? ViewGroup
            container?.let { parent ->
                // Get current props from stored props (via base class) with fallback to closure-scoped values
                val storedProps = getStoredProps(parent)
                val currentPrimaryColor = storedProps["primaryColor"]?.let { 
                    ColorUtilities.parseColor(it.toString()) 
                } ?: primaryColor
                val currentSecondaryColor = storedProps["secondaryColor"]?.let { 
                    ColorUtilities.parseColor(it.toString()) 
                } ?: secondaryColor
                val currentEnabled = when (val en = storedProps["enabled"]) {
                    is Boolean -> en
                    is String -> en.toBoolean()
                    else -> enabled
                }
                
                // Animate selection change
                animateSegmentSelection(parent, button, currentPrimaryColor, currentSecondaryColor, currentEnabled)
                
                // Fire event
                val selectedIndex = (0 until parent.childCount).indexOfFirst { 
                    parent.getChildAt(it).id == button.id 
                }
                if (selectedIndex >= 0) {
                    propagateEvent(parent, "onSelectionChange", mapOf(
                        "selectedIndex" to selectedIndex,
                        "selectedTitle" to button.text.toString()
                    ))
                }
            }
        }
        
        updateSegmentButton(button, isSelected, primaryColor, secondaryColor, enabled, true)
        
        return button
    }
    
    private fun animateSegmentSelection(
        container: ViewGroup,
        selectedButton: TextView,
        primaryColor: Int?,
        secondaryColor: Int?,
        enabled: Boolean
    ) {
        for (i in 0 until container.childCount) {
            val child = container.getChildAt(i) as? TextView
            if (child != null) {
                val isChildSelected = (child.id == selectedButton.id)
                val wasSelected = child.tag as? Boolean ?: false
                
                // Animate color transition if state changed
                if (wasSelected != isChildSelected) {
                    animateButtonState(child, wasSelected, isChildSelected, primaryColor, secondaryColor, enabled)
                } else {
                    updateSegmentButton(child, isChildSelected, primaryColor, secondaryColor, enabled, false)
                }
                
                child.tag = isChildSelected
            }
        }
    }
    
    private fun animateButtonState(
        button: TextView,
        wasSelected: Boolean,
        isSelected: Boolean,
        primaryColor: Int?,
        secondaryColor: Int?,
        enabled: Boolean
    ) {
        val targetBgColor = if (isSelected) {
            primaryColor ?: Color.parseColor("#2196F3")
        } else {
            Color.TRANSPARENT
        }
        val targetTextColor = if (isSelected) {
            Color.WHITE
        } else {
            secondaryColor ?: Color.parseColor("#000000")
        }
        
        // Get current colors
        val currentBgColor = if (wasSelected) {
            primaryColor ?: Color.parseColor("#2196F3")
        } else {
            Color.TRANSPARENT
        }
        val currentTextColor = button.currentTextColor
        
        // Animate background color
        val bgAnimator = ValueAnimator.ofObject(ArgbEvaluator(), currentBgColor, targetBgColor)
        bgAnimator.duration = 200 // Material Design animation duration
        bgAnimator.addUpdateListener { animator ->
            val animatedColor = animator.animatedValue as Int
            val drawable = GradientDrawable()
            drawable.setColor(animatedColor)
            val cornerRadius = 8f * button.context.resources.displayMetrics.density
            drawable.cornerRadius = cornerRadius
            
            // Add ripple effect
            val rippleColor = if (isSelected) {
                Color.argb(30, 255, 255, 255) // White ripple on selected
            } else {
                Color.argb(30, 0, 0, 0) // Black ripple on unselected
            }
            val ripple = RippleDrawable(
                android.content.res.ColorStateList.valueOf(rippleColor),
                drawable,
                null
            )
            button.background = ripple
        }
        bgAnimator.start()
        
        // Animate text color
        val textAnimator = ValueAnimator.ofObject(ArgbEvaluator(), currentTextColor, targetTextColor)
        textAnimator.duration = 200
        textAnimator.addUpdateListener { animator ->
            button.setTextColor(animator.animatedValue as Int)
        }
        textAnimator.start()
    }

    private fun updateSegmentButton(
        button: TextView,
        isSelected: Boolean,
        primaryColor: Int?,
        secondaryColor: Int?,
        enabled: Boolean,
        animate: Boolean = false
    ) {
        val density = button.context.resources.displayMetrics.density
        val cornerRadius = 8f * density
        
        val backgroundDrawable = GradientDrawable()
        
        if (isSelected) {
            // Selected state: Material Design primary color background
            val bgColor = primaryColor ?: Color.parseColor("#2196F3")
            backgroundDrawable.setColor(bgColor)
            button.setTextColor(Color.WHITE)
            
            // Add ripple effect for selected state (white ripple)
            val rippleColor = Color.argb(30, 255, 255, 255)
            val ripple = RippleDrawable(
                android.content.res.ColorStateList.valueOf(rippleColor),
                backgroundDrawable,
                null
            )
            ripple.setCornerRadius(cornerRadius)
            button.background = ripple
        } else {
            // Unselected state: Transparent background with border
            backgroundDrawable.setColor(Color.TRANSPARENT)
            val textColor = secondaryColor ?: Color.parseColor("#000000")
            button.setTextColor(textColor)
            
            // Add subtle border for unselected state (Material Design 3 style)
            val borderColor = Color.argb(30, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
            backgroundDrawable.setStroke((1 * density).toInt(), borderColor)
            
            // Add ripple effect for unselected state (black ripple)
            val rippleColor = Color.argb(20, 0, 0, 0)
            val ripple = RippleDrawable(
                android.content.res.ColorStateList.valueOf(rippleColor),
                backgroundDrawable,
                null
            )
            ripple.setCornerRadius(cornerRadius)
            button.background = ripple
        }
        
        backgroundDrawable.cornerRadius = cornerRadius
        button.isEnabled = enabled
        button.alpha = if (enabled) 1.0f else 0.38f // Material Design disabled opacity
        button.tag = isSelected // Store selection state for animation
    }

    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val container = view as? LinearLayout ?: return PointF(0f, 0f)
        
        val segments = props["segments"] as? List<*> ?: emptyList<Any>()
        val segmentCount = segments.size
        
        // Material Design 3 segmented button sizing
        val density = container.context.resources.displayMetrics.density
        val minSegmentWidth = 80f * density
        val segmentHeight = 40f * density // Material Design 3 segmented button height
        
        // Calculate total width based on segment count
        val totalWidth = minSegmentWidth * segmentCount
        
        return PointF(totalWidth, segmentHeight)
    }

    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

