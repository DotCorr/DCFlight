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

/**
 * DCFToggleComponent - Toggle/Switch component matching iOS DCFToggleComponent
 * Uses exact same prop names as iOS for cross-platform consistency
 */
class DCFToggleComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val switchControl = SwitchCompat(context)

        // Let the system handle visibility naturally - no manual control
        
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
            val colorInt = parseColor(color as String)
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            val colors = intArrayOf(colorInt, Color.GRAY)
            switchControl.trackTintList = ColorStateList(states, colors)
        }

        // Inactive track color (background color in iOS)
        props["inactiveTrackColor"]?.let { color ->
            val colorInt = parseColor(color as String)
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
            val colorInt = parseColor(color as String)
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf()
            )
            val colors = intArrayOf(colorInt, Color.WHITE)
            switchControl.thumbTintList = ColorStateList(states, colors)
        }

        // Inactive thumb color (Note: iOS UISwitch doesn't have separate inactive thumb color)
        props["inactiveThumbColor"]?.let { color ->
            val colorInt = parseColor(color as String)
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
        props["onValueChange"]?.let { 
            switchControl.setOnCheckedChangeListener { _, isChecked ->
                // 🚀 MATCH iOS: Use propagateEvent for onValueChange
                propagateEvent(switchControl, "onValueChange", mapOf(
                    "value" to isChecked,
                    "timestamp" to System.currentTimeMillis() / 1000.0
                ))
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

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val switchControl = view as? SwitchCompat ?: return PointF(0f, 0f)

        // Measure the switch content
        switchControl.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = switchControl.measuredWidth.toFloat()
        val measuredHeight = switchControl.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Toggle components are typically leaf nodes and don't need special handling
    }
}
