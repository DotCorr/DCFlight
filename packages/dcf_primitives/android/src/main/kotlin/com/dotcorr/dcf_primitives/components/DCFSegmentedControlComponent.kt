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
import android.widget.LinearLayout
import android.widget.RadioGroup
import android.widget.RadioButton
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.widget.CompoundButton
import androidx.core.content.ContextCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcf_primitives.utils.AdaptiveColorHelper
import com.dotcorr.dcf_primitives.utils.ColorUtilities

/**
 * DCFSegmentedControlComponent - 1:1 mapping with iOS DCFSegmentedControl
 * Provides segmented control like iOS UISegmentedControl
 */
class DCFSegmentedControlComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val radioGroup = RadioGroup(context)
        radioGroup.orientation = LinearLayout.HORIZONTAL
        
        // Set component identifier
        radioGroup.setTag(R.id.dcf_component_type, "SegmentedControl")
        
        // Apply initial props
        updateView(radioGroup, props)
        return radioGroup
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val radioGroup = view as RadioGroup
        var hasUpdates = false

        // segments prop - array of segment items
        props["segments"]?.let { segments ->
            when (segments) {
                is List<*> -> {
                    // Clear existing segments
                    radioGroup.removeAllViews()
                    
                    segments.forEachIndexed { index, segment ->
                        if (segment is Map<*, *>) {
                            val segmentMap = segment as Map<String, Any?>
                            val radioButton = createSegmentButton(radioGroup.context, segmentMap, index)
                            radioGroup.addView(radioButton)
                        }
                    }
                    hasUpdates = true
                }
            }
        }

        // selectedIndex prop - matches iOS exactly
        props["selectedIndex"]?.let {
            val selectedIndex = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 0
                else -> 0
            }
            
            if (selectedIndex >= 0 && selectedIndex < radioGroup.childCount) {
                val radioButton = radioGroup.getChildAt(selectedIndex) as? RadioButton
                radioButton?.isChecked = true
                hasUpdates = true
            }
        }

        // enabled prop
        props["enabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            
            if (radioGroup.isEnabled != enabled) {
                radioGroup.isEnabled = enabled
                // Also update all child segments
                for (i in 0 until radioGroup.childCount) {
                    radioGroup.getChildAt(i).isEnabled = enabled
                }
                hasUpdates = true
            }
        }

        // backgroundColor prop
        props["backgroundColor"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            radioGroup.setBackgroundColor(colorInt)
            hasUpdates = true
        }

        // selectedTintColor prop - color of selected segment background
        props["selectedTintColor"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            applySelectedTintColor(radioGroup, colorInt)
            hasUpdates = true
        }

        // tintColor prop - text color
        props["tintColor"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            applyTintColor(radioGroup, colorInt)
            hasUpdates = true
        }

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Apply adaptive colors
                val backgroundColor = AdaptiveColorHelper.getSystemBackgroundColor(radioGroup.context)
                val selectedColor = AdaptiveColorHelper.getSystemAccentColor(radioGroup.context)
                val textColor = AdaptiveColorHelper.getSystemTextColor(radioGroup.context)
                
                radioGroup.setBackgroundColor(backgroundColor)
                applySelectedTintColor(radioGroup, selectedColor)
                applyTintColor(radioGroup, textColor)
                hasUpdates = true
            }
        }

        // Set up selection change listener
        radioGroup.setOnCheckedChangeListener { group, checkedId ->
            // Find the index of the checked radio button
            val selectedIndex = (0 until group.childCount).firstOrNull { 
                group.getChildAt(it).id == checkedId 
            } ?: -1
            
            if (selectedIndex >= 0) {
                propagateEvent(group, "onSelectionChange", mapOf(
                    "selectedIndex" to selectedIndex,
                    "segmentId" to checkedId
                ))
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    private fun createSegmentButton(context: Context, segmentData: Map<String, Any?>, index: Int): RadioButton {
        val radioButton = RadioButton(context)
        
        // Set unique ID for this segment
        radioButton.id = View.generateViewId()
        
        // title prop
        segmentData["title"]?.let {
            radioButton.text = it.toString()
        }
        
        // enabled prop for individual segment
        segmentData["enabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            radioButton.isEnabled = enabled
        }
        
        // iconAsset prop - TODO: implement icon support if needed
        segmentData["iconAsset"]?.let {
            // Could load drawable and set as compound drawable
            // For now, just add icon indicator to text
            val iconName = it.toString()
            radioButton.text = "${radioButton.text} ⚡" // Placeholder for icon
        }

        // Style the radio button to look like iOS segmented control
        styleSegmentButton(radioButton, index)
        
        return radioButton
    }

    private fun styleSegmentButton(radioButton: RadioButton, index: Int) {
        // Remove default radio button appearance
        radioButton.buttonDrawable = null
        
        // Set padding
        val padding = 16
        radioButton.setPadding(padding, padding/2, padding, padding/2)
        
        // Center text
        radioButton.gravity = android.view.Gravity.CENTER
        
        // Create background drawable that changes based on state
        val backgroundDrawable = createSegmentBackground()
        radioButton.background = backgroundDrawable
        
        // Set text appearance
        radioButton.setTextColor(ContextCompat.getColorStateList(radioButton.context, android.R.color.primary_text_light))
        radioButton.typeface = Typeface.DEFAULT
    }

    private fun createSegmentBackground(): StateListDrawable {
        val stateList = StateListDrawable()
        
        // Selected state background
        val selectedDrawable = GradientDrawable()
        selectedDrawable.setColor(Color.BLUE) // Default selected color
        selectedDrawable.cornerRadius = 8f
        stateList.addState(intArrayOf(android.R.attr.state_checked), selectedDrawable)
        
        // Normal state background  
        val normalDrawable = GradientDrawable()
        normalDrawable.setColor(Color.TRANSPARENT)
        normalDrawable.setStroke(2, Color.GRAY)
        normalDrawable.cornerRadius = 8f
        stateList.addState(intArrayOf(), normalDrawable)
        
        return stateList
    }

    private fun applySelectedTintColor(radioGroup: RadioGroup, color: Int) {
        for (i in 0 until radioGroup.childCount) {
            val radioButton = radioGroup.getChildAt(i) as? RadioButton
            radioButton?.let { button ->
                val background = button.background as? StateListDrawable
                // Update selected state color - this is simplified
                // In a real implementation, you'd recreate the StateListDrawable
            }
        }
    }

    private fun applyTintColor(radioGroup: RadioGroup, color: Int) {
        for (i in 0 until radioGroup.childCount) {
            val radioButton = radioGroup.getChildAt(i) as? RadioButton
            radioButton?.setTextColor(color)
        }
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val radioGroup = view as? RadioGroup ?: return PointF(0f, 0f)
        
        // Calculate size based on number of segments and content
        val segments = props["segments"] as? List<*> ?: emptyList<Any>()
        val segmentCount = segments.size
        
        // Default segment size
        val segmentWidth = 100f
        val segmentHeight = 32f
        
        val totalWidth = segmentWidth * segmentCount
        
        return PointF(totalWidth, segmentHeight)
    }

    // MARK: - Lifecycle Management - MATCH iOS
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Additional setup when view is registered, if needed
    }
}

