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
import android.view.View
import androidx.appcompat.widget.SwitchCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFToggleComponent - Toggle/Switch component matching iOS DCFToggleComponent
 * Uses exact same prop names as iOS for cross-platform consistency
 */
class DCFToggleComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val switchControl = SwitchCompat(context)

        // Apply adaptive theming like iOS
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system colors that adapt to light/dark mode
            // Android handles this automatically with SwitchCompat
        }

        // Store component type
        switchControl.setTag(R.id.dcf_component_type, "Toggle")

        // Apply props
        updateView(switchControl, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        switchControl.applyStyles(nonNullStyleProps)

        return switchControl
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val switchControl = view as? SwitchCompat ?: return false

        // Update value - EXACT iOS prop name
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

        // Update enabled state - EXACT iOS prop name
        props["disabled"]?.let { disabled ->
            val isDisabled = disabled as? Boolean ?: false
            switchControl.isEnabled = !isDisabled
            switchControl.alpha = if (isDisabled) 0.5f else 1.0f
        }

        // Update colors - EXACT iOS prop names

        // Active track color (on tint color in iOS)
        props["activeTrackColor"]?.let { color ->
            val colorInt = parseColor(color)
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            val colors = intArrayOf(colorInt, Color.GRAY)
            switchControl.trackTintList = ColorStateList(states, colors)
        }

        // Inactive track color (background color in iOS)
        props["inactiveTrackColor"]?.let { color ->
            val colorInt = parseColor(color)
            val currentTrackTint = switchControl.trackTintList
            if (currentTrackTint != null) {
                val states = arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                )
                val colors = intArrayOf(
                    currentTrackTint.getColorForState(intArrayOf(android.R.attr.state_checked), Color.BLUE),
                    colorInt
                )
                switchControl.trackTintList = ColorStateList(states, colors)
            }
        }

        // Active thumb color
        props["activeThumbColor"]?.let { color ->
            val colorInt = parseColor(color)
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            val colors = intArrayOf(colorInt, Color.WHITE)
            switchControl.thumbTintList = ColorStateList(states, colors)
        }

        // Inactive thumb color (Note: iOS UISwitch doesn't have separate inactive thumb color)
        props["inactiveThumbColor"]?.let { color ->
            val colorInt = parseColor(color)
            val currentThumbTint = switchControl.thumbTintList
            if (currentThumbTint != null) {
                val states = arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                )
                val colors = intArrayOf(
                    currentThumbTint.getColorForState(
                        intArrayOf(android.R.attr.state_checked),
                        Color.WHITE
                    ),
                    colorInt
                )
                switchControl.thumbTintList = ColorStateList(states, colors)
            }
        }

        // Handle value change callback
        props["onValueChange"]?.let { onChange ->
            switchControl.setOnCheckedChangeListener { _, isChecked ->
                // Store state for framework to handle
                switchControl.setTag(R.id.dcf_toggle_checked_state, isChecked)
                switchControl.setTag(R.id.dcf_event_callback, onChange)
                // The actual callback would be triggered by the framework
            }
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            switchControl.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            switchControl.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }
}
