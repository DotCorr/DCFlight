/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.View.OnHoverListener
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import kotlin.math.atan2

class DCFGestureDetectorComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "GestureDetector")
        
        var panStartX = 0f
        var panStartY = 0f
        var panStartTime = 0L
        var isPanning = false
        var lastPanX = 0f
        var lastPanY = 0f
        var lastPanTime = 0L
        
        // Pinch/scale tracking
        var pinchStartScale = 1f
        var lastPinchScale = 1f
        var lastPinchTime = 0L
        var isPinching = false
        
        // Rotation tracking
        var rotationStartAngle = 0f
        var lastRotationAngle = 0f
        var lastRotationTime = 0L
        var isRotating = false
        var lastTouchPoints = mutableListOf<PointF>()
        
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
            
            override fun onDoubleTap(e: MotionEvent): Boolean {
                propagateEvent(frameLayout, "onDoubleTap", mapOf(
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
        
        // Scale gesture detector for pinch
        val scaleGestureDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
                isPinching = true
                pinchStartScale = detector.scaleFactor
                lastPinchScale = detector.scaleFactor
                lastPinchTime = System.currentTimeMillis()
                
                propagateEvent(frameLayout, "onPinchStart", mapOf(
                    "x" to detector.focusX.toDouble(),
                    "y" to detector.focusY.toDouble(),
                    "scale" to 1.0, // Start at 1.0
                    "velocity" to 0.0,
                    "timestamp" to System.currentTimeMillis(),
                    "fromUser" to true
                ))
                return true
            }
            
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val currentTime = System.currentTimeMillis()
                val currentScale = detector.scaleFactor
                val timeDelta = (currentTime - lastPinchTime).coerceAtLeast(1)
                val scaleDelta = currentScale - lastPinchScale
                val velocity = (scaleDelta / timeDelta) * 1000 // scale per second
                
                propagateEvent(frameLayout, "onPinchUpdate", mapOf(
                    "x" to detector.focusX.toDouble(),
                    "y" to detector.focusY.toDouble(),
                    "scale" to currentScale.toDouble(),
                    "velocity" to velocity.toDouble(),
                    "timestamp" to currentTime,
                    "fromUser" to true
                ))
                
                lastPinchScale = currentScale
                lastPinchTime = currentTime
                return true
            }
            
            override fun onScaleEnd(detector: ScaleGestureDetector) {
                val currentTime = System.currentTimeMillis()
                val timeDelta = (currentTime - lastPinchTime).coerceAtLeast(1)
                val scaleDelta = detector.scaleFactor - lastPinchScale
                val velocity = (scaleDelta / timeDelta) * 1000
                
                propagateEvent(frameLayout, "onPinchEnd", mapOf(
                    "x" to detector.focusX.toDouble(),
                    "y" to detector.focusY.toDouble(),
                    "scale" to detector.scaleFactor.toDouble(),
                    "velocity" to velocity.toDouble(),
                    "timestamp" to currentTime,
                    "fromUser" to true
                ))
                
                isPinching = false
            }
        })
        
        // Handle pan gestures, rotation, and multi-touch
        frameLayout.setOnTouchListener { _, event ->
            val currentTime = System.currentTimeMillis()
            val pointerCount = event.pointerCount
            
            // Handle pinch/scale first
            if (pointerCount >= 2) {
                scaleGestureDetector.onTouchEvent(event)
                
                // Handle rotation (two-finger rotation)
                if (pointerCount == 2) {
                    val x0 = event.getX(0)
                    val y0 = event.getY(0)
                    val x1 = event.getX(1)
                    val y1 = event.getY(1)
                    
                    val centerX = (x0 + x1) / 2
                    val centerY = (y0 + y1) / 2
                    
                    val dx = x1 - x0
                    val dy = y1 - y0
                    val currentAngle = atan2(dy, dx)
                    
                    when (event.actionMasked) {
                        MotionEvent.ACTION_POINTER_DOWN -> {
                            if (event.actionIndex == 1) {
                                isRotating = true
                                rotationStartAngle = currentAngle
                                lastRotationAngle = currentAngle
                                lastRotationTime = currentTime
                                
                                propagateEvent(frameLayout, "onRotationStart", mapOf(
                                    "x" to centerX.toDouble(),
                                    "y" to centerY.toDouble(),
                                    "rotation" to 0.0,
                                    "velocity" to 0.0,
                                    "timestamp" to currentTime,
                                    "fromUser" to true
                                ))
                            }
                        }
                        MotionEvent.ACTION_MOVE -> {
                            if (isRotating) {
                                val rotationDelta = currentAngle - lastRotationAngle
                                val timeDelta = (currentTime - lastRotationTime).coerceAtLeast(1)
                                val velocity = (rotationDelta / timeDelta) * 1000 // radians per second
                                
                                // Calculate total rotation from start
                                val totalRotation = currentAngle - rotationStartAngle
                                
                                propagateEvent(frameLayout, "onRotationUpdate", mapOf(
                                    "x" to centerX.toDouble(),
                                    "y" to centerY.toDouble(),
                                    "rotation" to totalRotation.toDouble(),
                                    "velocity" to velocity.toDouble(),
                                    "timestamp" to currentTime,
                                    "fromUser" to true
                                ))
                                
                                lastRotationAngle = currentAngle
                                lastRotationTime = currentTime
                            }
                        }
                        MotionEvent.ACTION_POINTER_UP -> {
                            if (isRotating) {
                                val totalRotation = currentAngle - rotationStartAngle
                                val timeDelta = (currentTime - lastRotationTime).coerceAtLeast(1)
                                val rotationDelta = currentAngle - lastRotationAngle
                                val velocity = (rotationDelta / timeDelta) * 1000
                                
                                propagateEvent(frameLayout, "onRotationEnd", mapOf(
                                    "x" to centerX.toDouble(),
                                    "y" to centerY.toDouble(),
                                    "rotation" to totalRotation.toDouble(),
                                    "velocity" to velocity.toDouble(),
                                    "timestamp" to currentTime,
                                    "fromUser" to true
                                ))
                                
                                isRotating = false
                            }
                        }
                    }
                }
                
                // Don't process pan gestures when pinching/rotating
                if (isPinching || isRotating) {
                    return@setOnTouchListener true
                }
            }
            
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    panStartX = event.x
                    panStartY = event.y
                    panStartTime = currentTime
                    lastPanX = event.x
                    lastPanY = event.y
                    lastPanTime = currentTime
                    isPanning = false
                    gestureDetector.onTouchEvent(event)
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.x - panStartX
                    val deltaY = event.y - panStartY
                    val distance = kotlin.math.sqrt((deltaX * deltaX + deltaY * deltaY).toDouble())
                    
                    // Start panning if moved more than threshold (10 pixels)
                    if (!isPanning && distance > 10) {
                        isPanning = true
                        propagateEvent(frameLayout, "onPanStart", mapOf(
                            "x" to panStartX.toDouble(),
                            "y" to panStartY.toDouble(),
                            "translationX" to 0.0,
                            "translationY" to 0.0,
                            "velocityX" to 0.0,
                            "velocityY" to 0.0,
                            "timestamp" to currentTime,
                            "fromUser" to true
                        ))
                        lastPanX = event.x
                        lastPanY = event.y
                        lastPanTime = currentTime
                    }
                    
                    if (isPanning) {
                        // Calculate velocity based on recent movement
                        val timeDelta = (currentTime - lastPanTime).coerceAtLeast(1)
                        val moveDeltaX = event.x - lastPanX
                        val moveDeltaY = event.y - lastPanY
                        val velocityX = (moveDeltaX / timeDelta) * 1000 // pixels per second
                        val velocityY = (moveDeltaY / timeDelta) * 1000 // pixels per second
                        
                        propagateEvent(frameLayout, "onPanUpdate", mapOf(
                            "x" to event.x.toDouble(),
                            "y" to event.y.toDouble(),
                            "translationX" to deltaX.toDouble(),
                            "translationY" to deltaY.toDouble(),
                            "velocityX" to velocityX.toDouble(),
                            "velocityY" to velocityY.toDouble(),
                            "timestamp" to currentTime,
                            "fromUser" to true
                        ))
                        
                        lastPanX = event.x
                        lastPanY = event.y
                        lastPanTime = currentTime
                    } else {
                        gestureDetector.onTouchEvent(event)
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (isPanning) {
                        val deltaX = event.x - panStartX
                        val deltaY = event.y - panStartY
                        val timeDelta = (currentTime - lastPanTime).coerceAtLeast(1)
                        val moveDeltaX = event.x - lastPanX
                        val moveDeltaY = event.y - lastPanY
                        val velocityX = (moveDeltaX / timeDelta) * 1000 // pixels per second
                        val velocityY = (moveDeltaY / timeDelta) * 1000 // pixels per second
                        
                        propagateEvent(frameLayout, "onPanEnd", mapOf(
                            "x" to event.x.toDouble(),
                            "y" to event.y.toDouble(),
                            "translationX" to deltaX.toDouble(),
                            "translationY" to deltaY.toDouble(),
                            "velocityX" to velocityX.toDouble(),
                            "velocityY" to velocityY.toDouble(),
                            "timestamp" to currentTime,
                            "fromUser" to true
                        ))
                        isPanning = false
                    } else {
                        gestureDetector.onTouchEvent(event)
                    }
                }
                else -> {
                    gestureDetector.onTouchEvent(event)
                }
            }
            true
        }
        
        // Hover support (for mouse/trackpad on tablets/desktop)
        frameLayout.setOnHoverListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> {
                    propagateEvent(view, "onHover", mapOf(
                        "x" to event.x.toDouble(),
                        "y" to event.y.toDouble(),
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
                    ))
                }
            }
            false
        }
        
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        mergedProps["disabled"]?.let {
            val disabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            view.isEnabled = !disabled
        }

        view.applyStyles(nonNullProps)

        return true
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

