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
import com.dotcorr.dcflight.components.DCFNodeLayout
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
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "updatePixels" -> {
                // Dart sends: canvasId, pixels (ByteArray), width, height
                val canvasId = arguments["canvasId"] as? String
                val pixels = arguments["pixels"] as? ByteArray
                val width = (arguments["width"] as? Number)?.toInt()
                val height = (arguments["height"] as? Number)?.toInt()

                if (canvasId != null && pixels != null && width != null && height != null) {
                    val view = DCFCanvasView.canvasViews[canvasId]
                    if (view != null) {
                        view.updatePixels(pixels, width, height)
                        true
                    } else {
                        false  // View not ready yet (retry later)
                    }
                } else {
                    null  // Invalid params
                }
            }
            else -> null  // Method not supported
        }
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
        isOpaque = false
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
    fun updatePixels(pixels: ByteArray, width: Int, height: Int) {
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
    
    // NEW: Command-based rendering (Phase 3) - executes Skia commands directly
    fun updateCommands(commands: List<Map<String, Any>>, width: Int, height: Int): Boolean {
        // android.util.Log.d("DCFCanvasView", "updateCommands width: $width height: $height commands: ${commands.size}")
        
        if (!isAvailable) {
            // android.util.Log.w("DCFCanvasView", "SurfaceTexture not available yet")
            return false
        }

        val canvas = lockCanvas()
        if (canvas == null) {
            android.util.Log.w("DCFCanvasView", "Failed to lock canvas")
            return false
        }
        
        try {
            // Clear canvas
            canvas.drawColor(android.graphics.Color.TRANSPARENT, android.graphics.PorterDuff.Mode.CLEAR)
            
            // Execute each command on Android Canvas (which uses Skia under the hood)
            executeCommands(commands, canvas, width, height)
            
            unlockCanvasAndPost(canvas)
            return true
        } catch (e: Exception) {
            android.util.Log.e("DCFCanvasView", "Error executing commands", e)
            unlockCanvasAndPost(canvas)
            return false
        }
    }
    
    // Execute drawing commands on Android Canvas (Skia)
    private fun executeCommands(commands: List<Map<String, Any>>, canvas: Canvas, width: Int, height: Int) {
        val paint = Paint().apply {
            isAntiAlias = true
        }
        
        for (command in commands) {
            val type = command["type"] as? String ?: continue
            @Suppress("UNCHECKED_CAST")
            val params = command["params"] as? Map<String, Any> ?: continue
            
            when (type) {
                "drawRect" -> {
                    val rect = params["rect"] as? List<Double>
                    val paintData = params["paint"] as? Map<String, Any>
                    if (rect != null && rect.size == 4 && paintData != null) {
                        applyPaint(paint, paintData)
                        canvas.drawRect(
                            rect[0].toFloat(), rect[1].toFloat(),
                            rect[2].toFloat(), rect[3].toFloat(),
                            paint
                        )
                    }
                }
                "drawCircle" -> {
                    val center = params["center"] as? List<Double>
                    val radius = (params["radius"] as? Number)?.toFloat()
                    val paintData = params["paint"] as? Map<String, Any>
                    if (center != null && center.size == 2 && radius != null && paintData != null) {
                        applyPaint(paint, paintData)
                        canvas.drawCircle(center[0].toFloat(), center[1].toFloat(), radius, paint)
                    }
                }
                "drawLine" -> {
                    val p1 = params["p1"] as? List<Double>
                    val p2 = params["p2"] as? List<Double>
                    val paintData = params["paint"] as? Map<String, Any>
                    if (p1 != null && p1.size == 2 && p2 != null && p2.size == 2 && paintData != null) {
                        applyPaint(paint, paintData)
                        canvas.drawLine(p1[0].toFloat(), p1[1].toFloat(), p2[0].toFloat(), p2[1].toFloat(), paint)
                    }
                }
                "drawOval" -> {
                    val rect = params["rect"] as? List<Double>
                    val paintData = params["paint"] as? Map<String, Any>
                    if (rect != null && rect.size == 4 && paintData != null) {
                        applyPaint(paint, paintData)
                        canvas.drawOval(
                            android.graphics.RectF(
                                rect[0].toFloat(), rect[1].toFloat(),
                                rect[2].toFloat(), rect[3].toFloat()
                            ),
                            paint
                        )
                    }
                }
                "drawArc" -> {
                    val rect = params["rect"] as? List<Double>
                    val startAngle = (params["startAngle"] as? Number)?.toFloat()
                    val sweepAngle = (params["sweepAngle"] as? Number)?.toFloat()
                    val useCenter = params["useCenter"] as? Boolean ?: false
                    val paintData = params["paint"] as? Map<String, Any>
                    if (rect != null && rect.size == 4 && startAngle != null && sweepAngle != null && paintData != null) {
                        applyPaint(paint, paintData)
                        canvas.drawArc(
                            android.graphics.RectF(
                                rect[0].toFloat(), rect[1].toFloat(),
                                rect[2].toFloat(), rect[3].toFloat()
                            ),
                            Math.toDegrees(startAngle.toDouble()).toFloat(),
                            Math.toDegrees(sweepAngle.toDouble()).toFloat(),
                            useCenter,
                            paint
                        )
                    }
                }
                "translate" -> {
                    val dx = (params["dx"] as? Number)?.toFloat()
                    val dy = (params["dy"] as? Number)?.toFloat()
                    if (dx != null && dy != null) {
                        canvas.translate(dx, dy)
                    }
                }
                "rotate" -> {
                    val radians = (params["radians"] as? Number)?.toDouble()
                    if (radians != null) {
                        canvas.rotate(Math.toDegrees(radians).toFloat())
                    }
                }
                "scale" -> {
                    val sx = (params["sx"] as? Number)?.toFloat()
                    val sy = (params["sy"] as? Number)?.toFloat()
                    if (sx != null && sy != null) {
                        canvas.scale(sx, sy)
                    }
                }
                "save" -> {
                    canvas.save()
                }
                "restore" -> {
                    canvas.restore()
                }
                "drawPath" -> {
                    val pathCommands = params["pathCommands"] as? List<Map<String, Any>>
                    val paintData = params["paint"] as? Map<String, Any>
                    
                    if (pathCommands != null && paintData != null) {
                        val path = android.graphics.Path()
                        
                        for (cmd in pathCommands) {
                            val cmdType = cmd["type"] as? String ?: continue
                            
                            when (cmdType) {
                                "moveTo" -> {
                                    val x = (cmd["x"] as? Number)?.toFloat()
                                    val y = (cmd["y"] as? Number)?.toFloat()
                                    if (x != null && y != null) path.moveTo(x, y)
                                }
                                "lineTo" -> {
                                    val x = (cmd["x"] as? Number)?.toFloat()
                                    val y = (cmd["y"] as? Number)?.toFloat()
                                    if (x != null && y != null) path.lineTo(x, y)
                                }
                                "cubicTo" -> {
                                    val x1 = (cmd["x1"] as? Number)?.toFloat()
                                    val y1 = (cmd["y1"] as? Number)?.toFloat()
                                    val x2 = (cmd["x2"] as? Number)?.toFloat()
                                    val y2 = (cmd["y2"] as? Number)?.toFloat()
                                    val x3 = (cmd["x3"] as? Number)?.toFloat()
                                    val y3 = (cmd["y3"] as? Number)?.toFloat()
                                    if (x1 != null && y1 != null && x2 != null && y2 != null && x3 != null && y3 != null) {
                                        path.cubicTo(x1, y1, x2, y2, x3, y3)
                                    }
                                }
                                "quadTo" -> {
                                    val x1 = (cmd["x1"] as? Number)?.toFloat()
                                    val y1 = (cmd["y1"] as? Number)?.toFloat()
                                    val x2 = (cmd["x2"] as? Number)?.toFloat()
                                    val y2 = (cmd["y2"] as? Number)?.toFloat()
                                    if (x1 != null && y1 != null && x2 != null && y2 != null) {
                                        path.quadTo(x1, y1, x2, y2)
                                    }
                                }
                                "close" -> {
                                    path.close()
                                }
                                "addRect" -> {
                                    val r = cmd["rect"] as? List<Double>
                                    if (r != null && r.size == 4) {
                                        path.addRect(r[0].toFloat(), r[1].toFloat(), r[2].toFloat(), r[3].toFloat(), android.graphics.Path.Direction.CW)
                                    }
                                }
                                "addOval" -> {
                                    val r = cmd["oval"] as? List<Double>
                                    if (r != null && r.size == 4) {
                                        path.addOval(r[0].toFloat(), r[1].toFloat(), r[2].toFloat(), r[3].toFloat(), android.graphics.Path.Direction.CW)
                                    }
                                }
                            }
                        }
                        
                        applyPaint(paint, paintData)
                        canvas.drawPath(path, paint)
                    }
                }
                // Add more command types as needed
                else -> {
                    android.util.Log.d("DCFCanvasView", "Unsupported command type: $type")
                }
            }
        }
    }
    
    private fun applyPaint(paint: Paint, paintData: Map<String, Any>) {
        val color = (paintData["color"] as? Number)?.toInt()
        if (color != null) {
            // ARGB format from Dart
            paint.color = color
        }
        
        val style = (paintData["style"] as? Number)?.toInt()
        if (style != null) {
            paint.style = when (style) {
                0 -> Paint.Style.FILL
                1 -> Paint.Style.STROKE
                else -> Paint.Style.FILL
            }
        }
        
        val strokeWidth = (paintData["strokeWidth"] as? Number)?.toFloat()
        if (strokeWidth != null) {
            paint.strokeWidth = strokeWidth
        }
        
        val isAntiAlias = paintData["isAntiAlias"] as? Boolean
        if (isAntiAlias != null) {
            paint.isAntiAlias = isAntiAlias
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

