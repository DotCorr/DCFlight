/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.DCDivergerUtil
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * DCFlutterWidgetComponent - Embeds Flutter widgets directly into native components
 * 
 * This directly embeds Flutter's rendering pipeline into native components
 * without using platform views, providing high performance integration.
 */
class DCFFlutterWidgetComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFFlutterWidgetComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Create a container that will host the Flutter widget
        val container = FlutterWidgetContainer(context)
        container.setTag(DCFTags.COMPONENT_TYPE_KEY, "FlutterWidget")
        container.setTag(DCFTags.STORED_PROPS_KEY, props.toMutableMap())
        
        // Get widgetId from props
        val widgetId = props["widgetId"] as? String
        container.widgetId = widgetId
        
        // The Flutter widget will be rendered directly by Flutter's engine
        updateView(container, props)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        container.applyStyles(nonNullStyleProps)
        
        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val container = view as? FlutterWidgetContainer ?: return false
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(container, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update widgetId if changed
        val widgetId = mergedProps["widgetId"] as? String
        if (widgetId != null) {
            container.widgetId = widgetId
        }
        
        container.applyStyles(nonNullProps)
        return true
    }

    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        android.util.Log.d(TAG, "🎨 viewRegisteredWithShadowTree - nodeId: $nodeId")
        val container = view as? FlutterWidgetContainer
        container?.onReady(nodeId)
    }

    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        // Apply Yoga layout to the container
        view.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        
        android.util.Log.d(TAG, "🎨 applyLayout - view: ${view.javaClass.simpleName}, layout: (${layout.left}, ${layout.top}, ${layout.width}, ${layout.height})")
        
        // Update Flutter widget frame when layout changes
        if (view is FlutterWidgetContainer) {
            // Store layout dimensions (same as iOS stores in view.frame)
            // Convert Float to Double to match method signature
            view.setLayoutDimensions(layout.width.toDouble(), layout.height.toDouble())
            view.updateFlutterWidgetFrame()
        }
    }

    override fun prepareForRecycle(view: View) {
        // Cleanup if needed
        if (view is FlutterWidgetContainer) {
            view.dispose()
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }

    /**
     * Container that hosts Flutter widgets directly using Flutter's rendering pipeline
     */
    private class FlutterWidgetContainer(context: Context) : ViewGroup(context) {
        
        var widgetId: String? = null
        private var methodChannel: MethodChannel? = null
        private var nodeId: String? = null // Store the actual nodeId from viewRegisteredWithShadowTree
        private var layoutWidth: Double = 0.0 // Store layout width from Yoga (same as iOS view.frame.width)
        private var layoutHeight: Double = 0.0 // Store layout height from Yoga (same as iOS view.frame.height)
        
        init {
            setupMethodChannel()
        }
        
        fun setLayoutDimensions(width: Double, height: Double) {
            layoutWidth = width
            layoutHeight = height
        }
        
        private fun setupMethodChannel() {
            // Get Flutter engine and create method channel
            val engine = DCDivergerUtil.getFlutterEngine() ?: run {
                android.util.Log.w(TAG, "⚠️ FlutterEngine not available")
                return
            }
            
            methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "dcflight/flutter_widget")
        }
        
        fun onReady(nodeId: String) {
            android.util.Log.d(TAG, "🎨 onReady called - nodeId: $nodeId, widgetId: $widgetId")
            
            // Store the nodeId for later use (this is the actual viewId)
            this.nodeId = nodeId
            
            // Request widget rendering from Dart side
            val currentWidgetId = widgetId ?: run {
                android.util.Log.w(TAG, "⚠️ No widgetId available")
                return
            }
            
            // Use stored nodeId (actual viewId), not id
            val viewId = nodeId
            
            // Post to main thread to ensure view is laid out
            post {
                // Replicate iOS behavior exactly: use bounds (content area) converted to window coordinates
                // On iOS: convert(bounds, to: window) where bounds is (0, 0, width, height) from view.frame
                // On Android: getLocationInWindow gives position, use stored layout dimensions (from Yoga)
                val location = IntArray(2)
                getLocationInWindow(location)
                
                // Use stored layout dimensions from Yoga (same as iOS uses view.frame.width/height)
                // These are the actual calculated dimensions from the layout system
                val boundsWidth = if (layoutWidth > 0) layoutWidth else (if (measuredWidth > 0) measuredWidth.toDouble() else (right - left).toDouble())
                val boundsHeight = if (layoutHeight > 0) layoutHeight else (if (measuredHeight > 0) measuredHeight.toDouble() else (bottom - top).toDouble())
                
                // Convert bounds to window coordinates (same as iOS convert(bounds, to: window))
                val x = location[0].toDouble()
                val y = location[1].toDouble()
                val width = boundsWidth
                val height = boundsHeight
                
                android.util.Log.d(TAG, "🎨 onReady - frame: ($x, $y, $width, $height), layout: ($layoutWidth x $layoutHeight)")
                
                // Only call renderWidget if we have valid dimensions
                // If frame is invalid, updateWidgetFrame will be called later with correct frame
                if (width > 0 && height > 0) {
                    android.util.Log.d(TAG, "🎨 Requesting widget render - widgetId: $currentWidgetId, viewId: $viewId, frame: ($x, $y, $width, $height)")
                    
                    // Call Dart method channel to render widget
                    methodChannel?.invokeMethod("renderWidget", mapOf(
                        "widgetId" to currentWidgetId,
                        "viewId" to viewId,
                        "x" to x,
                        "y" to y,
                        "width" to width,
                        "height" to height
                    ), object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            android.util.Log.d(TAG, "✅ renderWidget succeeded")
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            android.util.Log.e(TAG, "❌ renderWidget error: $errorCode - $errorMessage")
                        }
                        override fun notImplemented() {
                            android.util.Log.w(TAG, "⚠️ renderWidget not implemented")
                        }
                    })
                } else {
                    android.util.Log.w(TAG, "⚠️ Invalid frame ($width x $height), will wait for updateWidgetFrame")
                }
            }
        }
        
        fun updateFlutterWidgetFrame() {
            // Replicate iOS behavior exactly: use bounds (content area) converted to window coordinates
            // On iOS: convert(bounds, to: window) where bounds is (0, 0, width, height) from view.frame
            // On Android: getLocationInWindow gives position, use stored layout dimensions (from Yoga)
            val boundsWidth = if (layoutWidth > 0) layoutWidth else (if (measuredWidth > 0) measuredWidth.toDouble() else (right - left).toDouble())
            val boundsHeight = if (layoutHeight > 0) layoutHeight else (if (measuredHeight > 0) measuredHeight.toDouble() else (bottom - top).toDouble())
            
            if (boundsWidth <= 0 || boundsHeight <= 0) {
                android.util.Log.d(TAG, "⚠️ updateFlutterWidgetFrame: Invalid dimensions ($boundsWidth x $boundsHeight), skipping")
                return
            }
            
            val currentWidgetId = widgetId ?: run {
                android.util.Log.w(TAG, "⚠️ updateFlutterWidgetFrame: No widgetId")
                return
            }
            // Use stored nodeId (actual viewId), not id
            val viewId = nodeId ?: run {
                android.util.Log.w(TAG, "⚠️ updateFlutterWidgetFrame: No nodeId")
                return
            }
            
            // Convert bounds to window coordinates (same as iOS convert(bounds, to: window))
            val location = IntArray(2)
            getLocationInWindow(location)
            
            val x = location[0].toDouble()
            val y = location[1].toDouble()
            val width = boundsWidth
            val height = boundsHeight
            
            android.util.Log.d(TAG, "🎨 Updating widget frame - viewId: $viewId, frame: ($x, $y, $width, $height), layout: ($layoutWidth x $layoutHeight)")
            
            // Call Dart method channel to update frame
            methodChannel?.invokeMethod("updateWidgetFrame", mapOf(
                "viewId" to viewId,
                "x" to x,
                "y" to y,
                "width" to width,
                "height" to height
            ), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    android.util.Log.d(TAG, "✅ updateWidgetFrame succeeded")
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    android.util.Log.e(TAG, "❌ updateWidgetFrame error: $errorCode - $errorMessage")
                }
                override fun notImplemented() {
                    android.util.Log.w(TAG, "⚠️ updateWidgetFrame not implemented")
                }
            })
            
            // If renderWidget hasn't been called yet (widget not in hosts), call it now
            // This handles the case where onReady was called with invalid frame
            methodChannel?.invokeMethod("renderWidget", mapOf(
                "widgetId" to currentWidgetId,
                "viewId" to viewId,
                "x" to x,
                "y" to y,
                "width" to width,
                "height" to height
            ), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    android.util.Log.d(TAG, "✅ renderWidget (from updateFlutterWidgetFrame) succeeded")
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    android.util.Log.w(TAG, "⚠️ renderWidget (from updateFlutterWidgetFrame) error: $errorCode - $errorMessage")
                }
                override fun notImplemented() {
                    android.util.Log.w(TAG, "⚠️ renderWidget (from updateFlutterWidgetFrame) not implemented")
                }
            })
        }
        
        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            // No children to layout
        }
        
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            
            // Update Flutter widget frame when size changes
            if (w > 0 && h > 0) {
                updateFlutterWidgetFrame()
            }
        }
        
        fun dispose() {
            // Use stored nodeId (actual viewId), not id
            val viewId = nodeId ?: return
            
            android.util.Log.d(TAG, "🎨 Disposing widget - viewId: $viewId")
            
            // Call Dart method channel to dispose widget
            methodChannel?.invokeMethod("disposeWidget", mapOf(
                "viewId" to viewId
            ))
        }
    }
}
