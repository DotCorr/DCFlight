/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.ImageView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcflight.utils.AdaptiveColorHelper

/**
 * DCFSvgComponent - 1:1 mapping with iOS DCFSvgComponent
 * Displays SVG images like iOS
 */
class DCFSvgComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)
        
        // Let the system handle visibility naturally - no manual control
        
        // Set component identifier
        imageView.setTag(R.id.dcf_component_type, "Svg")
        
        // Apply initial props
        updateView(imageView, props)
        return imageView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val imageView = view as ImageView
        var hasUpdates = false

        // source prop - matches iOS exactly
        props["source"]?.let { source ->
            when (source) {
                is String -> {
                    loadSvgFromSource(imageView, source)
                    hasUpdates = true
                }
                is Map<*, *> -> {
                    // Handle object format like { uri: "..." }
                    (source["uri"] as? String)?.let { uri ->
                        loadSvgFromSource(imageView, uri)
                        hasUpdates = true
                    }
                }
            }
        }

        // width prop
        props["width"]?.let {
            val width = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 100
                else -> 100
            }
            hasUpdates = true
        }

        // height prop
        props["height"]?.let {
            val height = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 100
                else -> 100
            }
            hasUpdates = true
        }

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Apply adaptive background color for container
                imageView.setBackgroundColor(AdaptiveColorHelper.getSystemBackgroundColor(imageView.context))
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    private fun loadSvgFromSource(imageView: ImageView, source: String) {
        try {
            when {
                source.startsWith("asset://") -> {
                    // Load from assets
                    val assetPath = source.removePrefix("asset://")
                    loadSvgFromAssets(imageView, assetPath)
                }
                
                source.startsWith("drawable://") -> {
                    // Load from drawable resources
                    val drawableName = source.removePrefix("drawable://")
                    loadSvgFromDrawable(imageView, drawableName)
                }
                
                else -> {
                    // Try as drawable resource name
                    loadSvgFromDrawable(imageView, source)
                }
            }
        } catch (e: Exception) {
            // 🚀 MATCH iOS: Use propagateEvent for onError
            propagateEvent(imageView, "onError", mapOf(
                "error" to "SVG loading error: ${e.message}",
                "source" to source
            ))
        }
    }

    private fun loadSvgFromAssets(imageView: ImageView, assetPath: String) {
        try {
            val context = imageView.context
            val inputStream = context.assets.open(assetPath)
            val drawable = Drawable.createFromStream(inputStream, null)
            imageView.setImageDrawable(drawable)
            inputStream.close()
            
            // 🚀 MATCH iOS: Use propagateEvent for onLoad
            propagateEvent(imageView, "onLoad", mapOf(
                "source" to assetPath,
                "type" to "asset"
            ))
        } catch (e: Exception) {
            // 🚀 MATCH iOS: Use propagateEvent for onError
            propagateEvent(imageView, "onError", mapOf(
                "error" to "SVG not found: $assetPath",
                "source" to assetPath
            ))
        }
    }

    private fun loadSvgFromDrawable(imageView: ImageView, drawableName: String) {
        try {
            val context = imageView.context
            val resourceId = context.resources.getIdentifier(
                drawableName,
                "drawable",
                context.packageName
            )
            if (resourceId != 0) {
                imageView.setImageResource(resourceId)
                
                // 🚀 MATCH iOS: Use propagateEvent for onLoad
                propagateEvent(imageView, "onLoad", mapOf(
                    "source" to drawableName,
                    "type" to "drawable",
                    "resourceId" to resourceId
                ))
            } else {
                // 🚀 MATCH iOS: Use propagateEvent for onError
                propagateEvent(imageView, "onError", mapOf(
                    "error" to "SVG not found: $drawableName",
                    "source" to drawableName
                ))
            }
        } catch (e: Exception) {
            // 🚀 MATCH iOS: Use propagateEvent for onError
            propagateEvent(imageView, "onError", mapOf(
                "error" to "Error loading SVG: ${e.message}",
                "source" to drawableName
            ))
        }
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val imageView = view as? ImageView ?: return PointF(0f, 0f)

        // Get drawable dimensions if available
        val drawable = imageView.drawable
        if (drawable != null) {
            val intrinsicWidth = drawable.intrinsicWidth.toFloat()
            val intrinsicHeight = drawable.intrinsicHeight.toFloat()
            
            if (intrinsicWidth > 0 && intrinsicHeight > 0) {
                return PointF(intrinsicWidth, intrinsicHeight)
            }
        }

        // Fallback to measured dimensions
        imageView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = imageView.measuredWidth.toFloat()
        val measuredHeight = imageView.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // SVG components are typically leaf nodes and don't need special handling
    }
}

