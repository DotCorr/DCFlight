/*
 * Copyright (c) Dotcorr Studi        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        checkBox.applyStyles(nonNullStyleProps) and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.view.View
import androidx.appcompat.widget.AppCompatCheckBox
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFCheckboxComponent - Checkbox component matching iOS DCFCheckboxComponent
 * Uses exact same prop names as iOS for cross-platform consistency
 */
class DCFCheckboxComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val checkbox = AppCompatCheckBox(context)

        // Store component type
        checkbox.setTag(R.id.dcf_component_type, "Checkbox")

        // Apply props
        updateView(checkbox, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        checkbox.applyStyles(nonNullStyleProps)

        return checkbox
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val checkbox = view as? AppCompatCheckBox ?: return false

        // value - EXACT iOS prop name (the checked state)
        props["value"]?.let { value ->
            checkbox.isChecked = value as? Boolean ?: false
        }

        // disabled - EXACT iOS prop name
        props["disabled"]?.let { disabled ->
            val isDisabled = disabled as? Boolean ?: false
            checkbox.isEnabled = !isDisabled
            checkbox.alpha = if (isDisabled) 0.5f else 1.0f
        }

        // onValueChange - EXACT iOS prop name (callback when value changes)
        props["onValueChange"]?.let { onChange ->
            checkbox.setOnCheckedChangeListener { _, isChecked ->
                // Store state for framework to handle
                checkbox.setTag(R.id.dcf_checkbox_checked_state, isChecked)
                checkbox.setTag(R.id.dcf_event_callback, onChange)
                // The actual callback would be triggered by the framework
            }
        }

        // tintColor - EXACT iOS prop name (checkbox color)
        props["tintColor"]?.let { color ->
            val colorInt = parseColor(color)
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf(-android.R.attr.state_checked)
            )
            val colors = intArrayOf(colorInt, Color.GRAY)
            checkbox.buttonTintList = ColorStateList(states, colors)
        }

        // onTintColor - iOS prop name (color when checked)
        props["onTintColor"]?.let { color ->
            val colorInt = parseColor(color)
            val currentTintList = checkbox.buttonTintList
            if (currentTintList != null) {
                val states = arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf(-android.R.attr.state_checked)
                )
                val uncheckedColor = currentTintList.getColorForState(
                    intArrayOf(-android.R.attr.state_checked),
                    Color.GRAY
                )
                val colors = intArrayOf(colorInt, uncheckedColor)
                checkbox.buttonTintList = ColorStateList(states, colors)
            } else {
                val states = arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf(-android.R.attr.state_checked)
                )
                val colors = intArrayOf(colorInt, Color.GRAY)
                checkbox.buttonTintList = ColorStateList(states, colors)
            }
        }

        // title - iOS prop name (label text for checkbox)
        props["title"]?.let { title ->
            checkbox.text = title.toString()
        }

        // titleColor - iOS prop name (label text color)
        props["titleColor"]?.let { color ->
            checkbox.setTextColor(parseColor(color))
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            checkbox.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            checkbox.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }
}
