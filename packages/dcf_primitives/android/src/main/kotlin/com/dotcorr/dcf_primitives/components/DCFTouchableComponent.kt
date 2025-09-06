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
import android.widget.FrameLayout
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import kotlin.math.max

/**
 * TouchableOpacity-style button component using low-level primitives
 * Uses FrameLayout container with TextView for guaranteed text visibility
 * Avoids Android Button complexities that cause text visibility issues
 */
class DCFTouchableComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTouchableComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Create container using FrameLayout (like TouchableOpacity)
        val container = FrameLayout(context)
        
        // Create text view for the title
        val textView = TextView(context)
        textView.gravity = Gravity.CENTER
        textView.setTextColor(Color.BLACK)
        textView.textSize = 16f
        
        // Add text view to container
        val layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        container.addView(textView, layoutParams)
        
        // Set default touchable styling
        container.setBackgroundColor(Color.LTGRAY)
        container.isClickable = true
        container.isFocusable = true
        
        // Apply initial props
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(container, nonNullProps)

        // Apply StyleSheet properties
        container.applyStyles(nonNullProps)

        // Handle touch events with opacity feedback
        container.setOnTouchListener { view, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    view.alpha = 0.6f // TouchableOpacity effect
                }
                android.view.MotionEvent.ACTION_UP,
                android.view.MotionEvent.ACTION_CANCEL -> {
                    view.alpha = 1.0f
                }
            }
            false // Allow click to continue
        }

        // Handle onPress events
        container.setOnClickListener {
            val textView = container.getChildAt(0) as TextView
            Log.d(TAG, "Touchable clicked: ${textView.text}")
            
            propagateEvent(container, "onPress", mapOf(
                "pressed" to true,
                "timestamp" to System.currentTimeMillis() / 1000.0,
                "title" to textView.text.toString()
            ))
        }

        // Store component type
        container.setTag(R.id.dcf_component_type, "Touchable")

        Log.d(TAG, "Created touchable component")

        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val container = view as? FrameLayout ?: return false
        val textView = container.getChildAt(0) as? TextView ?: return false

        Log.d(TAG, "Updating touchable with props: $props")

        // Handle title prop
        props["title"]?.let { title ->
            val titleText = when (title) {
                is String -> title
                else -> title.toString()
            }
            textView.text = titleText
            Log.d(TAG, "Set touchable title: $titleText")
        }

        // Handle disabled prop
        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    container.isEnabled = !disabled
                    container.alpha = if (disabled) 0.5f else 1.0f
                    Log.d(TAG, "Set touchable disabled: $disabled")
                }
            }
        }

        // Handle text color
        props["color"]?.let { color ->
            val colorInt = when (color) {
                is String -> Color.parseColor(color)
                is Int -> color
                else -> Color.BLACK
            }
            textView.setTextColor(colorInt)
        }

        // Handle background color
        props["backgroundColor"]?.let { backgroundColor ->
            val colorInt = when (backgroundColor) {
                is String -> Color.parseColor(backgroundColor)
                is Int -> backgroundColor
                else -> Color.LTGRAY
            }
            container.setBackgroundColor(colorInt)
        }

        // Apply StyleSheet properties
        container.applyStyles(props)

        return true
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val container = view as? FrameLayout ?: return PointF(0f, 0f)
        val textView = container.getChildAt(0) as? TextView ?: return PointF(0f, 0f)

        val text = textView.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(100f, 50f) // Default size
        }

        // Measure the text view
        textView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = textView.measuredWidth.toFloat() + 32f // Add padding
        val measuredHeight = textView.measuredHeight.toFloat() + 16f // Add padding

        Log.d(TAG, "Touchable intrinsic size: ${measuredWidth}x${measuredHeight} for title: \"$text\"")

        return PointF(max(100f, measuredWidth), max(50f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Touchable component registered with shadow tree: $nodeId")
    }
}
