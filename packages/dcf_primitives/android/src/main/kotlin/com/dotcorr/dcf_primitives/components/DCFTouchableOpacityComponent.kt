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
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * EXACT iOS DCFTouchableOpacityComponent port for Android
 * Matches iOS DCFTouchableOpacityComponent.swift behavior 1:1
 * Provides touch feedback with opacity animation like iOS
 */
class DCFTouchableOpacityComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTouchableOpacity"
        private const val DEFAULT_ACTIVE_OPACITY = 0.2f
    }

    private var activeOpacity: Float = DEFAULT_ACTIVE_OPACITY
    private var originalAlpha: Float = 1.0f

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        // Let the system handle visibility naturally - no manual control
        
        // Apply adaptive default styling - let OS handle light/dark mode
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system colors that automatically adapt to light/dark mode
            frameLayout.setBackgroundColor(
                com.dotcorr.dcflight.utils.AdaptiveColorHelper.getSystemBackgroundColor(context)
            )
        } else {
            frameLayout.setBackgroundColor(Color.TRANSPARENT)
        }
        
        // Set component identifier
        frameLayout.setTag(R.id.dcf_component_type, "TouchableOpacity")
        
        // Store original alpha
        originalAlpha = frameLayout.alpha
        
        // Set up touch handling exactly like iOS
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    Log.d(TAG, "Touch down on TouchableOpacity")
                    
                    // MATCH iOS: Use propagateEvent for onPressIn
                    propagateEvent(view, "onPressIn", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Apply opacity feedback - MATCH iOS animation
                    view.animate()
                        .alpha(activeOpacity)
                        .setDuration(100)
                        .start()
                    true
                }
                
                MotionEvent.ACTION_UP -> {
                    Log.d(TAG, "Touch up on TouchableOpacity")
                    
                    // MATCH iOS: Use propagateEvent for onPressOut
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Restore original alpha - MATCH iOS animation
                    view.animate()
                        .alpha(originalAlpha)
                        .setDuration(100)
                        .start()
                    
                    // Check if touch is still inside bounds for onPress
                    val x = event.x
                    val y = event.y
                    if (x >= 0 && x <= view.width && y >= 0 && y <= view.height) {
                        Log.d(TAG, "TouchableOpacity pressed")
                        
                        // MATCH iOS: Use propagateEvent for onPress
                        propagateEvent(view, "onPress", mapOf(
                            "timestamp" to System.currentTimeMillis() / 1000.0
                        ))
                    }
                    true
                }
                
                MotionEvent.ACTION_CANCEL -> {
                    Log.d(TAG, "Touch cancelled on TouchableOpacity")
                    
                    // MATCH iOS: Use propagateEvent for onPressOut
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    // Restore original alpha - MATCH iOS animation
                    view.animate()
                        .alpha(originalAlpha)
                        .setDuration(100)
                        .start()
                    true
                }
                
                else -> false
            }
        }
        
        // Set up long press detection like iOS
        frameLayout.setOnLongClickListener { view ->
            Log.d(TAG, "Long press on TouchableOpacity")
            
            // MATCH iOS: Use propagateEvent for onLongPress
            propagateEvent(view, "onLongPress", mapOf(
                "timestamp" to System.currentTimeMillis() / 1000.0
            ))
            true
        }
        
        // Apply initial props - convert nullable to non-nullable
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(frameLayout, nonNullProps)
        
        // Apply StyleSheet properties
        frameLayout.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created TouchableOpacity component")
        
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        Log.d(TAG, "Updating TouchableOpacity with props: $props")

        // Update activeOpacity if provided - MATCH iOS
        props["activeOpacity"]?.let { opacity ->
            activeOpacity = when (opacity) {
                is Number -> opacity.toFloat()
                is String -> opacity.toFloatOrNull() ?: DEFAULT_ACTIVE_OPACITY
                else -> DEFAULT_ACTIVE_OPACITY
            }
            Log.d(TAG, "Set activeOpacity: $activeOpacity")
        }

        // Store current alpha as original alpha
        originalAlpha = view.alpha

        // Apply StyleSheet properties
        view.applyStyles(props)
        
        return true
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // TouchableOpacity is a container and typically doesn't have intrinsic size
        // It relies on its children and layout constraints
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // TouchableOpacity components are containers, so they might need layout management
        Log.d(TAG, "TouchableOpacity component registered with shadow tree: $nodeId")
    }
}

