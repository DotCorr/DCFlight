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
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles

class DCFTouchableOpacityComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTouchableOpacity"
        private const val DEFAULT_ACTIVE_OPACITY = 0.2f
    }

    private var activeOpacity: Float = DEFAULT_ACTIVE_OPACITY
    private var originalAlpha: Float = 1.0f

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "TouchableOpacity")
        
        originalAlpha = 1.0f
        
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    Log.d(TAG, "Touch down on TouchableOpacity")
                    
                    propagateEvent(view, "onPressIn", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
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
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
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
                            "timestamp" to System.currentTimeMillis(),
                            "fromUser" to true
                        ))
                    }
                    true
                }
                
                MotionEvent.ACTION_CANCEL -> {
                    Log.d(TAG, "Touch cancelled on TouchableOpacity")
                    
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
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
                "timestamp" to System.currentTimeMillis(),
                "fromUser" to true
            ))
            true
        }
        
        updateView(frameLayout, props)
        
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val frameLayout = view as? FrameLayout ?: return false
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        
        props["activeOpacity"]?.let { opacity ->
            activeOpacity = when (opacity) {
                is Number -> opacity.toFloat()
                is String -> opacity.toFloatOrNull() ?: DEFAULT_ACTIVE_OPACITY
                else -> DEFAULT_ACTIVE_OPACITY
            }
        }
        
        originalAlpha = 1.0f
        
        view.applyStyles(nonNullProps)
        
        // Ensure alpha is 1.0 after styles (framework won't override for TouchableOpacity)
        view.alpha = 1.0f
        
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

