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
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        // Apply Yoga layout to the view
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        // Notify canvas view of layout size change
        if (view is DCFCanvasView) {
            view.onLayoutApplied(layout.width, layout.height)
        }
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

class DCFCanvasView(context: Context) : TextureView(context), TextureView.SurfaceTextureListener {
    companion object {
        val canvasViews = ConcurrentHashMap<String, DCFCanvasView>()
    }

    private var canvasId: String? = null
    private var surfaceTexture: SurfaceTexture? = null

    init {
        surfaceTextureListener = this
        // Transparent background - canvas content comes from texture
        setBackgroundColor(Color.TRANSPARENT)
        // Allow touches to pass through to views behind the canvas
        isClickable = false
        isFocusable = false
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
            android.util.Log.d("DCFCanvasView", "Registered canvasId: $id")
        }
        
        // Note: Size is now handled by Yoga layout via applyLayout
        // We don't set layoutParams here anymore - Yoga handles it
    }
    
    fun onLayoutApplied(width: Float, height: Float) {
        android.util.Log.d("DCFCanvasView", "onLayoutApplied width: $width height: $height, canvasId: $canvasId")
        // Ensure we're registered if we have a valid size
        if (width > 0 && height > 0 && canvasId != null) {
            canvasViews[canvasId!!] = this
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
