/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.util.Log
import android.view.View
import androidx.appcompat.widget.AppCompatButton
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R
import kotlin.math.max

/**
 * EXACT iOS DCFButtonComponent port for Android
 * Matches iOS DCFButtonComponent.swift behavior 1:1
 * ONLY implements props that iOS DCFButtonComponent has:
 * - title: String
 * - disabled: Boolean
 * ALL styling handled by StyleSheet via .applyStyles() like iOS
 */
class DCFButtonComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFButtonComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val button = AppCompatButton(context)

        // iOS-style button defaults
        button.isAllCaps = false
        
        // Set iOS system colors as defaults - MATCH iOS exactly
        ColorUtilities.color("#007AFF")?.let { button.setBackgroundColor(it) }
        ColorUtilities.color("#FFFFFF")?.let { button.setTextColor(it) }

        // Apply initial props - convert nullable to non-nullable
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(button, nonNullProps)

        // Apply StyleSheet properties (UNIFIED with iOS)
        button.applyStyles(nonNullProps)

        // MATCH iOS: Handle onPress events using propagateEvent
        button.setOnClickListener {
            Log.d(TAG, "Button clicked: ${button.text}")
            
            // MATCH iOS: Use propagateEvent for onPress
            propagateEvent(button, "onPress", mapOf(
                "pressed" to true,
                "timestamp" to System.currentTimeMillis() / 1000.0,
                "buttonTitle" to button.text.toString()
            ))
        }

        // Store component type for identification
        button.setTag(R.id.dcf_component_type, "Button")

        Log.d(TAG, "Created button component with title: ${button.text}")

        return button
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val button = view as? AppCompatButton ?: return false

        Log.d(TAG, "Updating button with props: $props")

        // 1:1 MATCH iOS DCFButtonComponent props:
        
        // "title" prop - matches iOS exactly
        props["title"]?.let { title ->
            val titleText = when (title) {
                is String -> title
                else -> title.toString()
            }
            button.text = titleText
            Log.d(TAG, "Set button title: $titleText")
        }

        // "disabled" prop - matches iOS exactly  
        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    button.isEnabled = !disabled
                    button.alpha = if (disabled) 0.5f else 1.0f
                    Log.d(TAG, "Set button disabled: $disabled")
                }
            }
        }

        // Apply StyleSheet properties
        button.applyStyles(props)

        return true
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val button = view as? AppCompatButton ?: return PointF(0f, 0f)

        // Get the current text or use empty string
        val text = button.text?.toString() ?: ""
        
        if (text.isEmpty()) {
            return PointF(0f, 0f)
        }

        // Measure the button content
        button.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = button.measuredWidth.toFloat()
        val measuredHeight = button.measuredHeight.toFloat()

        Log.d(TAG, "Button intrinsic size: ${measuredWidth}x${measuredHeight} for title: \"$text\"")

        return PointF(max(1f, measuredWidth), max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Button components are typically leaf nodes and don't need special handling
        Log.d(TAG, "Button component registered with shadow tree: $nodeId")
    }
}
