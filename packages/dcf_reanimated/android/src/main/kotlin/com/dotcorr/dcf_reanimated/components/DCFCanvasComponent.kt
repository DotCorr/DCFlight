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
import com.dotcorr.dcflight.components.DCFComponent
import java.util.concurrent.ConcurrentHashMap

class DCFCanvasComponent : DCFComponent() {
    private var canvasView: DCFCanvasView? = null

    override fun createView(context: Context, props: Map<String, Any?>): View {
        canvasView = DCFCanvasView(context)
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
                view?.updateTexture(pixels, width, height)
                return true
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
            val argbPixels = ByteArray(pixels.size)
            for (i in pixels.indices step 4) {
                if (i + 3 < pixels.size) {
                    // RGBA: R, G, B, A
                    // ARGB: A, R, G, B
                    argbPixels[i] = pixels[i + 3]     // A
                    argbPixels[i + 1] = pixels[i]     // R
                    argbPixels[i + 2] = pixels[i + 1] // G
                    argbPixels[i + 3] = pixels[i + 2] // B
                }
            }
            
            val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
            val buffer = java.nio.ByteBuffer.wrap(argbPixels)
            bitmap.copyPixelsFromBuffer(buffer)
            
            val canvas = lockCanvas()
            if (canvas != null) {
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
