/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.PointF
import android.view.View
import android.widget.SeekBar
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFSliderComponent - 1:1 mapping with iOS DCFSliderComponent
 * Uses exact same prop names as iOS UISlider for cross-platform consistency
 */
class DCFSliderComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val seekBar = SeekBar(context)
        
        // Apply adaptive default styling - let OS handle light/dark mode
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system colors that automatically adapt to light/dark mode
            // SeekBar automatically uses theme colors in newer Android versions
        }
        
        // Set component identifier for debugging
        seekBar.setTag(R.id.dcf_component_type, "Slider")
        
        // Set up iOS-style onValueChange event
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser && seekBar != null) {
                    // 🚀 MATCH iOS: Use propagateEvent for onValueChange
                    propagateEvent(seekBar, "onValueChange", mapOf(
                        "value" to (progress / 100.0f),
                        "fromUser" to fromUser
                    ))
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                // iOS equivalent of touchDown
                if (seekBar != null) {
                    propagateEvent(seekBar, "onSlidingStart", mapOf())
                }
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                // iOS equivalent of touchUp
                if (seekBar != null) {
                    propagateEvent(seekBar, "onSlidingComplete", mapOf(
                        "value" to (seekBar.progress / 100.0f)
                    ))
                }
            }
        })
        
        // Apply initial props and return
        updateView(seekBar, props)
        return seekBar
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val seekBar = view as SeekBar
        var hasUpdates = false

        // 🚀 MATCH iOS UISlider props exactly
        props["value"]?.let {
            val value = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            val progress = (value * 100).toInt()
            if (seekBar.progress != progress) {
                seekBar.progress = progress
                hasUpdates = true
            }
        }

        props["minimumValue"]?.let {
            val minValue = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            // SeekBar min is always 0, we handle offset in value calculation
            hasUpdates = true
        }

        props["maximumValue"]?.let {
            val maxValue = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 100f
                else -> 100f
            }
            val maxProgress = (maxValue * 100).toInt()
            if (seekBar.max != maxProgress) {
                seekBar.max = maxProgress
                hasUpdates = true
            }
        }

        // iOS minimumTrackTintColor -> Android progress tint
        props["minimumTrackTintColor"]?.let {
            val colorStr = it as? String
            colorStr?.let { color ->
                try {
                    val colorInt = ColorUtilities.parseColor(color)
                    seekBar.progressTintList = ColorStateList.valueOf(colorInt)
                    hasUpdates = true
                } catch (e: Exception) {
                    // Invalid color format
                }
            }
        }

        // iOS maximumTrackTintColor -> Android progress background tint  
        props["maximumTrackTintColor"]?.let {
            val colorStr = it as? String
            colorStr?.let { color ->
                try {
                    val colorInt = ColorUtilities.parseColor(color)
                    seekBar.progressBackgroundTintList = ColorStateList.valueOf(colorInt)
                    hasUpdates = true
                } catch (e: Exception) {
                    // Invalid color format
                }
            }
        }

        // iOS thumbTintColor -> Android thumb tint
        props["thumbTintColor"]?.let {
            val colorStr = it as? String
            colorStr?.let { color ->
                try {
                    val colorInt = ColorUtilities.parseColor(color)
                    seekBar.thumbTintList = ColorStateList.valueOf(colorInt)
                    hasUpdates = true
                } catch (e: Exception) {
                    // Invalid color format
                }
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val seekBar = view as? SeekBar ?: return PointF(0f, 0f)

        // Measure the slider content
        seekBar.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = seekBar.measuredWidth.toFloat()
        val measuredHeight = seekBar.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Slider components are typically leaf nodes and don't need special handling
    }
}

