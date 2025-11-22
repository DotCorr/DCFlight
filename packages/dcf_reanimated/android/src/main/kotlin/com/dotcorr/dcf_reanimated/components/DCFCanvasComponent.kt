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
import kotlin.math.max
import kotlin.math.min
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
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
        
        if (mergedProps["onPaint"] is Boolean) {
            canvasView.hasOnPaint = mergedProps["onPaint"] as Boolean
        }
        
        if (mergedProps["backgroundColor"] is Number) {
            val bgColor = (mergedProps["backgroundColor"] as Number).toInt()
            canvasView.setBackgroundColor(bgColor)
        } else {
            canvasView.setBackgroundColor(Color.TRANSPARENT)
        }
        
        // Parse shapes from props
        if (mergedProps["shapes"] is List<*>) {
            @Suppress("UNCHECKED_CAST")
            canvasView.shapes = mergedProps["shapes"] as List<Map<String, Any?>>
        } else {
            canvasView.shapes = emptyList()
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        canvasView.applyStyles(nonNullProps)
        
        return true
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): android.graphics.PointF {
        return android.graphics.PointF(0f, 0f)
    }
    
    override fun applyLayout(view: View, layout: com.dotcorr.dcflight.components.DCFNodeLayout) {
        // CRITICAL: Apply layout exactly as specified to prevent stretching
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
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
    var hasOnPaint: Boolean = false  // Whether onPaint callback is provided
    var shapes: List<Map<String, Any?>> = emptyList()  // Shapes to render
    
    private val choreographer = Choreographer.getInstance()
    private var frameCallback: Choreographer.FrameCallback? = null
    
    init {
        setWillNotDraw(false)
        setBackgroundColor(Color.TRANSPARENT)
        // CRITICAL: Set layer type to hardware for proper transparency support
        // This ensures the view can be transparent and composited correctly
        setLayerType(View.LAYER_TYPE_HARDWARE, null)
        // Prevent stretching by respecting layout constraints
        setMinimumWidth(0)
        setMinimumHeight(0)
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Respect layout constraints to prevent stretching
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
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
        
        // Render shapes
        if (shapes.isNotEmpty()) {
            renderShapes(canvas)
        } else if (hasOnPaint) {
            // onPaint callback will be called via method channel when implemented
            // For now, draw a test circle to show the canvas is working
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                color = android.graphics.Color.GREEN
                style = android.graphics.Paint.Style.FILL
            }
            
            val centerX = width / 2f
            val centerY = height / 2f
            val radius = 50f
            
            canvas.drawCircle(centerX, centerY, radius, paint)
        } else {
            // Draw test circle to verify Canvas is working (centered)
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                color = android.graphics.Color.GREEN
                style = android.graphics.Paint.Style.FILL
            }
            
            val centerX = width / 2f
            val centerY = height / 2f
            val radius = 50f
            
            canvas.drawCircle(centerX, centerY, radius, paint)
        }
    }
    
    // MARK: - Shape Rendering
    
    private fun renderShapes(canvas: AndroidCanvas) {
        renderShapesRecursive(canvas, shapes)
    }
    
    private fun renderShapesRecursive(canvas: AndroidCanvas, shapes: List<Map<String, Any?>>) {
        for (shape in shapes) {
            val type = shape["_type"] as? String ?: continue
            
            if (type == "SkiaGroup") {
                renderGroup(canvas, shape)
            } else {
                renderShape(canvas, shape)
            }
        }
    }
    
    private fun renderGroup(canvas: AndroidCanvas, group: Map<String, Any?>) {
        // Save canvas state
        val saveCount = canvas.save()
        
        // Apply transformations
        if (group["transform"] is List<*>) {
            @Suppress("UNCHECKED_CAST")
            val transforms = group["transform"] as List<Map<String, Any?>>
            for (t in transforms) {
                if (t["translateX"] is Number) {
                    canvas.translate((t["translateX"] as Number).toFloat(), 0f)
                }
                if (t["translateY"] is Number) {
                    canvas.translate(0f, (t["translateY"] as Number).toFloat())
                }
                if (t["translate"] is List<*>) {
                    @Suppress("UNCHECKED_CAST")
                    val translate = t["translate"] as List<Number>
                    if (translate.size >= 2) {
                        canvas.translate(translate[0].toFloat(), translate[1].toFloat())
                    }
                }
                if (t["rotate"] is Number) {
                    val degrees = (t["rotate"] as Number).toFloat()
                    canvas.rotate(degrees)
                }
                if (t["scaleX"] is Number) {
                    canvas.scale((t["scaleX"] as Number).toFloat(), 1f)
                }
                if (t["scaleY"] is Number) {
                    canvas.scale(1f, (t["scaleY"] as Number).toFloat())
                }
                if (t["scale"] is List<*>) {
                    @Suppress("UNCHECKED_CAST")
                    val scale = t["scale"] as List<Number>
                    if (scale.size >= 2) {
                        canvas.scale(scale[0].toFloat(), scale[1].toFloat())
                    }
                }
                if (t["skewX"] is Number) {
                    canvas.skew((t["skewX"] as Number).toFloat(), 0f)
                }
                if (t["skewY"] is Number) {
                    canvas.skew(0f, (t["skewY"] as Number).toFloat())
                }
            }
        }
        
        // Apply clipping
        if (group["clip"] is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            val clip = group["clip"] as Map<String, Any?>
            if (clip["x"] is Number && clip["y"] is Number && clip["width"] is Number && clip["height"] is Number) {
                val x = (clip["x"] as Number).toFloat()
                val y = (clip["y"] as Number).toFloat()
                val width = (clip["width"] as Number).toFloat()
                val height = (clip["height"] as Number).toFloat()
                if (clip["r"] is Number) {
                    val r = (clip["r"] as Number).toFloat()
                    val path = android.graphics.Path()
                    path.addRoundRect(android.graphics.RectF(x, y, x + width, y + height), r, r, android.graphics.Path.Direction.CW)
                    canvas.clipPath(path)
                } else {
                    canvas.clipRect(android.graphics.RectF(x, y, x + width, y + height))
                }
            } else if (clip["pathString"] is String) {
                val pathString = clip["pathString"] as String
                val path = android.graphics.Path()
                parseSVGPath(pathString, path)
                canvas.clipPath(path)
            }
        }
        
        // Render children
        if (group["_children"] is List<*>) {
            @Suppress("UNCHECKED_CAST")
            val children = group["_children"] as List<Map<String, Any?>>
            renderShapesRecursive(canvas, children)
        }
        
        // Restore canvas state
        canvas.restoreToCount(saveCount)
    }
    
    private fun renderShape(canvas: AndroidCanvas, shape: Map<String, Any?>) {
        val type = shape["_type"] as? String ?: return
        
        // Create paint for this shape
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        
        // Apply paint properties
        if (shape["color"] != null) {
            paint.color = parseShapeColor(shape["color"])
        }
        
        if (shape["opacity"] is Number) {
            val opacity = (shape["opacity"] as Number).toFloat()
            val alpha = (opacity * 255).toInt().coerceIn(0, 255)
            paint.alpha = alpha
        }
        
        if (shape["style"] == "stroke") {
            paint.style = android.graphics.Paint.Style.STROKE
        } else {
            paint.style = android.graphics.Paint.Style.FILL
        }
        
        if (shape["strokeWidth"] is Number) {
            paint.strokeWidth = (shape["strokeWidth"] as Number).toFloat()
        }
        
        if (shape["blendMode"] is String) {
            val blendMode = parseBlendMode(shape["blendMode"] as String)
            paint.xfermode = android.graphics.PorterDuffXfermode(blendMode)
        }
        
        // Apply shader if present
        if (shape["_shader"] is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            val shaderData = shape["_shader"] as Map<String, Any?>
            val shader = createShader(shaderData)
            if (shader != null) {
                paint.shader = shader
            }
        }
        
        // Apply path effects if present
        if (shape["_pathEffect"] is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            val effectData = shape["_pathEffect"] as Map<String, Any?>
            val pathEffect = createPathEffect(effectData)
            if (pathEffect != null) {
                paint.pathEffect = pathEffect
            }
        }
        
        // Apply color filters if present
        if (shape["_colorFilter"] is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            val filterData = shape["_colorFilter"] as Map<String, Any?>
            val colorFilter = createColorFilter(filterData)
            if (colorFilter != null) {
                paint.colorFilter = colorFilter
            }
        }
        
        // Apply image filters if present
        if (shape["_filters"] is List<*>) {
            @Suppress("UNCHECKED_CAST")
            val filters = shape["_filters"] as List<Map<String, Any?>>
            for (filterData in filters) {
                val filter = createImageFilter(filterData)
                if (filter != null) {
                    paint.maskFilter = filter
                }
            }
        }
        
        // Apply backdrop filters if present
        if (shape["_backdropFilters"] is List<*>) {
            @Suppress("UNCHECKED_CAST")
            val filters = shape["_backdropFilters"] as List<Map<String, Any?>>
            for (filterData in filters) {
                val filter = createBackdropFilter(filterData)
                if (filter != null) {
                    paint.maskFilter = filter
                }
            }
        }
        
        // Render based on type
        when (type) {
                "SkiaRect" -> {
                    val x = (shape["x"] as? Number)?.toFloat() ?: 0f
                    val y = (shape["y"] as? Number)?.toFloat() ?: 0f
                    val width = (shape["width"] as? Number)?.toFloat() ?: 0f
                    val height = (shape["height"] as? Number)?.toFloat() ?: 0f
                    canvas.drawRect(x, y, x + width, y + height, paint)
                }
                
                "SkiaRoundedRect" -> {
                    val x = (shape["x"] as? Number)?.toFloat() ?: 0f
                    val y = (shape["y"] as? Number)?.toFloat() ?: 0f
                    val width = (shape["width"] as? Number)?.toFloat() ?: 0f
                    val height = (shape["height"] as? Number)?.toFloat() ?: 0f
                    val r = (shape["r"] as? Number ?: shape["rx"] as? Number)?.toFloat() ?: 0f
                    canvas.drawRoundRect(x, y, x + width, y + height, r, r, paint)
                }
                
                "SkiaCircle" -> {
                    val cx = (shape["cx"] as? Number)?.toFloat() ?: 0f
                    val cy = (shape["cy"] as? Number)?.toFloat() ?: 0f
                    val r = (shape["r"] as? Number)?.toFloat() ?: 0f
                    canvas.drawCircle(cx, cy, r, paint)
                }
                
                "SkiaOval" -> {
                    val x = (shape["x"] as? Number)?.toFloat() ?: 0f
                    val y = (shape["y"] as? Number)?.toFloat() ?: 0f
                    val width = (shape["width"] as? Number)?.toFloat() ?: 0f
                    val height = (shape["height"] as? Number)?.toFloat() ?: 0f
                    val rect = android.graphics.RectF(x, y, x + width, y + height)
                    canvas.drawOval(rect, paint)
                }
                
                "SkiaLine" -> {
                    val x1 = (shape["x1"] as? Number)?.toFloat() ?: 0f
                    val y1 = (shape["y1"] as? Number)?.toFloat() ?: 0f
                    val x2 = (shape["x2"] as? Number)?.toFloat() ?: 0f
                    val y2 = (shape["y2"] as? Number)?.toFloat() ?: 0f
                    canvas.drawLine(x1, y1, x2, y2, paint)
                }
                
                "SkiaPath" -> {
                    val pathString = shape["pathString"] as? String
                    if (pathString != null) {
                        val path = android.graphics.Path()
                        // Parse SVG path string (simplified - Android Path doesn't have parseSVGString)
                        // For now, we'll need to implement SVG path parsing or use a library
                        // For basic paths, we can use Path.addPath or manual parsing
                        try {
                            parseSVGPath(pathString, path)
                            canvas.drawPath(path, paint)
                        } catch (e: Exception) {
                            Log.e(SkiaCanvasView.TAG, "Failed to parse SVG path: $pathString", e)
                        }
                    }
                }
                
                "SkiaFill" -> {
                    // Fill entire canvas
                    canvas.drawRect(0f, 0f, this.width.toFloat(), this.height.toFloat(), paint)
                }
                
                "SkiaImage" -> {
                    val imageSource = shape["image"] as? String
                    val x = (shape["x"] as? Number)?.toFloat() ?: 0f
                    val y = (shape["y"] as? Number)?.toFloat() ?: 0f
                    val width = (shape["width"] as? Number)?.toFloat() ?: 0f
                    val height = (shape["height"] as? Number)?.toFloat() ?: 0f
                    val fit = shape["fit"] as? String ?: "fill"
                    
                    if (imageSource != null) {
                        val bitmap = loadImage(imageSource)
                        if (bitmap != null) {
                            val srcRect = android.graphics.Rect(0, 0, bitmap.width, bitmap.height)
                            val dstRect = when (fit) {
                                "cover" -> {
                                    val scale = max(width / bitmap.width, height / bitmap.height)
                                    val scaledWidth = bitmap.width * scale
                                    val scaledHeight = bitmap.height * scale
                                    android.graphics.RectF(
                                        x + (width - scaledWidth) / 2,
                                        y + (height - scaledHeight) / 2,
                                        x + (width + scaledWidth) / 2,
                                        y + (height + scaledHeight) / 2
                                    )
                                }
                                "contain" -> {
                                    val scale = min(width / bitmap.width, height / bitmap.height)
                                    val scaledWidth = bitmap.width * scale
                                    val scaledHeight = bitmap.height * scale
                                    android.graphics.RectF(
                                        x + (width - scaledWidth) / 2,
                                        y + (height - scaledHeight) / 2,
                                        x + (width + scaledWidth) / 2,
                                        y + (height + scaledHeight) / 2
                                    )
                                }
                                else -> android.graphics.RectF(x, y, x + width, y + height)
                            }
                            canvas.drawBitmap(bitmap, srcRect, dstRect, paint)
                        }
                    }
                }
                
                "SkiaText" -> {
                    val text = shape["text"] as? String
                    val x = (shape["x"] as? Number)?.toFloat() ?: 0f
                    val y = (shape["y"] as? Number)?.toFloat() ?: 0f
                    val fontSize = (shape["fontSize"] as? Number)?.toFloat() ?: 16f
                    val fontFamily = shape["fontFamily"] as? String ?: "sans-serif"
                    
                    if (text != null) {
                        paint.textSize = fontSize
                        canvas.drawText(text, x, y, paint)
                    }
                }
        }
    }
    
    private fun createShader(shaderData: Map<String, Any?>): android.graphics.Shader? {
        val type = shaderData["_type"] as? String ?: return null
        
        return when (type) {
            "SkiaLinearGradient" -> {
                val x0 = (shaderData["x0"] as? Number)?.toFloat() ?: 0f
                val y0 = (shaderData["y0"] as? Number)?.toFloat() ?: 0f
                val x1 = (shaderData["x1"] as? Number)?.toFloat() ?: 0f
                val y1 = (shaderData["y1"] as? Number)?.toFloat() ?: 0f
                val colors = (shaderData["colors"] as? List<*>)?.mapNotNull { parseShapeColor(it) }?.toIntArray()
                val stops = (shaderData["stops"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }?.toFloatArray()
                
                if (colors != null && colors.isNotEmpty()) {
                    android.graphics.LinearGradient(
                        x0, y0, x1, y1,
                        colors,
                        stops,
                        android.graphics.Shader.TileMode.CLAMP
                    )
                } else null
            }
            
            "SkiaRadialGradient" -> {
                val cx = (shaderData["cx"] as? Number)?.toFloat() ?: 0f
                val cy = (shaderData["cy"] as? Number)?.toFloat() ?: 0f
                val r = (shaderData["r"] as? Number)?.toFloat() ?: 0f
                val colors = (shaderData["colors"] as? List<*>)?.mapNotNull { parseShapeColor(it) }?.toIntArray()
                val stops = (shaderData["stops"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }?.toFloatArray()
                
                if (colors != null && colors.isNotEmpty()) {
                    android.graphics.RadialGradient(
                        cx, cy, r,
                        colors,
                        stops,
                        android.graphics.Shader.TileMode.CLAMP
                    )
                } else null
            }
            
            "SkiaConicGradient" -> {
                val cx = (shaderData["cx"] as? Number)?.toFloat() ?: 0f
                val cy = (shaderData["cy"] as? Number)?.toFloat() ?: 0f
                val startAngle = (shaderData["startAngle"] as? Number)?.toFloat() ?: 0f
                val colors = (shaderData["colors"] as? List<*>)?.mapNotNull { parseShapeColor(it) }?.toIntArray()
                val stops = (shaderData["stops"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }?.toFloatArray()
                
                if (colors != null && colors.isNotEmpty()) {
                    android.graphics.SweepGradient(
                        cx, cy,
                        colors,
                        stops
                    )
                } else null
            }
            
            else -> null
        }
    }
    
    private fun createPathEffect(effectData: Map<String, Any?>): android.graphics.PathEffect? {
        val type = effectData["_type"] as? String ?: return null
        
        return when (type) {
            "SkiaDiscretePathEffect" -> {
                val length = (effectData["length"] as? Number)?.toFloat() ?: 0f
                val deviation = (effectData["deviation"] as? Number)?.toFloat() ?: 0f
                android.graphics.DiscretePathEffect(length, deviation)
            }
            
            "SkiaDashPathEffect" -> {
                val intervals = (effectData["intervals"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }?.toFloatArray()
                val phase = (effectData["phase"] as? Number)?.toFloat() ?: 0f
                if (intervals != null && intervals.isNotEmpty()) {
                    android.graphics.DashPathEffect(intervals, phase)
                } else null
            }
            
            "SkiaCornerPathEffect" -> {
                val r = (effectData["r"] as? Number)?.toFloat() ?: 0f
                android.graphics.CornerPathEffect(r)
            }
            
            else -> null
        }
    }
    
    private fun createImageFilter(filterData: Map<String, Any?>): android.graphics.MaskFilter? {
        val type = filterData["_type"] as? String ?: return null
        
        return when (type) {
            "SkiaBlur" -> {
                val blur = (filterData["blur"] as? Number)?.toFloat() ?: 0f
                android.graphics.BlurMaskFilter(blur, android.graphics.BlurMaskFilter.Blur.NORMAL)
            }
            
            "SkiaColorMatrix" -> {
                // ColorMatrix is handled as ColorFilter, not MaskFilter
                // This is handled separately in createColorFilter
                null
            }
            
            "SkiaDropShadow" -> {
                // DropShadow requires rendering with offset and blur
                // For Android, we'll use BlurMaskFilter as approximation
                val blur = (filterData["blur"] as? Number)?.toFloat() ?: 0f
                android.graphics.BlurMaskFilter(blur, android.graphics.BlurMaskFilter.Blur.NORMAL)
            }
            
            "SkiaOffset" -> {
                // Offset is handled by canvas translation, not a filter
                null
            }
            
            "SkiaMorphology" -> {
                // Morphology (erode/dilate) - Android doesn't have direct equivalent
                // Use blur as approximation
                val radius = (filterData["radius"] as? Number)?.toFloat() ?: 0f
                android.graphics.BlurMaskFilter(radius, android.graphics.BlurMaskFilter.Blur.NORMAL)
            }
            
            else -> null
        }
    }
    
    private fun createColorFilter(filterData: Map<String, Any?>): android.graphics.ColorFilter? {
        val type = filterData["_type"] as? String ?: return null
        
        return when (type) {
            "SkiaColorMatrix" -> {
                val matrix = (filterData["matrix"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }?.toFloatArray()
                if (matrix != null && matrix.size == 20) {
                    android.graphics.ColorMatrixColorFilter(android.graphics.ColorMatrix(matrix))
                } else null
            }
            
            "SkiaBlendColor" -> {
                val color = parseShapeColor(filterData["color"])
                val mode = filterData["mode"] as? String ?: "srcOver"
                val blendMode = parseBlendMode(mode)
                android.graphics.PorterDuffColorFilter(color, blendMode)
            }
            
            else -> null
        }
    }
    
    private fun createBackdropFilter(filterData: Map<String, Any?>): android.graphics.MaskFilter? {
        val type = filterData["_type"] as? String ?: return null
        
        return when (type) {
            "SkiaBackdropBlur" -> {
                val blur = (filterData["blur"] as? Number)?.toFloat() ?: 0f
                android.graphics.BlurMaskFilter(blur, android.graphics.BlurMaskFilter.Blur.NORMAL)
            }
            
            else -> null
        }
    }
    
    private fun loadImage(source: String): android.graphics.Bitmap? {
        return try {
            // Try loading from assets
            if (!source.contains("://") && !source.startsWith("/")) {
                val assetManager = this.context.assets
                val inputStream = assetManager.open(source)
                android.graphics.BitmapFactory.decodeStream(inputStream)
            }
            // Try loading from file system
            else if (source.startsWith("/")) {
                android.graphics.BitmapFactory.decodeFile(source)
            }
            // Try loading from network (synchronous - in production would use async)
            else if (source.startsWith("http://") || source.startsWith("https://")) {
                val url = java.net.URL(source)
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.connect()
                val inputStream = connection.inputStream
                android.graphics.BitmapFactory.decodeStream(inputStream)
            }
            // Try loading from data URI
            else if (source.startsWith("data:image/")) {
                val base64Data = source.substringAfter(",")
                val imageBytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT)
                android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            }
            else null
        } catch (e: Exception) {
            Log.e(SkiaCanvasView.TAG, "Failed to load image: $source", e)
            null
        }
    }
    
    private fun parseBlendMode(mode: String): android.graphics.PorterDuff.Mode {
        return when (mode) {
            "clear" -> android.graphics.PorterDuff.Mode.CLEAR
            "src" -> android.graphics.PorterDuff.Mode.SRC
            "dst" -> android.graphics.PorterDuff.Mode.DST
            "srcOver" -> android.graphics.PorterDuff.Mode.SRC_OVER
            "dstOver" -> android.graphics.PorterDuff.Mode.DST_OVER
            "srcIn" -> android.graphics.PorterDuff.Mode.SRC_IN
            "dstIn" -> android.graphics.PorterDuff.Mode.DST_IN
            "srcOut" -> android.graphics.PorterDuff.Mode.SRC_OUT
            "dstOut" -> android.graphics.PorterDuff.Mode.DST_OUT
            "srcATop" -> android.graphics.PorterDuff.Mode.SRC_ATOP
            "dstATop" -> android.graphics.PorterDuff.Mode.DST_ATOP
            "xor" -> android.graphics.PorterDuff.Mode.XOR
            "plus" -> android.graphics.PorterDuff.Mode.ADD
            "modulate" -> android.graphics.PorterDuff.Mode.MULTIPLY
            "screen" -> android.graphics.PorterDuff.Mode.SCREEN
            "overlay" -> android.graphics.PorterDuff.Mode.OVERLAY
            "darken" -> android.graphics.PorterDuff.Mode.DARKEN
            "lighten" -> android.graphics.PorterDuff.Mode.LIGHTEN
            "colorDodge" -> android.graphics.PorterDuff.Mode.LIGHTEN
            "colorBurn" -> android.graphics.PorterDuff.Mode.DARKEN
            "hardLight" -> android.graphics.PorterDuff.Mode.OVERLAY
            "softLight" -> android.graphics.PorterDuff.Mode.OVERLAY
            "difference" -> android.graphics.PorterDuff.Mode.DST_OVER // DIFFERENCE not available, use DST_OVER as fallback
            "exclusion" -> android.graphics.PorterDuff.Mode.OVERLAY
            "multiply" -> android.graphics.PorterDuff.Mode.MULTIPLY
            "hue" -> android.graphics.PorterDuff.Mode.SRC_ATOP
            "saturation" -> android.graphics.PorterDuff.Mode.SRC_ATOP
            "color" -> android.graphics.PorterDuff.Mode.SRC_ATOP
            "luminosity" -> android.graphics.PorterDuff.Mode.SRC_ATOP
            else -> android.graphics.PorterDuff.Mode.SRC_OVER
        }
    }
    
    private fun parseShapeColor(color: Any?): Int {
        if (color == null) return android.graphics.Color.BLACK
        
        if (color is Number) {
            return color.toInt()
        }
        
        if (color is String) {
            return parseColorString(color)
        }
        
        return android.graphics.Color.BLACK
    }
    
    private fun parseColorString(hex: String): Int {
        var hexSanitized = hex.trim()
        if (hexSanitized.startsWith("#")) {
            hexSanitized = hexSanitized.substring(1)
        }
        
        val rgb = hexSanitized.toLong(16)
        
        // Convert RGB to ARGB (with full alpha)
        val r = ((rgb shr 16) and 0xFF).toInt()
        val g = ((rgb shr 8) and 0xFF).toInt()
        val b = (rgb and 0xFF).toInt()
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    }
    
    private fun parseSVGPath(pathString: String, path: android.graphics.Path) {
        // Simplified SVG path parser - handles basic M, L, Z commands
        // For full SVG path support, consider using a library
        val commands = pathString.split(Regex("(?=[MLZ])"))
        var currentX = 0f
        var currentY = 0f
        
        for (cmd in commands) {
            val trimmed = cmd.trim()
            if (trimmed.isEmpty()) continue
            
            when (trimmed[0]) {
                'M', 'm' -> {
                    val coords = trimmed.substring(1).trim().split(Regex("[, ]+"))
                    if (coords.size >= 2) {
                        val x = coords[0].toFloat()
                        val y = coords[1].toFloat()
                        if (trimmed[0] == 'M') {
                            path.moveTo(x, y)
                            currentX = x
                            currentY = y
                        } else {
                            path.rMoveTo(x, y)
                            currentX += x
                            currentY += y
                        }
                    }
                }
                'L', 'l' -> {
                    val coords = trimmed.substring(1).trim().split(Regex("[, ]+"))
                    if (coords.size >= 2) {
                        val x = coords[0].toFloat()
                        val y = coords[1].toFloat()
                        if (trimmed[0] == 'L') {
                            path.lineTo(x, y)
                            currentX = x
                            currentY = y
                        } else {
                            path.rLineTo(x, y)
                            currentX += x
                            currentY += y
                        }
                    }
                }
                'Z', 'z' -> {
                    path.close()
                }
            }
        }
    }
    
    // MARK: - Particle System
    
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopFrameCallback()
    }
}

