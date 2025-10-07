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
import com.dotcorr.dcflight.utils.AdaptiveColorHelper

/**
 * DCFGestureDetectorComponent - 1:1 mapping with iOS DCFGestureDetectorComponent
 * Provides gesture detection like iOS UIGestureRecognizer
 */
class DCFGestureDetectorComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        
        frameLayout.setTag(R.id.dcf_component_type, "GestureDetector")
        
        val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                propagateEvent(frameLayout, "onTap", mapOf(
                    "x" to e.x.toDouble(),
                    "y" to e.y.toDouble()
                ))
                return true
            }
            
            override fun onLongPress(e: MotionEvent) {
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
                
                when {
                    Math.abs(deltaX) > Math.abs(deltaY) -> {
                        if (deltaX > 0) {
                            propagateEvent(frameLayout, "onSwipeRight", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        } else {
                            propagateEvent(frameLayout, "onSwipeLeft", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        }
                    }
                    else -> {
                        if (deltaY > 0) {
                            propagateEvent(frameLayout, "onSwipeDown", mapOf(
                                "velocityX" to velocityX.toDouble(),
                                "velocityY" to velocityY.toDouble()
                            ))
                        } else {
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
        
        frameLayout.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
        }
        
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        var hasUpdates = false

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

        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                view.setBackgroundColor(AdaptiveColorHelper.getSystemBackgroundColor(view.context))
                hasUpdates = true
            }
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
}

