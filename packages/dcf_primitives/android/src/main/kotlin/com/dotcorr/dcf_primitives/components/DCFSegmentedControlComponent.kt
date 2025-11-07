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
import com.dotcorr.dcflight.utils.AdaptiveColorHelper
import com.dotcorr.dcflight.utils.ColorUtilities

/**
 * DCFSegmentedControlComponent - Segmented control for Android
 */
class DCFSegmentedControlComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val radioGroup = RadioGroup(context)
        radioGroup.orientation = LinearLayout.HORIZONTAL
        
        val primaryColor = props["primaryColor"]?.let { ColorUtilities.parseColor(it.toString()) } 
            ?: com.dotcorr.dcflight.theme.DCFTheme.getAccentColor(context)
        val secondaryColor = props["secondaryColor"]?.let { ColorUtilities.parseColor(it.toString()) } 
            ?: com.dotcorr.dcflight.theme.DCFTheme.getTextColor(context)
        
        radioGroup.setTag(R.id.dcf_component_type, "SegmentedControl")
        
        updateView(radioGroup, props)
        return radioGroup
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val radioGroup = view as RadioGroup
        var hasUpdates = false

        props["segments"]?.let { segments ->
            when (segments) {
                is List<*> -> {
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

        props["enabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            
            if (radioGroup.isEnabled != enabled) {
                radioGroup.isEnabled = enabled
                for (i in 0 until radioGroup.childCount) {
                    radioGroup.getChildAt(i).isEnabled = enabled
                }
                hasUpdates = true
            }
        }

        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // backgroundColor: background color (handled by applyStyles)
        // primaryColor: selected segment color
        // secondaryColor: tint/text color
        
        props["primaryColor"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            applySelectedTintColor(radioGroup, colorInt)
            hasUpdates = true
        }

        props["secondaryColor"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            applyTintColor(radioGroup, colorInt)
            hasUpdates = true
        }
        
        // backgroundColor is handled by applyStyles from StyleSheet

        // Use DCFTheme as fallback (framework colors), not adaptive system colors
        // Framework controls colors - if no semantic colors provided, use DCFTheme defaults
        if (!props.containsKey("primaryColor") && !props.containsKey("secondaryColor")) {
            val selectedColor = com.dotcorr.dcflight.theme.DCFTheme.getAccentColor(radioGroup.context)
            val textColor = com.dotcorr.dcflight.theme.DCFTheme.getTextColor(radioGroup.context)
            
            applySelectedTintColor(radioGroup, selectedColor)
            applyTintColor(radioGroup, textColor)
            hasUpdates = true
        }

        radioGroup.setOnCheckedChangeListener { group, checkedId ->
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

        view.applyStyles(props)

        return hasUpdates
    }

    private fun createSegmentButton(context: Context, segmentData: Map<String, Any?>, index: Int): RadioButton {
        val radioButton = RadioButton(context)
        
        radioButton.id = View.generateViewId()
        
        segmentData["title"]?.let {
            radioButton.text = it.toString()
        }
        
        segmentData["enabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            radioButton.isEnabled = enabled
        }
        
        segmentData["iconAsset"]?.let {
            val iconName = it.toString()
            radioButton.text = "${radioButton.text} ⚡" // Placeholder for icon
        }

        styleSegmentButton(radioButton, index)
        
        return radioButton
    }

    private fun styleSegmentButton(radioButton: RadioButton, index: Int) {
        radioButton.buttonDrawable = null
        
        val padding = 16
        radioButton.setPadding(padding, padding/2, padding, padding/2)
        
        radioButton.gravity = android.view.Gravity.CENTER
        
        val backgroundDrawable = createSegmentBackground(radioButton.context)
        radioButton.background = backgroundDrawable
        
        radioButton.setTextColor(ContextCompat.getColorStateList(radioButton.context, android.R.color.primary_text_light))
        radioButton.typeface = Typeface.DEFAULT
    }

    private fun createSegmentBackground(context: Context): StateListDrawable {
        val stateList = StateListDrawable()
        
        val selectedDrawable = GradientDrawable()
        // Use DCFTheme as default (framework controls colors)
        selectedDrawable.setColor(com.dotcorr.dcflight.theme.DCFTheme.getAccentColor(context))
        selectedDrawable.cornerRadius = 8f
        stateList.addState(intArrayOf(android.R.attr.state_checked), selectedDrawable)

        val normalDrawable = GradientDrawable()
        normalDrawable.setColor(Color.TRANSPARENT)
        // Use DCFTheme as default (framework controls colors)
        normalDrawable.setStroke(2, com.dotcorr.dcflight.theme.DCFTheme.getSurfaceColor(context))
        normalDrawable.cornerRadius = 8f
        stateList.addState(intArrayOf(), normalDrawable)
        
        return stateList
    }

    private fun applySelectedTintColor(radioGroup: RadioGroup, color: Int) {
        for (i in 0 until radioGroup.childCount) {
            val radioButton = radioGroup.getChildAt(i) as? RadioButton
            radioButton?.let { button ->
                val background = button.background as? StateListDrawable
            }
        }
    }

    private fun applyTintColor(radioGroup: RadioGroup, color: Int) {
        for (i in 0 until radioGroup.childCount) {
            val radioButton = radioGroup.getChildAt(i) as? RadioButton
            radioButton?.setTextColor(color)
        }
    }

    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val radioGroup = view as? RadioGroup ?: return PointF(0f, 0f)
        
        val segments = props["segments"] as? List<*> ?: emptyList<Any>()
        val segmentCount = segments.size
        
        val segmentWidth = 100f
        val segmentHeight = 32f
        
        val totalWidth = segmentWidth * segmentCount
        
        return PointF(totalWidth, segmentHeight)
    }

    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }
}

