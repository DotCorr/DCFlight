/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles

class DCFTouchableOpacityComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTouchableOpacity"
        private const val DEFAULT_ACTIVE_OPACITY = 0.2f
    }

    private var activeOpacity: Float = DEFAULT_ACTIVE_OPACITY
    private var originalAlpha: Float = 1.0f

    private var viewId: Int? = null

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "TouchableOpacity")
        frameLayout.isClickable = true
        frameLayout.isFocusable = true
        frameLayout.isFocusableInTouchMode = true
        
        originalAlpha = 1.0f

        frameLayout.setOnClickListener { view ->
            Log.e(TAG, "✅ Click listener fired: viewId=$viewId")

            propagateEvent(view, "onPress", mapOf(
                "timestamp" to System.currentTimeMillis(),
                "fromUser" to true
            ))
        }
        
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    Log.e(TAG, "🔵 Touch DOWN: viewId=$viewId")
                    val viewIdTag = view.getTag(DCFTags.VIEW_ID_KEY)
                    Log.d(TAG, "   VIEW_ID_KEY: $viewIdTag")
                    
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
                    Log.e(TAG, "🔵 Touch UP: viewId=$viewId")
                    val viewIdTag = view.getTag(DCFTags.VIEW_ID_KEY)
                    val eventTypesTag = view.getTag(DCFTags.EVENT_TYPES_KEY)
                    val callbackTag = view.getTag(DCFTags.EVENT_CALLBACK_KEY)
                    Log.d(TAG, "   VIEW_ID_KEY: $viewIdTag")
                    Log.d(TAG, "   EVENT_TYPES_KEY: $eventTypesTag")
                    Log.d(TAG, "   EVENT_CALLBACK_KEY: $callbackTag")
                    
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
                        Log.e(TAG, "✅ TOUCHABLE PRESSED - Dispatching performClick()")
                        view.performClick()
                    }
                    true
                }
                
                MotionEvent.ACTION_CANCEL -> {
                    Log.d(TAG, "⚠️ Touch CANCEL: viewId=$viewId")
                    
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
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        mergedProps["activeOpacity"]?.let { opacity ->
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


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        // Store viewId for logging
        viewId = nodeId.toIntOrNull()
        Log.d(TAG, "✅ TouchableOpacity registered with shadow tree: nodeId=$nodeId, viewId=$viewId")
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

