/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.YogaLayout
import com.dotcorr.dcflight.components.Size
import com.dotcorr.dcflight.components.R
import com.dotcorr.dcflight.utils.ColorUtilities

/**
 * Basic View component for DCFlight
 * Acts as a container view similar to div in web or View in React Native
 */
class DCFViewComponent : DCFComponent {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = FrameLayout(context)

        // Apply initial props
        updateView(view, props)

        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        try {
            // Apply style properties
            applyStyleProps(view, props)

            // Apply accessibility properties
            applyAccessibilityProps(view, props)

            // Apply interaction properties
            applyInteractionProps(view, props)

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    override fun applyLayout(view: View, layout: YogaLayout) {
        // Use default implementation from interface
        super.applyLayout(view, layout)
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any?>): Size {
        // For a basic view, we don't have intrinsic content size
        // Return zero to let Yoga handle the sizing
        return Size(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Use default implementation from interface
        super.viewRegisteredWithShadowTree(view, nodeId)
    }

    private fun applyStyleProps(view: View, props: Map<String, Any?>) {
        // Background color
        props["backgroundColor"]?.let { colorValue ->
            when (colorValue) {
                is String -> {
                    val color = ColorUtilities.color(colorValue) ?: Color.TRANSPARENT
                    view.setBackgroundColor(color)
                }

                is Long -> view.setBackgroundColor(colorValue.toInt())
                is Int -> view.setBackgroundColor(colorValue)
            }
        }

        // Opacity
        props["opacity"]?.let { opacity ->
            when (opacity) {
                is Double -> view.alpha = opacity.toFloat()
                is Float -> view.alpha = opacity
                is Int -> view.alpha = opacity.toFloat()
            }
        }

        // Border properties
        val borderWidth = props["borderWidth"] as? Double ?: props["borderWidth"] as? Int ?: 0
        val borderColor = props["borderColor"]?.let { colorValue ->
            when (colorValue) {
                is String -> ColorUtilities.color(colorValue) ?: Color.TRANSPARENT
                is Long -> colorValue.toInt()
                is Int -> colorValue
                else -> Color.TRANSPARENT
            }
        } ?: Color.TRANSPARENT

        val borderRadius = props["borderRadius"] as? Double ?: props["borderRadius"] as? Int ?: 0

        // Apply border and corner radius using GradientDrawable
        if (borderWidth > 0 || borderRadius > 0) {
            val drawable = GradientDrawable().apply {
                // Set background color if exists
                props["backgroundColor"]?.let { bgColor ->
                    val color = when (bgColor) {
                        is String -> ColorUtilities.color(bgColor) ?: Color.TRANSPARENT
                        is Long -> bgColor.toInt()
                        is Int -> bgColor
                        else -> Color.TRANSPARENT
                    }
                    setColor(color)
                }

                // Set border
                if (borderWidth > 0) {
                    setStroke(borderWidth.toInt(), borderColor)
                }

                // Set corner radius
                if (borderRadius > 0) {
                    cornerRadius = borderRadius.toFloat()
                }
            }
            view.background = drawable
        }

        // Shadow properties (elevation in Android)
        props["shadowRadius"]?.let { shadowRadius ->
            val elevation = when (shadowRadius) {
                is Double -> shadowRadius.toFloat()
                is Float -> shadowRadius
                is Int -> shadowRadius.toFloat()
                else -> 0f
            }
            view.elevation = elevation
        }

        // Clip to bounds
        props["overflow"]?.let { overflow ->
            when (overflow) {
                "hidden" -> view.clipToOutline = true
                "visible" -> view.clipToOutline = false
            }
        }
    }

    private fun applyAccessibilityProps(view: View, props: Map<String, Any?>) {
        // Accessibility label
        props["accessibilityLabel"]?.let { label ->
            view.contentDescription = label.toString()
        }

        // Accessibility hint
        props["accessibilityHint"]?.let { hint ->
            // Android doesn't have a separate hint, append to content description
            val currentDesc = view.contentDescription?.toString() ?: ""
            view.contentDescription = if (currentDesc.isNotEmpty()) {
                "$currentDesc. $hint"
            } else {
                hint.toString()
            }
        }

        // Important for accessibility
        props["importantForAccessibility"]?.let { important ->
            when (important) {
                "yes", true -> view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
                "no", false -> view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                "no-hide-descendants" -> view.importantForAccessibility =
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS

                "auto" -> view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
            }
        }

        // Test ID for automation
        props["testID"]?.let { testId ->
            view.tag = testId
        }
    }

    private fun applyInteractionProps(view: View, props: Map<String, Any?>) {
        // Pointer events
        props["pointerEvents"]?.let { pointerEvents ->
            when (pointerEvents) {
                "none" -> {
                    view.isClickable = false
                    view.isFocusable = false
                }

                "box-none" -> {
                    // View itself doesn't receive events but children can
                    view.isClickable = false
                    view.isFocusable = false
                }

                "box-only" -> {
                    // View receives events, children do not
                    view.isClickable = true
                    view.isFocusable = true
                }

                "auto" -> {
                    // Default behavior
                    view.isClickable = true
                    view.isFocusable = true
                }
            }
        }

        // Hit slop (extends touch area)
        props["hitSlop"]?.let { hitSlop ->
            if (hitSlop is Map<*, *>) {
                val top = (hitSlop["top"] as? Number)?.toInt() ?: 0
                val bottom = (hitSlop["bottom"] as? Number)?.toInt() ?: 0
                val left = (hitSlop["left"] as? Number)?.toInt() ?: 0
                val right = (hitSlop["right"] as? Number)?.toInt() ?: 0

                // Store hit slop for custom touch handling
                view.setTag(R.id.dcf_hit_slop_top, top)
                view.setTag(R.id.dcf_hit_slop_bottom, bottom)
                view.setTag(R.id.dcf_hit_slop_left, left)
                view.setTag(R.id.dcf_hit_slop_right, right)
            }
        }
    }

    companion object {
        /**
         * Handle tunnel method calls from Dart
         */
        @JvmStatic
        fun handleTunnelMethod(method: String, params: Map<String, Any?>): Any? {
            return when (method) {
                "setNativeProps" -> {
                    // Handle direct native prop updates
                    true
                }

                else -> {
                    println("⚠️ DCFViewComponent: Unknown tunnel method: $method")
                    null
                }
            }
        }
    }
}
