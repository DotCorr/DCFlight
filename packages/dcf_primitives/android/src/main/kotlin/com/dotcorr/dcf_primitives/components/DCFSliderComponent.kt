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
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

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
        
        seekBar.setTag(DCFTags.COMPONENT_TYPE_KEY, "Slider")
        
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

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val seekBar = view as SeekBar
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        mergedProps["value"]?.let {
            val value = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0f
                else -> 0f
            }
            seekBar.progress = (value * 100).toInt()
        }

        mergedProps["maximumValue"]?.let {
            val maxValue = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 100f
                else -> 100f
            }
            seekBar.max = (maxValue * 100).toInt()
        }

        ColorUtilities.getColor("minimumTrackColor", "primaryColor", nonNullProps)?.let { colorInt ->
            seekBar.progressTintList = ColorStateList.valueOf(colorInt)
        }

        ColorUtilities.getColor("thumbColor", "primaryColor", nonNullProps)?.let { colorInt ->
            seekBar.thumbTintList = ColorStateList.valueOf(colorInt)
        }

        ColorUtilities.getColor("maximumTrackColor", "secondaryColor", nonNullProps)?.let { colorInt ->
            seekBar.progressBackgroundTintList = ColorStateList.valueOf(colorInt)
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

