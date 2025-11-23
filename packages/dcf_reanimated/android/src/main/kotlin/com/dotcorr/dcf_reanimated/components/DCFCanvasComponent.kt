/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated.components

import android.content.Context
import android.graphics.PointF
import android.graphics.SurfaceTexture
import android.view.TextureView
import android.view.View
import android.view.Choreographer
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import com.dotcorr.dcflight.components.DCFComponent
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.sqrt
import kotlin.math.cos
import kotlin.math.sin

class DCFCanvasComponent : DCFComponent() {
    private var canvasView: DCFCanvasView? = null

    override fun createView(context: Context, props: Map<String, Any?>): View {
        canvasView = DCFCanvasView(context)
        
        // Set initial size from props if available
        val width = (props["width"] as? Number)?.toInt() ?: 0
        val height = (props["height"] as? Number)?.toInt() ?: 0
        if (width > 0 && height > 0) {
            val layoutParams = android.view.ViewGroup.LayoutParams(width, height)
            canvasView!!.layoutParams = layoutParams
        }
        
        updateView(canvasView!!, props)
        return canvasView!!
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        if (view is DCFCanvasView) {
            view.update(props)
            return true
        }
        return false
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // Canvas size is determined by layout or props, not intrinsic content
        val width = (props["width"] as? Number)?.toFloat() ?: 0f
        val height = (props["height"] as? Number)?.toFloat() ?: 0f
        return PointF(width, height)
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // No special handling needed for canvas registration
    }

    // Handle tunnel methods from Dart
    // Note: This is called on a cached factory instance, so we must use the static registry
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        if (method == "updateTexture") {
            val canvasId = arguments["canvasId"] as? String
            val pixels = arguments["pixels"] as? ByteArray
            val width = (arguments["width"] as? Number)?.toInt()
            val height = (arguments["height"] as? Number)?.toInt()

            if (canvasId != null && pixels != null && width != null && height != null) {
                val view = DCFCanvasView.canvasViews[canvasId]
                if (view != null) {
                    view.updateTexture(pixels, width, height)
                    return true
                } else {
                    android.util.Log.w("DCFCanvasComponent", "View not found for canvasId: $canvasId - view may not be registered yet")
                    return false  // Return false instead of null to indicate view not ready
                }
            }
        }
        return null
    }
}

// Particle data class for native rendering
data class Particle(
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    var rotation: Double,
    var rotationSpeed: Double,
    val size: Double,
    val color: Int // ARGB
)

class DCFCanvasView(context: Context) : TextureView(context), TextureView.SurfaceTextureListener {
    companion object {
        val canvasViews = ConcurrentHashMap<String, DCFCanvasView>()
    }

    private var canvasId: String? = null
    private var surfaceTexture: SurfaceTexture? = null
    
