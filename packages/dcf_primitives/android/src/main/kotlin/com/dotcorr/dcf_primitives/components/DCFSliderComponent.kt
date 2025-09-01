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
import android.graphics.PorterDuff
import android.view.View
import android.widget.SeekBar
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFSliderComponent - Slider component matching iOS DCFSliderComponent
 * Uses exact same prop names as iOS UISlider for cross-platform consistency
 */
class DCFSliderComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val seekBar = SeekBar(context)

        // Store component type
        seekBar.setTag(R.id.dcf_component_type, "Slider")

        // Apply props
        updateView(seekBar, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        seekBar.applyStyles(nonNullStyleProps)

        return seekBar
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val seekBar = view as? SeekBar ?: return false

        // Store min/max values for calculation - EXACT iOS prop names
        val minimumValue = (props["minimumValue"] as? Number)?.toFloat() ?: 0f
        val maximumValue = (props["maximumValue"] as? Number)?.toFloat() ?: 1f

        seekBar.setTag(R.id.dcf_slider_min_value, minimumValue)
        seekBar.setTag(R.id.dcf_slider_max_value, maximumValue)

        // Set the max progress based on range
        val range = maximumValue - minimumValue
        seekBar.max = 1000 // Use 1000 steps for precision

        // Update value - EXACT iOS prop name
        props["value"]?.let { value ->
            when (value) {
                is Number -> {
                    val floatValue = value.toFloat()
                    val normalizedValue = ((floatValue - minimumValue) / range * 1000).toInt()
                    seekBar.progress = normalizedValue.coerceIn(0, 1000)
                }
            }
        }

        // Update disabled state - EXACT iOS prop name
        props["disabled"]?.let { disabled ->
            val isDisabled = disabled as? Boolean ?: false
            seekBar.isEnabled = !isDisabled
            seekBar.alpha = if (isDisabled) 0.5f else 1.0f
        }

        // Update minimum track tint color - EXACT iOS prop name
        props["minimumTrackTintColor"]?.let { color ->
            val colorInt = parseColor(color)
            seekBar.progressTintList = ColorStateList.valueOf(colorInt)
        }

        // Update maximum track tint color - EXACT iOS prop name
        props["maximumTrackTintColor"]?.let { color ->
            val colorInt = parseColor(color)
            seekBar.progressBackgroundTintList = ColorStateList.valueOf(colorInt)
        }

        // Update thumb tint color - EXACT iOS prop name
        props["thumbTintColor"]?.let { color ->
            val colorInt = parseColor(color)
            seekBar.thumbTintList = ColorStateList.valueOf(colorInt)
        }

        // Handle continuous updates - EXACT iOS prop name
        val isContinuous = props["continuous"] as? Boolean ?: true

        // Handle value change events
        props["onValueChange"]?.let { onChange ->
            seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser && isContinuous) {
                        val actualValue = minimumValue + (progress / 1000f) * (maximumValue - minimumValue)
                        seekBar?.setTag(R.id.dcf_slider_value, actualValue)
                        seekBar?.setTag(R.id.dcf_event_callback, onChange)
                        // Framework would handle the actual callback
                    }
                }

                override fun onStartTrackingTouch(seekBar: SeekBar?) {
                    props["onSlidingStart"]?.let { onStart ->
                        seekBar?.setTag(R.id.dcf_event_callback, onStart)
                        // Framework would handle the actual callback
                    }
                }

                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    if (!isContinuous) {
                        val progress = seekBar?.progress ?: 0
                        val actualValue = minimumValue + (progress / 1000f) * (maximumValue - minimumValue)
                        seekBar?.setTag(R.id.dcf_slider_value, actualValue)
                        seekBar?.setTag(R.id.dcf_event_callback, onChange)
                    }

                    props["onSlidingComplete"]?.let { onComplete ->
                        val progress = seekBar?.progress ?: 0
                        val actualValue = minimumValue + (progress / 1000f) * (maximumValue - minimumValue)
                        seekBar?.setTag(R.id.dcf_slider_value, actualValue)
                        seekBar?.setTag(R.id.dcf_event_callback, onComplete)
                        // Framework would handle the actual callback
                    }
                }
            })
        }

        // Step value - EXACT iOS prop name
        props["step"]?.let { step ->
            when (step) {
                is Number -> {
                    // Store step value for discrete slider behavior
                    seekBar.setTag(R.id.dcf_slider_step, step.toFloat())
                }
            }
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            seekBar.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            seekBar.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }
}
