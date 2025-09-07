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
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcf_primitives.utils.AdaptiveColorHelper

/**
 * DCFGestureDetectorComponent - 1:1 mapping with iOS DCFGestureDetectorComponent
 * Provides gesture detection like iOS UIGestureRecognizer
 */
class DCFGestureDetectorComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        // Set component identifier
        frameLayout.setTag(R.id.dcf_component_type, "GestureDetector")
        
        // Set up gesture detector
        val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                // 🚀 MATCH iOS: Use propagateEvent for onTap
                propagateEvent(frameLayout, "onTap", mapOf(
                    "x" to e.x.toDouble(),
                    "y" to e.y.toDouble()
                ))
                return true
            }
            
            override fun onLongPress(e: MotionEvent) {
                // 🚀 MATCH iOS: Use propagateEvent for onLongPress
                propagateEvent(frameLayout, "onLongPress", mapOf(
                    "x" to e.x.toDouble(),
                    "y" to e.y.toDouble()
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
                
                // Determine swipe direction
                when {
                    Math.abs(deltaX) > Math.abs(deltaY) -> {
                        if (deltaX > 0) {
                            // 🚀 MATCH iOS: Use propagateEvent for onSwipeRight
                            propagateEvent(frameLayout, "onSwipeRight", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        } else {
                            // 🚀 MATCH iOS: Use propagateEvent for onSwipeLeft
                            propagateEvent(frameLayout, "onSwipeLeft", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        }
                    }
                    else -> {
                        if (deltaY > 0) {
                            // 🚀 MATCH iOS: Use propagateEvent for onSwipeDown
                            propagateEvent(frameLayout, "onSwipeDown", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        } else {
                            // 🚀 MATCH iOS: Use propagateEvent for onSwipeUp
                            propagateEvent(frameLayout, "onSwipeUp", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        }
                    }
                }
                return true
            }
        })
        
        // Set up touch listener to pass events to gesture detector
        frameLayout.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
        }
        
        // Apply initial props
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        var hasUpdates = false

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

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Apply adaptive background color
                view.setBackgroundColor(AdaptiveColorHelper.getSystemBackgroundColor(view.context))
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val frameLayout = view as? FrameLayout ?: return PointF(0f, 0f)

        // Measure the gesture detector content
        frameLayout.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = frameLayout.measuredWidth.toFloat()
        val measuredHeight = frameLayout.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // GestureDetector components may contain children and need shadow tree handling
    }
}

