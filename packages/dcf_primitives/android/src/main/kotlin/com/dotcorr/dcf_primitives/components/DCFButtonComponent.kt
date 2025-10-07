/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.PointF
import android.util.Log
import android.view.Gravity
import android.view.View
import androidx.appcompat.widget.AppCompatButton
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import kotlin.math.max

/**
 * DCFButtonComponent - Button component for Android
 * Uses native AppCompatButton for proper configuration change handling
 * ALL styling handled by StyleSheet via .applyStyles() like iOS
 */
class DCFButtonComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFButtonComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val button = AppCompatButton(context)
        
        button.gravity = Gravity.CENTER
        button.textSize = 16f
        button.isAllCaps = false
        button.setPadding(16, 8, 16, 8) // Match default button padding
        
        val isAdaptive = (props.filterValues { it != null }.mapValues { it.value!! })["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            button.setBackgroundColor(
                com.dotcorr.dcflight.utils.ColorUtilities.getSystemColor(
                    context,
                    com.dotcorr.dcflight.utils.ColorUtilities.SystemColorType.ACCENT
                )
            )
            button.setTextColor(Color.WHITE)
        } else {
            button.setBackgroundColor(Color.LTGRAY)
            button.setTextColor(Color.BLACK)
        }
        
        button.isClickable = true
        button.isFocusable = true
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(button, nonNullProps)

        button.applyStyles(nonNullProps)

        button.setOnTouchListener { view, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    view.alpha = 0.6f // TouchableOpacity effect
                }
                android.view.MotionEvent.ACTION_UP,
                android.view.MotionEvent.ACTION_CANCEL -> {
                    view.alpha = if (view.isEnabled) 1.0f else 0.5f
                }
            }
            false // Allow click to continue
        }

        button.setOnClickListener {
            Log.d(TAG, "Button clicked: ${button.text}")
            
            propagateEvent(button, "onPress", mapOf(
                "pressed" to true,
                "timestamp" to System.currentTimeMillis() / 1000.0,
                "title" to button.text.toString()
            ))
        }

        button.setTag(R.id.dcf_component_type, "Button")

        Log.d(TAG, "Created native AppCompatButton component")

        return button
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val button = view as? AppCompatButton ?: return false

        Log.d(TAG, "Updating button with props: $props")

        
        props["title"]?.let { title ->
            val titleText = when (title) {
                is String -> title
                else -> title.toString()
            }
            button.text = titleText
            Log.d(TAG, "Set button title: $titleText")
        }

        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    button.isEnabled = !disabled
                    button.alpha = if (disabled) 0.5f else 1.0f
                    Log.d(TAG, "Set button disabled: $disabled")
                }
            }
        }

        props["adaptive"]?.let { adaptive ->
            button.setTag("dcf_adaptive".hashCode(), adaptive)
            Log.d(TAG, "Set button adaptive: $adaptive")
        }

        props["color"]?.let { color ->
            val colorInt = when (color) {
                is String -> Color.parseColor(color)
                is Int -> color
                else -> Color.BLACK
            }
            button.setTextColor(colorInt)
        }

        props["backgroundColor"]?.let { backgroundColor ->
            val colorInt = when (backgroundColor) {
                is String -> Color.parseColor(backgroundColor)
                is Int -> backgroundColor
                else -> Color.LTGRAY
            }
            button.setBackgroundColor(colorInt)
        }

        button.applyStyles(props)

        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val button = view as? AppCompatButton ?: return PointF(0f, 0f)

        val text = button.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(100f, 50f) // Default button size
        }

        button.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = button.measuredWidth.toFloat()
        val measuredHeight = button.measuredHeight.toFloat()

        Log.d(TAG, "Button intrinsic size: ${measuredWidth}x${measuredHeight} for title: \"$text\"")

        return PointF(max(100f, measuredWidth), max(50f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Native button component registered with shadow tree: $nodeId")
    }
}

