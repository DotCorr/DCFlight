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
 * DCFButtonComponent - Button component for Android
 * Uses FrameLayout + TextView for consistency
 * ALL styling handled by StyleSheet via .applyStyles() like iOS
 */
class DCFButtonComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFButtonComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Create button container using FrameLayout (View primitive)
        val container = FrameLayout(context)
        
        // Let the system handle visibility naturally - no manual control
        
        // Create text view for the title (Text primitive)
        val textView = TextView(context)
        textView.gravity = Gravity.CENTER
        textView.textSize = 16f
        textView.isAllCaps = false
        
        // Apply adaptive styling - match iOS behavior
        val isAdaptive = (props.filterValues { it != null }.mapValues { it.value!! })["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system button colors that adapt to light/dark mode
            container.setBackgroundColor(
                com.dotcorr.dcflight.utils.ColorUtilities.getSystemColor(
                    context,
                    com.dotcorr.dcflight.utils.ColorUtilities.SystemColorType.ACCENT
                )
            )
            textView.setTextColor(Color.WHITE)
        } else {
            // Non-adaptive default styling
            container.setBackgroundColor(Color.LTGRAY)
            textView.setTextColor(Color.BLACK)
        }
        
        // Add text view to container with centered layout
        val layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        layoutParams.gravity = Gravity.CENTER
        container.addView(textView, layoutParams)
        
        // Set touchable container styling
        container.isClickable = true
        container.isFocusable = true
        
        // Apply initial props - convert nullable to non-nullable
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(container, nonNullProps)

        // Apply StyleSheet properties (UNIFIED with iOS)
        container.applyStyles(nonNullProps)

        // Handle touch feedback (TouchableOpacity style)
        container.setOnTouchListener { view, event ->
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

        // MATCH iOS: Handle onPress events using propagateEvent
        container.setOnClickListener {
            val textView = container.getChildAt(0) as TextView
            Log.d(TAG, "Button clicked: ${textView.text}")
            
            // MATCH iOS: Use propagateEvent for onPress
            propagateEvent(container, "onPress", mapOf(
                "pressed" to true,
                "timestamp" to System.currentTimeMillis() / 1000.0,
                "title" to textView.text.toString()
            ))
        }

        // Store component type for identification
        container.setTag(R.id.dcf_component_type, "Button")

        Log.d(TAG, "Created composed button component")

        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val container = view as? FrameLayout ?: return false
        val textView = container.getChildAt(0) as? TextView ?: return false

        Log.d(TAG, "Updating button with props: $props")

        // 1:1 MATCH Dart DCFButton props:
        
        // "title" prop - matches Dart DCFButtonProps exactly
        props["title"]?.let { title ->
            val titleText = when (title) {
                is String -> title
                else -> title.toString()
            }
            textView.text = titleText
            // ROTATION FIX: Force text redraw after title change
            textView.invalidate()
            textView.requestLayout()
            Log.d(TAG, "Set button title: $titleText")
        }

        // "disabled" prop - matches Dart DCFButtonProps exactly  
        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    container.isEnabled = !disabled
                    container.alpha = if (disabled) 0.5f else 1.0f
                    Log.d(TAG, "Set button disabled: $disabled")
                }
            }
        }

        // "adaptive" prop - matches Dart DCFButtonProps exactly
        props["adaptive"]?.let { adaptive ->
            // Store adaptive flag for potential theme-aware styling
            container.setTag("dcf_adaptive".hashCode(), adaptive)
            Log.d(TAG, "Set button adaptive: $adaptive")
        }

        // Handle text color from styling
        props["color"]?.let { color ->
            val colorInt = when (color) {
                is String -> Color.parseColor(color)
                is Int -> color
                else -> Color.BLACK
            }
            textView.setTextColor(colorInt)
        }

        // Handle background color from styling
        props["backgroundColor"]?.let { backgroundColor ->
            val colorInt = when (backgroundColor) {
                is String -> Color.parseColor(backgroundColor)
                is Int -> backgroundColor
                else -> Color.LTGRAY
            }
            container.setBackgroundColor(colorInt)
        }

        // Apply StyleSheet properties (let flexbox handle centering)
        container.applyStyles(props)

        return true
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val container = view as? FrameLayout ?: return PointF(0f, 0f)
        val textView = container.getChildAt(0) as? TextView ?: return PointF(0f, 0f)

        // Get the current text or use empty string
        val text = textView.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(100f, 50f) // Default button size
        }

        // ROTATION FIX: Force text view to recalculate its layout before measuring
        // This ensures text is properly measured after device rotation
        textView.requestLayout()
        textView.invalidate()
        
        // Force the text view to measure with current configuration
        textView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = textView.measuredWidth.toFloat() + 32f // Add padding
        val measuredHeight = textView.measuredHeight.toFloat() + 16f // Add padding

        Log.d(TAG, "Button intrinsic size: ${measuredWidth}x${measuredHeight} for title: \"$text\"")

        return PointF(max(100f, measuredWidth), max(50f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Button components are typically leaf nodes and don't need special handling
        Log.d(TAG, "Composed button component registered with shadow tree: $nodeId")
    }
}

