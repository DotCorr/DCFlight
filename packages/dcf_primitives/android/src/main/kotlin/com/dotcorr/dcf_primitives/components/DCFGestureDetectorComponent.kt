/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles

class DCFGestureDetectorComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = object : FrameLayout(context) {
            // Override to ensure touch events reach gesture detector even with children
            override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
                // Don't intercept, but ensure we can receive events
                return false
            }
        }
        
        // CRITICAL: Make clickable and focusable to receive touch events even with children
        frameLayout.isClickable = true
        frameLayout.isFocusable = true
        frameLayout.isFocusableInTouchMode = true
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "GestureDetector")
        
        val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                propagateEvent(frameLayout, "onTap", mapOf(
                    "x" to e.x.toDouble(),
                    "y" to e.y.toDouble(),
                    "timestamp" to System.currentTimeMillis(),
                    "fromUser" to true
                ))
                return true
            }
            
            override fun onLongPress(e: MotionEvent) {
                propagateEvent(frameLayout, "onLongPress", mapOf(
                    "x" to e.x.toDouble(),
                    "y" to e.y.toDouble(),
                    "timestamp" to System.currentTimeMillis(),
                    "fromUser" to true
                ))
            }
            
            override fun onFling(
                e1: MotionEvent?,
                e2: MotionEvent,
                velocityX: Float,
                velocityY: Float
            ): Boolean {
                val deltaX = (e2.x - (e1?.x ?: 0f))
                val deltaY = (e2.y - (e1?.y ?: 0f))
                
                    val velocity = kotlin.math.sqrt((velocityX * velocityX + velocityY * velocityY).toDouble())
                    val direction = when {
                        Math.abs(deltaX) > Math.abs(deltaY) -> {
                            if (deltaX > 0) "right" else "left"
                        }
                        else -> {
                            if (deltaY > 0) "down" else "up"
                        }
                    }
                    
                    when {
                        Math.abs(deltaX) > Math.abs(deltaY) -> {
                            if (deltaX > 0) {
                                propagateEvent(frameLayout, "onSwipeRight", mapOf(
                                    "direction" to "right",
                                    "velocity" to velocity,
                                    "timestamp" to System.currentTimeMillis(),
                                    "fromUser" to true
                                ))
                            } else {
                                propagateEvent(frameLayout, "onSwipeLeft", mapOf(
                                    "direction" to "left",
                                    "velocity" to velocity,
                                    "timestamp" to System.currentTimeMillis(),
                                    "fromUser" to true
                                ))
                            }
                        }
                        else -> {
                            if (deltaY > 0) {
                                propagateEvent(frameLayout, "onSwipeDown", mapOf(
                                    "direction" to "down",
                                    "velocity" to velocity,
                                    "timestamp" to System.currentTimeMillis(),
                                    "fromUser" to true
                                ))
                            } else {
                                propagateEvent(frameLayout, "onSwipeUp", mapOf(
                                    "direction" to "up",
                                    "velocity" to velocity,
                                    "timestamp" to System.currentTimeMillis(),
                                    "fromUser" to true
                                ))
                            }
                        }
                    }
                return true
            }
        })
        
        frameLayout.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
        }
        
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        var hasUpdates = false

        if (hasPropChanged("disabled", existingProps, props)) {
            props["disabled"]?.let {
                val disabled = when (it) {
                    is Boolean -> it
                    is String -> it.toBoolean()
                    else -> false
                }
                if (view.isEnabled == disabled) {
                    view.isEnabled = !disabled
                    view.isClickable = !disabled
                    view.isFocusable = !disabled
                    view.isFocusableInTouchMode = !disabled
                    hasUpdates = true
                }
            }
        } else {
            // Ensure view remains clickable even if disabled prop not changed
            view.isClickable = true
            view.isFocusable = true
            view.isFocusableInTouchMode = true
        }

        view.applyStyles(props)

        return hasUpdates
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val frameLayout = view as? FrameLayout ?: return PointF(0f, 0f)

        frameLayout.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = frameLayout.measuredWidth.toFloat()
        val measuredHeight = frameLayout.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

