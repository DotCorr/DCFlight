/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PointF
import android.view.View
import androidx.appcompat.widget.SwitchCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcf_primitives.components.parseColor

/**
 * DCFToggleComponent - Toggle/Switch component matching iOS DCFToggleComponent
 * Uses exact same prop names as iOS for cross-platform consistency
 */
class DCFToggleComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val switchControl = SwitchCompat(context)

        // COLOR SYSTEM: Explicit color override > Semantic color
        // activeColor (explicit) > primaryColor (semantic)
        val activeColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
            ?: props["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveTrackColor = ColorUtilities.getColor("inactiveColor", "secondaryColor", props)
            ?: props["secondaryColor"]?.let { parseColor(it.toString()) }
        val activeThumbColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
            ?: props["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveThumbColor = props["tertiaryColor"]?.let { parseColor(it.toString()) }
        
        // Only set colors if StyleSheet provided them (should always be the case)
        if (activeColor != null && inactiveTrackColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            switchControl.trackTintList = ColorStateList(states, intArrayOf(activeColor, inactiveTrackColor))
        }
        // NO FALLBACK: If colors missing, don't set ColorStateList (StyleSheet should always provide)
        
        if (activeThumbColor != null && inactiveThumbColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            switchControl.thumbTintList = ColorStateList(states, intArrayOf(activeThumbColor, inactiveThumbColor))
        }
        // NO FALLBACK: If colors missing, don't set ColorStateList (StyleSheet should always provide)

        switchControl.setTag(R.id.dcf_component_type, "Toggle")

        updateView(switchControl, props)

        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        switchControl.applyStyles(nonNullStyleProps)

        return switchControl
    }

    // Remove override - let base class handle props merging

    override protected fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val switchControl = view as? SwitchCompat ?: return false

        // Framework-level helper: Only update value if it actually changed
        if (hasPropChanged("value", existingProps, props)) {
            props["value"]?.let { value ->
                val isOn = value as? Boolean ?: false
                val animated = props["animated"] as? Boolean ?: true

                if (animated) {
                    switchControl.isChecked = isOn
                } else {
                    switchControl.jumpDrawablesToCurrentState()
                    switchControl.isChecked = isOn
                }
            }
        }

        // Framework-level helper: Only update disabled if it actually changed
        if (hasPropChanged("disabled", existingProps, props)) {
            props["disabled"]?.let { disabled ->
                val isDisabled = disabled as? Boolean ?: false
                switchControl.isEnabled = !isDisabled
                switchControl.alpha = if (isDisabled) 0.5f else 1.0f
            }
        }


        // Framework-level helper: Only update colors if they actually changed
        if (hasPropChanged("activeColor", existingProps, props) ||
            hasPropChanged("inactiveColor", existingProps, props) ||
            hasPropChanged("primaryColor", existingProps, props) || 
            hasPropChanged("secondaryColor", existingProps, props) ||
            hasPropChanged("tertiaryColor", existingProps, props)) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            
            // COLOR SYSTEM: Explicit color override > Semantic color
            // activeColor (explicit) > primaryColor (semantic)
            val activeTrackColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
                ?: props["primaryColor"]?.let { parseColor(it as String) }
            // inactiveColor (explicit) > secondaryColor (semantic)
            val inactiveTrackColor = ColorUtilities.getColor("inactiveColor", "secondaryColor", props)
                ?: props["secondaryColor"]?.let { parseColor(it as String) }
            val activeThumbColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
                ?: props["primaryColor"]?.let { parseColor(it as String) }
            val inactiveThumbColor = props["tertiaryColor"]?.let { parseColor(it as String) }
            
            if (activeTrackColor != null && inactiveTrackColor != null) {
                switchControl.trackTintList = ColorStateList(states, intArrayOf(activeTrackColor, inactiveTrackColor))
            }
            
            if (activeThumbColor != null && inactiveThumbColor != null) {
                switchControl.thumbTintList = ColorStateList(states, intArrayOf(activeThumbColor, inactiveThumbColor))
            }
        }

        props["onValueChange"]?.let { 
            switchControl.setOnCheckedChangeListener { _, isChecked ->
                propagateEvent(switchControl, "onValueChange", mapOf(
                    "value" to isChecked,
                    "timestamp" to System.currentTimeMillis() / 1000.0
                ))
            }
        }

        props["accessibilityLabel"]?.let { label ->
            switchControl.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            switchControl.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val switchControl = view as? SwitchCompat ?: return PointF(0f, 0f)

        switchControl.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = switchControl.measuredWidth.toFloat()
        val measuredHeight = switchControl.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}
