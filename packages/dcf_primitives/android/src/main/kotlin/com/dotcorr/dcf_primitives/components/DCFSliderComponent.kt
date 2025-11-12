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
        
        ColorUtilities.getColor("minimumTrackColor", "primaryColor", props)?.let { colorInt ->
            seekBar.progressTintList = ColorStateList.valueOf(colorInt)
        }
        
        ColorUtilities.getColor("thumbColor", "primaryColor", props)?.let { colorInt ->
            seekBar.thumbTintList = ColorStateList.valueOf(colorInt)
        }
        
        ColorUtilities.getColor("maximumTrackColor", "secondaryColor", props)?.let { colorInt ->
            seekBar.progressBackgroundTintList = ColorStateList.valueOf(colorInt)
        }
        
        seekBar.setTag(R.id.dcf_component_type, "Slider")
        
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser && seekBar != null) {
                    propagateEvent(seekBar, "onValueChange", mapOf(
                        "value" to (progress / 100.0f),
                        "fromUser" to fromUser
                    ))
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                if (seekBar != null) {
                    propagateEvent(seekBar, "onSlidingStart", mapOf())
                }
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                if (seekBar != null) {
                    propagateEvent(seekBar, "onSlidingComplete", mapOf(
                        "value" to (seekBar.progress / 100.0f)
                    ))
                }
            }
        })
        
        updateView(seekBar, props)
        return seekBar
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val seekBar = view as SeekBar
        var hasUpdates = false

        if (hasPropChanged("value", existingProps, props)) {
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
        }

        if (hasPropChanged("minimumValue", existingProps, props)) {
            props["minimumValue"]?.let {
                val minValue = when (it) {
                    is Number -> it.toFloat()
                    is String -> it.toFloatOrNull() ?: 0f
                    else -> 0f
                }
                hasUpdates = true
            }
        }

        if (hasPropChanged("maximumValue", existingProps, props)) {
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
        }

            ColorUtilities.getColor("minimumTrackColor", "primaryColor", props)?.let { colorInt ->
                seekBar.progressTintList = ColorStateList.valueOf(colorInt)
                hasUpdates = true
        }

            ColorUtilities.getColor("thumbColor", "primaryColor", props)?.let { colorInt ->
                seekBar.thumbTintList = ColorStateList.valueOf(colorInt)
                hasUpdates = true
        }

            ColorUtilities.getColor("maximumTrackColor", "secondaryColor", props)?.let { colorInt ->
                seekBar.progressBackgroundTintList = ColorStateList.valueOf(colorInt)
                hasUpdates = true
        }

        view.applyStyles(props)

        return hasUpdates
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val seekBar = view as? SeekBar ?: return PointF(0f, 0f)

        seekBar.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = seekBar.measuredWidth.toFloat()
        val measuredHeight = seekBar.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

