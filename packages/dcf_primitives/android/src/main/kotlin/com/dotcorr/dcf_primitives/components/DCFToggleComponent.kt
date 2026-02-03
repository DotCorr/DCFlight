/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PointF
import android.view.View
import androidx.appcompat.widget.SwitchCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.components.DCFPrimitiveTags
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcf_primitives.components.parseColor

class DCFToggleComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val switchControl = SwitchCompat(context)

        val activeColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
            ?: props["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveTrackColor = ColorUtilities.getColor("inactiveColor", "secondaryColor", props)
            ?: props["secondaryColor"]?.let { parseColor(it.toString()) }
        val activeThumbColor = ColorUtilities.getColor("activeColor", "primaryColor", props)
            ?: props["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveThumbColor = props["tertiaryColor"]?.let { parseColor(it.toString()) }
        
        if (activeColor != null && inactiveTrackColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            switchControl.trackTintList = ColorStateList(states, intArrayOf(activeColor, inactiveTrackColor))
        }
        
        if (activeThumbColor != null && inactiveThumbColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            switchControl.thumbTintList = ColorStateList(states, intArrayOf(activeThumbColor, inactiveThumbColor))
        }

        switchControl.setTag(DCFTags.COMPONENT_TYPE_KEY, "Toggle")

        updateView(switchControl, props)

        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        switchControl.applyStyles(nonNullStyleProps)

        return switchControl
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val switchControl = view as? SwitchCompat ?: return false
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        mergedProps["value"]?.let { value ->
            val isOn = value as? Boolean ?: false
            val animated = mergedProps["animated"] as? Boolean ?: true

            if (animated) {
                switchControl.isChecked = isOn
            } else {
                switchControl.jumpDrawablesToCurrentState()
                switchControl.isChecked = isOn
            }
        }

        mergedProps["disabled"]?.let { disabled ->
            val isDisabled = disabled as? Boolean ?: false
            switchControl.isEnabled = !isDisabled
            switchControl.alpha = if (isDisabled) 0.5f else 1.0f
        }

        val states = arrayOf(
            intArrayOf(android.R.attr.state_checked),
            intArrayOf()
        )
        
        val activeTrackColor = ColorUtilities.getColor("activeColor", "primaryColor", nonNullProps)
            ?: nonNullProps["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveTrackColor = ColorUtilities.getColor("inactiveColor", "secondaryColor", nonNullProps)
            ?: nonNullProps["secondaryColor"]?.let { parseColor(it.toString()) }
        val activeThumbColor = ColorUtilities.getColor("activeColor", "primaryColor", nonNullProps)
            ?: nonNullProps["primaryColor"]?.let { parseColor(it.toString()) }
        val inactiveThumbColor = nonNullProps["tertiaryColor"]?.let { parseColor(it.toString()) }
        
        if (activeTrackColor != null && inactiveTrackColor != null) {
            switchControl.trackTintList = ColorStateList(states, intArrayOf(activeTrackColor, inactiveTrackColor))
        }
        
        if (activeThumbColor != null && inactiveThumbColor != null) {
            switchControl.thumbTintList = ColorStateList(states, intArrayOf(activeThumbColor, inactiveThumbColor))
        }

        props["onValueChange"]?.let { 
            switchControl.setOnCheckedChangeListener { _, isChecked ->
                propagateEvent(switchControl, "onValueChange", mapOf(
                    "value" to isChecked,
                    "timestamp" to System.currentTimeMillis() / 1000.0
                ))
            }
        }

        view.applyStyles(nonNullProps)
        return true
    }


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}
