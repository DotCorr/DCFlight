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
import com.dotcorr.dcflight.utils.ColorUtilities
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
        
        // NO FALLBACK: backgroundColor and primaryColor come from StyleSheet only
        // StyleSheet will always provide these via toMap() fallbacks
        
        button.isClickable = true
        button.isFocusable = true
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        
        // Set initial title if provided
        props["title"]?.let { title ->
            val titleText = when (title) {
                is String -> title
                else -> title.toString()
            }
            button.text = titleText
            Log.d(TAG, "Set initial button title: $titleText")
        }
        
        // CRITICAL: Store props FIRST before calling updateView
        // This ensures updateViewInternal has access to all props including primaryColor
        storeProps(button, props)
        
        // Use updateView to ensure props are stored and merged correctly
        // This will call updateViewInternal which will set text color (ensuring it's not overridden)
        // CRITICAL: updateView merges props and ensures primaryColor from StyleSheet.toMap() is available
        updateView(button, props)
        
        // After updateView, get the merged props (which should include primaryColor from StyleSheet.toMap())
        val mergedProps = getStoredProps(button)
        val nonNullMergedProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        button.applyStyles(nonNullMergedProps)
        
        // CRITICAL: Set text color AFTER updateView and applyStyles to ensure it's the final operation
        // Use merged props which should include primaryColor from StyleSheet.toMap() fallback
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // StyleSheet.toMap() ALWAYS provides primaryColor via DCFTheme.textColor fallback
        mergedProps["primaryColor"]?.let { color ->
            val colorInt = ColorUtilities.color(color.toString())
            if (colorInt != null) {
                button.setTextColor(colorInt)
                // Force invalidate and request layout to ensure text is redrawn with correct color
                button.invalidate()
                button.requestLayout()
                Log.d(TAG, "Set text color from primaryColor: ${ColorUtilities.hexString(colorInt)}")
            } else {
                Log.w(TAG, "Failed to parse primaryColor: $color")
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        } ?: run {
            Log.e(TAG, "ERROR: No primaryColor in merged props! StyleSheet.toMap() should always provide it!")
        }

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

    // Remove override - let base class handle props merging
    // This ensures title and other props are preserved across updates

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
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


        // backgroundColor is handled by applyStyles from StyleSheet
        button.applyStyles(props)
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // primaryColor: button text color
        // CRITICAL: ALWAYS set text color AFTER applyStyles to ensure it's not overridden
        // This ensures text is visible even when UI is bloated or during rapid updates
        // StyleSheet.toMap() ALWAYS provides primaryColor, so this should never be null
        // IMPORTANT: On initial render (empty existingProps), ALWAYS set color to ensure visibility
        props["primaryColor"]?.let { color ->
            val colorInt = ColorUtilities.color(color.toString())
            if (colorInt != null) {
                button.setTextColor(colorInt)
                // Force invalidate to ensure text is redrawn with correct color
                button.invalidate()
                if (existingProps.isEmpty() || hasPropChanged("primaryColor", existingProps, props)) {
                    Log.d(TAG, "Set text color from primaryColor: ${ColorUtilities.hexString(colorInt)} (initial: ${existingProps.isEmpty()})")
                }
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor, don't set color (StyleSheet should always provide it)

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

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

