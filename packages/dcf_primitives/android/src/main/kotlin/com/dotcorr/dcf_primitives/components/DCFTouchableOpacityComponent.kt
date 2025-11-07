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
        
        
        // Use DCFTheme as default (framework controls colors)
        // StyleSheet.backgroundColor will override if provided
        // Note: TouchableOpacity typically should be transparent, but framework controls this
        frameLayout.setBackgroundColor(Color.TRANSPARENT)
        
        frameLayout.setTag(R.id.dcf_component_type, "TouchableOpacity")
        
        originalAlpha = frameLayout.alpha
        
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    Log.d(TAG, "Touch down on TouchableOpacity")
                    
                    propagateEvent(view, "onPressIn", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    view.animate()
                        .alpha(activeOpacity)
                        .setDuration(100)
                        .start()
                    true
                }
                
                MotionEvent.ACTION_UP -> {
                    Log.d(TAG, "Touch up on TouchableOpacity")
                    
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    view.animate()
                        .alpha(originalAlpha)
                        .setDuration(100)
                        .start()
                    
                    val x = event.x
                    val y = event.y
                    if (x >= 0 && x <= view.width && y >= 0 && y <= view.height) {
                        Log.d(TAG, "TouchableOpacity pressed")
                        
                        propagateEvent(view, "onPress", mapOf(
                            "timestamp" to System.currentTimeMillis() / 1000.0
                        ))
                    }
                    true
                }
                
                MotionEvent.ACTION_CANCEL -> {
                    Log.d(TAG, "Touch cancelled on TouchableOpacity")
                    
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis() / 1000.0
                    ))
                    
                    view.animate()
                        .alpha(originalAlpha)
                        .setDuration(100)
                        .start()
                    true
                }
                
                else -> false
            }
        }
        
        frameLayout.setOnLongClickListener { view ->
            Log.d(TAG, "Long press on TouchableOpacity")
            
            propagateEvent(view, "onLongPress", mapOf(
                "timestamp" to System.currentTimeMillis() / 1000.0
            ))
            true
        }
        
        // Use updateView (not updateViewInternal) - framework handles props merging
        updateView(frameLayout, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        frameLayout.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created TouchableOpacity component")
        
        return frameLayout
    }

    // Remove override - let base class handle props merging

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        Log.d(TAG, "Updating TouchableOpacity with props: $props")

        props["activeOpacity"]?.let { opacity ->
            activeOpacity = when (opacity) {
                is Number -> opacity.toFloat()
                is String -> opacity.toFloatOrNull() ?: DEFAULT_ACTIVE_OPACITY
                else -> DEFAULT_ACTIVE_OPACITY
            }
            Log.d(TAG, "Set activeOpacity: $activeOpacity")
        }

        originalAlpha = view.alpha

        view.applyStyles(props)
        
        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "TouchableOpacity component registered with shadow tree: $nodeId")
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

