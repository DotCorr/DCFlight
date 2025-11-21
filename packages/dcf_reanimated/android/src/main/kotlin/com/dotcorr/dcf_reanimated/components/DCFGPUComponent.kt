/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated.components

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.view.Choreographer
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import java.util.concurrent.TimeUnit

/**
 * GPU Component using Skia for GPU-accelerated rendering
 * 
 * Uses Android's built-in Skia library for consistent GPU rendering
 */
class DCFGPUComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFGPUComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val gpuView = SkiaGPUView(context)
        gpuView.setTag(DCFTags.COMPONENT_TYPE_KEY, "GPU")
        updateView(gpuView, props)
        return gpuView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val gpuView = view as? SkiaGPUView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        if (mergedProps["gpuConfig"] is Map<*, *>) {
            val gpuConfig = mergedProps["gpuConfig"] as Map<String, Any?>
            gpuView.configureGPU(gpuConfig)
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        gpuView.applyStyles(nonNullProps)
        
        // CRITICAL: GPU surface must always be transparent (Skia, Metal, etc.)
        // Force transparent background regardless of what applyStyles did
        gpuView.setBackgroundColor(Color.TRANSPARENT)
        gpuView.background = null
        
        return true
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): android.graphics.PointF {
        return android.graphics.PointF(0f, 0f)
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val gpuView = view as? SkiaGPUView ?: return
        gpuView.nodeId = nodeId
        Log.d(TAG, "Skia GPU component registered with shadow tree: $nodeId")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

/**
 * Skia GPU View for particle systems and GPU effects
 * 
 * Uses Android's built-in Skia for GPU-accelerated rendering
 */
class SkiaGPUView(context: Context) : View(context) {
    
    companion object {
        private const val TAG = "SkiaGPUView"
    }
    
    var nodeId: String? = null
    
    private val choreographer = Choreographer.getInstance()
    private var frameCallback: Choreographer.FrameCallback? = null
    private var isRendering = false
    private var animationStartTime = 0L
    
    private var gpuConfig: Map<String, Any?> = emptyMap()
    private var renderMode: String = "particles"
    private var particleCount: Int = 50
    private val particles = mutableListOf<Particle>()
    
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    
    init {
        setWillNotDraw(false)
        setBackgroundColor(Color.TRANSPARENT)
        // CRITICAL: Set layer type to hardware for proper transparency support
        // This ensures the view can be transparent and composited correctly
        setLayerType(View.LAYER_TYPE_HARDWARE, null)
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        if (renderMode == "particles" && particles.isEmpty() && width > 0 && height > 0) {
            Log.d(TAG, "📐 SKIA GPU: View laid out, initializing particles in ${width}x${height}")
            initializeParticles()
            
            val autoStart = gpuConfig["autoStart"] as? Boolean ?: true
            if (autoStart && !isRendering) {
                startRendering()
            }
        }
    }
    
    fun configureGPU(config: Map<String, Any?>) {
        Log.d(TAG, "🎮 SKIA GPU: Configuring GPU rendering")
        this.gpuConfig = config
        
        renderMode = config["renderMode"] as? String ?: "particles"
        particleCount = (config["particleCount"] as? Number)?.toInt() ?: 50
        
        if (renderMode == "particles" && width > 0 && height > 0) {
            initializeParticles()
        }
        
        val autoStart = config["autoStart"] as? Boolean ?: true
        if (autoStart && width > 0 && height > 0) {
            startRendering()
        }
    }
    
    private fun initializeParticles() {
        particles.clear()
        
        val viewWidth = if (width > 0) width.toFloat() else 400f
        val viewHeight = if (height > 0) height.toFloat() else 800f
        
        val parameters = gpuConfig["parameters"] as? Map<*, *>
        val colorArray = (parameters?.get("colors") as? List<*>)?.mapNotNull { it as? String }
            ?: listOf("#FF0000", "#00FF00", "#0000FF")
        
        Log.d(TAG, "🎨 SKIA GPU: Initializing $particleCount particles in ${viewWidth}x${viewHeight}")
        
        for (i in 0 until particleCount) {
            val particle = Particle(
                x = (Math.random() * viewWidth).toFloat().coerceAtLeast(0f),
                y = (Math.random() * -100.0).toFloat().coerceAtMost(0f),
                velocityX = (Math.random() * 100.0 - 50.0).toFloat(),
                velocityY = (Math.random() * -100.0 - 50.0).toFloat(),
                color = parseColor(colorArray[i % colorArray.size]),
                size = (Math.random() * 10.0 + 5.0).toFloat()
            )
            particles.add(particle)
        }
        
        Log.d(TAG, "✅ SKIA GPU: Initialized ${particles.size} particles")
    }
    
    private fun parseColor(hex: String): Int {
        val hexSanitized = hex.trim().replace("#", "")
        return try {
            Color.parseColor("#$hexSanitized")
        } catch (e: IllegalArgumentException) {
            Color.RED
        }
    }
    
    fun startRendering() {
        if (isRendering) return
        
        Log.d(TAG, "🚀 SKIA GPU: Starting GPU rendering")
        isRendering = true
        animationStartTime = System.nanoTime()
        
        startFrameCallback()
    }
    
    fun stopRendering() {
        if (!isRendering) return
        
        Log.d(TAG, "🛑 SKIA GPU: Stopping GPU rendering")
        isRendering = false
        stopFrameCallback()
    }
    
    private fun startFrameCallback() {
        if (frameCallback != null) return
        
        frameCallback = Choreographer.FrameCallback { frameTimeNanos ->
            if (!isRendering) {
                stopFrameCallback()
                return@FrameCallback
            }
            
            val elapsed = TimeUnit.NANOSECONDS.toMillis(frameTimeNanos - animationStartTime)
            val elapsedSeconds = elapsed / 1000.0
            
            val duration = (gpuConfig["duration"] as? Number)?.toInt() ?: 2000
            if (elapsed >= duration) {
                stopRendering()
                return@FrameCallback
            }
            
            updateParticles(elapsedSeconds)
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
    
    private fun updateParticles(elapsed: Double) {
        if (renderMode != "particles") return
        
        val gravity = ((gpuConfig["parameters"] as? Map<*, *>)?.get("gravity") as? Number)?.toDouble() ?: 9.8
        val deltaTime = 0.016f
        
        for (i in particles.indices) {
            val particle = particles[i]
            
            particles[i] = particle.copy(
                x = particle.x + particle.velocityX * deltaTime,
                y = particle.y + particle.velocityY * deltaTime,
                velocityY = particle.velocityY + (gravity * deltaTime * 10.0).toFloat()
            )
            
            if (particle.y > height) {
                particles[i] = particle.copy(
                    y = -10f,
                    x = (Math.random() * width).toFloat().coerceAtLeast(0f),
                    velocityY = (Math.random() * -100.0 - 50.0).toFloat()
                )
            }
        }
    }
    
    override fun onDraw(canvas: Canvas) {
        // CRITICAL: Don't call super.onDraw() - it might draw an opaque background
        // Instead, explicitly clear with transparent color
        canvas.drawColor(Color.TRANSPARENT, android.graphics.PorterDuff.Mode.CLEAR)
        
        // Canvas is backed by Skia on Android
        // Render particles using Skia's GPU-accelerated rendering
        for (particle in particles) {
            paint.color = particle.color
            canvas.drawCircle(particle.x, particle.y, particle.size / 2, paint)
        }
    }
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopRendering()
        Log.d(TAG, "🗑️ SKIA GPU: View detached from window")
    }
}

data class Particle(
    var x: Float,
    var y: Float,
    var velocityX: Float,
    var velocityY: Float,
    val color: Int,
    val size: Float
)

