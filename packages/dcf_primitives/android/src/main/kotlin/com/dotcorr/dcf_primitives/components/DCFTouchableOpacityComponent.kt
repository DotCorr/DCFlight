/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFTouchableOpacityComponent - 1:1 mapping with iOS DCFTouchableOpacityComponent
 * Provides touch feedback with opacity animation like iOS
 */
class DCFTouchableOpacityComponent : DCFComponent() {

    private var activeOpacity: Float = 0.2f
    private var originalAlpha: Float = 1.0f

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        // Set component identifier
        frameLayout.setTag(R.id.dcf_component_type, "TouchableOpacity")
        
        // Store original alpha
        originalAlpha = frameLayout.alpha
        
        // Set up touch handling exactly like iOS
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // 🚀 MATCH iOS: Use propagateEvent for onPressIn
                    propagateEvent(view, "onPressIn", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Apply opacity feedback
                    view.alpha = activeOpacity
                    true
                }
                
                MotionEvent.ACTION_UP -> {
                    // 🚀 MATCH iOS: Use propagateEvent for onPressOut
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Restore original alpha
                    view.alpha = originalAlpha
                    
                    // Check if touch is still inside bounds for onPress
                    val x = event.x
                    val y = event.y
                    if (x >= 0 && x <= view.width && y >= 0 && y <= view.height) {
                        // 🚀 MATCH iOS: Use propagateEvent for onPress
                        propagateEvent(view, "onPress", mapOf(
                            "timestamp" to System.currentTimeMillis() / 1000.0
                        ))
                    }
                    true
                }
                
                MotionEvent.ACTION_CANCEL -> {
                    // 🚀 MATCH iOS: Use propagateEvent for onPressOut
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Restore original alpha
                    view.alpha = originalAlpha
                    true
                }
                
                else -> false
            }
        }
        
        // Set up long press detection like iOS
        frameLayout.setOnLongClickListener { view ->
            // 🚀 MATCH iOS: Use propagateEvent for onLongPress
            propagateEvent(view, "onLongPress", mapOf(
                "timestamp" to System.currentTimeMillis() / 1000.0
            ))
            true
        }
        
        // Apply initial props
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    private fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        var hasUpdates = false

        // activeOpacity prop - matches iOS exactly
        props["activeOpacity"]?.let {
            val opacity = when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 0.2f
                else -> 0.2f
            }
            if (activeOpacity != opacity) {
                activeOpacity = opacity
                hasUpdates = true
            }
        }

        // disabled prop
        props["disabled"]?.let {
            val disabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            if (view.isEnabled == disabled) {
                view.isEnabled = !disabled
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }
}
