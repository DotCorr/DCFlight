/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated.components

import android.content.Context
import android.graphics.Canvas as AndroidCanvas
import android.graphics.Color
import android.util.Log
import android.view.Choreographer
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles

/**
 * Skia Canvas Component for GPU-accelerated 2D rendering
 * 
 * Uses Android's built-in Skia library for consistent GPU rendering
 */
class DCFCanvasComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFCanvasComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val canvasView = SkiaCanvasView(context)
        canvasView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Canvas")
        updateView(canvasView, props)
        return canvasView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val canvasView = view as? SkiaCanvasView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        if (mergedProps["repaintOnFrame"] is Boolean) {
            canvasView.repaintOnFrame = mergedProps["repaintOnFrame"] as Boolean
        }
        
        if (mergedProps["backgroundColor"] is Number) {
            val bgColor = (mergedProps["backgroundColor"] as Number).toInt()
            canvasView.setBackgroundColor(bgColor)
        } else {
            canvasView.setBackgroundColor(Color.TRANSPARENT)
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        canvasView.applyStyles(nonNullProps)
        
        return true
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): android.graphics.PointF {
        return android.graphics.PointF(0f, 0f)
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val canvasView = view as? SkiaCanvasView ?: return
        canvasView.nodeId = nodeId
        Log.d(TAG, "Skia Canvas component registered with shadow tree: $nodeId")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

/**
 * Skia Canvas View using Android's built-in Skia
 * 
 * Android has Skia built-in, so we use android.graphics.Canvas
 * which is backed by Skia for GPU-accelerated rendering
 */
class SkiaCanvasView(context: Context) : View(context) {
    
    companion object {
        private const val TAG = "SkiaCanvasView"
    }
    
    var nodeId: String? = null
    var repaintOnFrame: Boolean = false
    
    private val choreographer = Choreographer.getInstance()
    private var frameCallback: Choreographer.FrameCallback? = null
    
    init {
        setWillNotDraw(false)
        setBackgroundColor(Color.TRANSPARENT)
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        if (repaintOnFrame && frameCallback == null) {
            startFrameCallback()
        }
    }
    
    private fun startFrameCallback() {
        if (frameCallback != null) return
        
        frameCallback = Choreographer.FrameCallback { frameTimeNanos ->
            if (!repaintOnFrame) {
                stopFrameCallback()
                return@FrameCallback
            }
            
            invalidate()
            choreographer.postFrameCallback(frameCallback!!)
        }
        
        choreographer.postFrameCallback(frameCallback!!)
    }
    
    private fun stopFrameCallback() {
        frameCallback?.let {
            choreographer.removeFrameCallback(it)
            frameCallback = null
        }
    }
    
    override fun onDraw(canvas: AndroidCanvas) {
        super.onDraw(canvas)
        
        // Canvas is backed by Skia on Android
        // This provides direct access to Skia's 2D graphics API
        // Users can draw using Skia's full API through the canvas
        
        // Temporary: Draw a test circle to verify Canvas is working
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.GREEN
            style = android.graphics.Paint.Style.FILL
        }
        
        val centerX = width / 2f
        val centerY = height / 2f
        val radius = 50f
        
        canvas.drawCircle(centerX, centerY, radius, paint)
        
        // TODO: The actual drawing will be done through native Skia calls
        // when the onPaint callback is implemented
    }
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopFrameCallback()
        Log.d(TAG, "Skia Canvas view detached from window")
    }
}