    // Native particle system
    private var particles: MutableList<Particle> = mutableListOf()
    private var particleConfig: Map<String, Any?>? = null
    private var animationStartTime: Long = 0
    private var animationDuration: Long = 0
    private var gravity: Double = 9.8
    private var canvasWidth: Double = 0.0
    private var canvasHeight: Double = 0.0
    private var isAnimating: Boolean = false
    private var choreographer: Choreographer? = null
    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (isAnimating) {
                updateAndRenderParticles()
                choreographer?.postFrameCallback(this)
            }
        }
    }

    init {
        surfaceTextureListener = this
        // Transparent background - canvas content comes from texture
        setBackgroundColor(Color.TRANSPARENT)
        // Allow touches to pass through to views behind the canvas
        isClickable = false
        isFocusable = false
        choreographer = Choreographer.getInstance()
    }

    fun update(props: Map<String, Any?>) {
        val id = props["canvasId"] as? String
        if (id != null && canvasId != id) {
            // Unregister old ID
            if (canvasId != null) {
                canvasViews.remove(canvasId!!)
            }
            canvasId = id
            canvasViews[id!!] = this
        }
        
        // Check for particle config (native rendering mode)
        if (props.containsKey("particleConfig")) {
            val config = props["particleConfig"] as? Map<String, Any?>
            if (config != null) {
                configureParticles(config)
                return // Native rendering handles everything
            }
        }
        
        // Ensure view fills its container
        val width = (props["width"] as? Number)?.toInt()
        val height = (props["height"] as? Number)?.toInt()
        if (width != null && height != null) {
            // Set layout params to fill space
            val layoutParams = this.layoutParams
            if (layoutParams != null) {
                layoutParams.width = width
                layoutParams.height = height
                this.layoutParams = layoutParams
            } else {
                // Create new layout params if none exist
                val newParams = android.view.ViewGroup.LayoutParams(width, height)
                this.layoutParams = newParams
            }
        }
    }
    
    private fun configureParticles(config: Map<String, Any?>) {
        android.util.Log.d("DCFCanvasView", "🎉 Configuring native particle system")
        particleConfig = config
        
        val particlesData = config["particles"] as? List<Map<String, Any?>>
        val width = (config["width"] as? Number)?.toDouble()
        val height = (config["height"] as? Number)?.toDouble()
        val duration = (config["duration"] as? Number)?.toLong()
        val gravityValue = (config["gravity"] as? Number)?.toDouble()
        
        if (particlesData == null || width == null || height == null || duration == null || gravityValue == null) {
            android.util.Log.w("DCFCanvasView", "⚠️ Invalid particle config")
            return
        }
        
        canvasWidth = width
        canvasHeight = height
        animationDuration = duration
        gravity = gravityValue
        
        // Initialize particles
        particles.clear()
        for (particleData in particlesData) {
            val x = (particleData["x"] as? Number)?.toDouble() ?: 0.0
            val y = (particleData["y"] as? Number)?.toDouble() ?: 0.0
            val vx = (particleData["vx"] as? Number)?.toDouble() ?: 0.0
            val vy = (particleData["vy"] as? Number)?.toDouble() ?: 0.0
            val rotation = (particleData["rotation"] as? Number)?.toDouble() ?: 0.0
            val rotationSpeed = (particleData["rotationSpeed"] as? Number)?.toDouble() ?: 0.0
            val size = (particleData["size"] as? Number)?.toDouble() ?: 0.0
            val color = (particleData["color"] as? Number)?.toInt() ?: 0
            
            particles.add(Particle(x, y, vx, vy, rotation, rotationSpeed, size, color))
        }
        
        android.util.Log.d("DCFCanvasView", "🎉 Initialized ${particles.size} particles")
        
        // Start animation
        animationStartTime = System.currentTimeMillis()
        isAnimating = true
        choreographer?.postFrameCallback(frameCallback)
    }
    
    private fun updateAndRenderParticles() {
        val currentTime = System.currentTimeMillis()
        val elapsed = currentTime - animationStartTime
        
        // Check if animation is complete
        if (elapsed >= animationDuration) {
            isAnimating = false
            choreographer?.removeFrameCallback(frameCallback)
            android.util.Log.d("DCFCanvasView", "🎉 Particle animation complete")
            // TODO: Fire onComplete callback
            return
        }
        
        // Update particles
        val deltaTime = 1.0 / 60.0 // Assume 60fps
        for (i in particles.indices) {
            val p = particles[i]
            p.x += p.vx * deltaTime
            p.y += (p.vy + gravity) * deltaTime
            p.vy += gravity * deltaTime
            p.rotation += p.rotationSpeed * deltaTime
        }
        
        // Render particles
        renderParticles()
    }
    
    private fun renderParticles() {
        val surface = surfaceTexture ?: return
        val canvas = lockCanvas() ?: return
        
        try {
            // Clear canvas
            canvas.drawColor(Color.TRANSPARENT, android.graphics.PorterDuff.Mode.CLEAR)
            
            // Render each particle
            val paint = Paint().apply {
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            
            for (particle in particles) {
                val x = particle.x.toFloat()
                val y = particle.y.toFloat()
                
                // Skip if out of bounds
                if (x < 0 || x >= canvasWidth || y < 0 || y >= canvasHeight) {
                    continue
                }
                
                paint.color = particle.color
                val radius = (particle.size / 2.0).toFloat()
                
                // Draw circle
                canvas.save()
                canvas.translate(x, y)
                canvas.rotate(particle.rotation.toFloat())
                canvas.drawCircle(0f, 0f, radius, paint)
                canvas.restore()
            }
        } finally {
            unlockCanvasAndPost(canvas)
        }
    }

    fun updateTexture(pixels: ByteArray, width: Int, height: Int) {
        val surface = surfaceTexture ?: return
        // In a real implementation, we would update the SurfaceTexture here.
        // Since SurfaceTexture requires an OpenGL texture ID, we would typically
        // use EGL to bind the texture and update it with the pixels.
        // For this implementation, we will use a simpler approach:
        // Draw the pixels to a Bitmap and then to the Surface.
        
        try {
            // Convert RGBA to ARGB (Android Bitmap expects ARGB_8888)
            // Use IntArray for setPixels which is more reliable than ByteBuffer
            val argbPixels = IntArray(width * height)
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val srcIndex = (y * width + x) * 4
                    if (srcIndex + 3 < pixels.size) {
                        // RGBA: R, G, B, A (from Dart)
                        // ARGB: A, R, G, B (for Android Bitmap)
                        val r = pixels[srcIndex].toInt() and 0xFF
                        val g = pixels[srcIndex + 1].toInt() and 0xFF
                        val b = pixels[srcIndex + 2].toInt() and 0xFF
                        val a = pixels[srcIndex + 3].toInt() and 0xFF
                        
                        // Pack into ARGB int: (A << 24) | (R << 16) | (G << 8) | B
                        argbPixels[y * width + x] = (a shl 24) or (r shl 16) or (g shl 8) or b
                    }
                }
            }
            
            val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
            bitmap.setPixels(argbPixels, 0, width, 0, 0, width, height)
            
            val canvas = lockCanvas()
            if (canvas != null) {
                // Clear canvas first to avoid artifacts
                canvas.drawColor(android.graphics.Color.TRANSPARENT, android.graphics.PorterDuff.Mode.CLEAR)
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                unlockCanvasAndPost(canvas)
            }
        } catch (e: Exception) {
            android.util.Log.e("DCFCanvasView", "Error updating texture", e)
        }
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        this.surfaceTexture = surface
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
        // Handle resize
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
        // Frame available
    }
}
