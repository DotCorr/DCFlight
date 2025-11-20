/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.util.Log
import android.view.Choreographer
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import java.util.concurrent.TimeUnit

/**
 * GPU Component for direct GPU-accelerated rendering and animations.
 * 
 * Uses Android's Choreographer for 60fps rendering on UI thread.
 * Supports particle systems (confetti) and custom GPU rendering.
 */
class DCFGPUComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFGPUComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val gpuView = GPUView(context)
        
        gpuView.setTag(DCFTags.COMPONENT_TYPE_KEY, "GPU")
        
        // Configure GPU rendering from props
        if (props["gpuConfig"] is Map<*, *>) {
            val gpuConfig = props["gpuConfig"] as Map<String, Any?>
            gpuView.configureGPU(gpuConfig)
        }
        
        updateView(gpuView, props)
        
        return gpuView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val gpuView = view as? GPUView ?: return false
        
        // CRITICAL: Merge new props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        // Update GPU configuration if changed
        if (mergedProps["gpuConfig"] is Map<*, *>) {
            val gpuConfig = mergedProps["gpuConfig"] as Map<String, Any?>
            gpuView.updateGPUConfig(gpuConfig)
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        gpuView.applyStyles(nonNullProps)
        
        return true
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val gpuView = view as? GPUView ?: return
        gpuView.nodeId = nodeId
        Log.d(TAG, "GPU component registered with shadow tree: $nodeId")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

/**
 * GPU View that renders directly using GPU acceleration.
 * 
 * Uses Choreographer for 60fps frame updates on UI thread.
 * Supports particle systems for confetti and other effects.
 */
class GPUView(context: Context) : View(context) {
    
    companion object {
        private const val TAG = "GPUView"
    }
    
    // Choreographer for 60fps rendering
    private val choreographer = Choreographer.getInstance()
    private var frameCallback: Choreographer.FrameCallback? = null
    private var isRendering = false
    private var animationStartTime = 0L
    
    // GPU configuration
    private var gpuConfig: Map<String, Any?> = emptyMap()
    private var renderMode: String = "particles"
    private var particleCount: Int = 50
    
    // Particle system (for confetti)
    private val particles = mutableListOf<Particle>()
    
    // Paint for rendering
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    
    // Identifiers for callbacks
    var nodeId: String? = null
    
    init {
        setWillNotDraw(false) // Enable custom drawing
        setBackgroundColor(Color.TRANSPARENT) // Make view transparent
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        // Re-initialize particles when view is laid out (bounds are now correct)
        if (renderMode == "particles" && particles.isEmpty && width > 0 && height > 0) {
            Log.d(TAG, "📐 GPU: View laid out, initializing particles in ${width}x${height}")
            initializeParticles()
            
            // Auto-start if configured
            val autoStart = gpuConfig["autoStart"] as? Boolean ?: true
            if (autoStart && !isRendering) {
                startRendering()
            }
        }
    }
    
    // ============================================================================
    // GPU CONFIGURATION
    // ============================================================================
    
    fun configureGPU(config: Map<String, Any?>) {
        Log.d(TAG, "🎮 GPU: Configuring GPU rendering")
        this.gpuConfig = config
        
        // Parse configuration
        renderMode = config["renderMode"] as? String ?: "particles"
        particleCount = (config["particleCount"] as? Number)?.toInt() ?: 50
        
        // Initialize particle system if needed (will be re-initialized in onLayout with correct bounds)
        if (renderMode == "particles" && width > 0 && height > 0) {
            initializeParticles()
        }
        
        // Auto-start if configured (will be started in onLayout if bounds not ready)
        val autoStart = config["autoStart"] as? Boolean ?: true
        if (autoStart && width > 0 && height > 0) {
            startRendering()
        }
    }
    
    fun updateGPUConfig(config: Map<String, Any?>) {
        stopRendering()
        configureGPU(config)
    }
    
    // ============================================================================
    // PARTICLE SYSTEM (CONFETTI)
    // ============================================================================
    
    private fun initializeParticles() {
        particles.clear()
        
        // Use view bounds if available, otherwise use a default size
        val viewWidth = if (width > 0) width.toFloat() else 400f
        val viewHeight = if (height > 0) height.toFloat() else 800f
        
        val parameters = gpuConfig["parameters"] as? Map<*, *>
        val colorArray = (parameters?.get("colors") as? List<*>)?.mapNotNull { it as? String }
            ?: listOf("#FF0000", "#00FF00", "#0000FF")
        
        Log.d(TAG, "🎨 GPU: Initializing $particleCount particles in ${viewWidth}x${viewHeight}")
        
        for (i in 0 until particleCount) {
            val particle = Particle(
                x = (Math.random() * viewWidth).toFloat().coerceAtLeast(0f),
                y = (Math.random() * -100.0).toFloat().coerceAtMost(0f), // Start above view
                velocityX = (Math.random() * 100.0 - 50.0).toFloat(),
                velocityY = (Math.random() * -100.0 - 50.0).toFloat(),
                color = parseColor(colorArray[i % colorArray.size]),
                size = (Math.random() * 10.0 + 5.0).toFloat()
            )
            particles.add(particle)
        }
        
        Log.d(TAG, "✅ GPU: Initialized ${particles.size} particles")
    }
    
    private fun parseColor(hex: String): Int {
        val hexSanitized = hex.trim().replace("#", "")
        return try {
            Color.parseColor("#$hexSanitized")
        } catch (e: IllegalArgumentException) {
            Color.RED
        }
    }
    
    // ============================================================================
    // RENDERING LOOP
    // ============================================================================
    
    fun startRendering() {
        if (isRendering) return
        
        Log.d(TAG, "🚀 GPU: Starting GPU rendering")
        isRendering = true
        animationStartTime = System.nanoTime()
        
        // Fire start event
        fireGPUEvent("onGPUStart")
        
        // Start Choreographer frame callback
        startFrameCallback()
    }
    
    fun stopRendering() {
        if (!isRendering) return
        
        Log.d(TAG, "🛑 GPU: Stopping GPU rendering")
        isRendering = false
        stopFrameCallback()
        
        // Fire complete event
        fireGPUEvent("onGPUComplete")
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
            
            // Check duration
            val duration = (gpuConfig["duration"] as? Number)?.toInt() ?: 2000
            if (elapsed >= duration) {
                stopRendering()
                return@FrameCallback
            }
            
            // Update and render
            updateParticles(elapsedSeconds)
            invalidate() // Trigger onDraw()
            
            // Schedule next frame
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
        val deltaTime = 0.016f // ~60fps
        
        for (i in particles.indices) {
            val particle = particles[i]
            
            // Update position
            particles[i] = particle.copy(
                x = particle.x + particle.velocityX * deltaTime,
                y = particle.y + particle.velocityY * deltaTime,
                velocityY = particle.velocityY + (gravity * deltaTime * 10.0).toFloat() // Apply gravity
            )
            
            // Reset if out of bounds
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
        super.onDraw(canvas)
        
        // Draw particles
        for (particle in particles) {
            paint.color = particle.color
            canvas.drawCircle(particle.x, particle.y, particle.size / 2, paint)
        }
    }
    
    // ============================================================================
    // EVENT SYSTEM
    // ============================================================================
    
    private fun fireGPUEvent(eventType: String) {
        val id = nodeId
        if (id != null) {
            propagateEvent(
                this,
                eventType,
                mapOf(
                    "timestamp" to System.currentTimeMillis()
                )
            )
        }
    }
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopRendering()
        Log.d(TAG, "🗑️ GPU: View detached from window")
    }
}

/**
 * Particle data structure for confetti and particle effects
 */
data class Particle(
    var x: Float,
    var y: Float,
    var velocityX: Float,
    var velocityY: Float,
    val color: Int,
    val size: Float
)

