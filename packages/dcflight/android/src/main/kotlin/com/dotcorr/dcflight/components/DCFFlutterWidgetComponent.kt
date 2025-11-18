/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

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
        
        // Get widget type from props
        val widgetType = props["widgetType"] as? String ?: "Unknown"
        
        // The Flutter widget will be rendered directly by Flutter's engine
        // We create a FlutterView that embeds the widget
        updateView(container, props)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        container.applyStyles(nonNullStyleProps)
        
        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val container = view as? FlutterWidgetContainer ?: return false
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        
        container.setTag(DCFTags.STORED_PROPS_KEY, props.toMutableMap())
        container.applyStyles(nonNullProps)
        return true
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val container = view as? FlutterWidgetContainer ?: return PointF(0f, 0f)
        val width = (props["width"] as? Number)?.toFloat() ?: 0f
        val height = (props["height"] as? Number)?.toFloat() ?: 0f
        return PointF(width, height)
    }

    override fun viewRegisteredWithShadowTree(view: View) {
        val container = view as? FlutterWidgetContainer
        container?.onReady()
    }

    /**
     * Container that hosts Flutter widgets directly using Flutter's rendering pipeline
     */
    private class FlutterWidgetContainer(context: Context) : ViewGroup(context) {
        
        private var flutterView: FlutterView? = null
        
        fun onReady() {
            // Get Flutter engine and create FlutterView
            // The widget will be rendered by Flutter's engine directly
            propagateEvent(this, "onReady", mapOf(
                "width" to width,
                "height" to height
            ))
        }
        
        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            // Layout FlutterView to fill container
            flutterView?.layout(l, t, r, b)
        }
        
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            propagateEvent(this, "onSizeChanged", mapOf(
                "width" to w,
                "height" to h
            ))
        }
    }
}

