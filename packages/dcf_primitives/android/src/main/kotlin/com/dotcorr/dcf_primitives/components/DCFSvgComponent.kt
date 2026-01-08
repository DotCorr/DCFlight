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
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFSvgComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)
        
        ColorUtilities.getColor("tintColor", "primaryColor", props)?.let { colorInt ->
            imageView.setColorFilter(colorInt, android.graphics.PorterDuff.Mode.SRC_IN)
        }
        
        imageView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Svg")
        
        updateView(imageView, props)
        return imageView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val imageView = view as ImageView
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        mergedProps["source"]?.let { source ->
            when (source) {
                is String -> {
                    loadSvgFromSource(imageView, source)
                }
                is Map<*, *> -> {
                    (source["uri"] as? String)?.let { uri ->
                        loadSvgFromSource(imageView, uri)
                    }
                }
            }
        }

        ColorUtilities.getColor("tintColor", "primaryColor", nonNullProps)?.let { colorInt ->
            imageView.setColorFilter(colorInt, android.graphics.PorterDuff.Mode.SRC_IN)
        }

        view.applyStyles(nonNullProps)
        return true
    }

    private fun loadSvgFromSource(imageView: ImageView, source: String) {
        try {
            when {
                source.startsWith("asset://") -> {
                    val assetPath = source.removePrefix("asset://")
                    loadSvgFromAssets(imageView, assetPath)
                }
                
                source.startsWith("drawable://") -> {
                    val drawableName = source.removePrefix("drawable://")
                    loadSvgFromDrawable(imageView, drawableName)
                }
                
                else -> {
                    loadSvgFromDrawable(imageView, source)
                }
            }
        } catch (e: Exception) {
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
            
            propagateEvent(imageView, "onLoad", mapOf(
                "source" to assetPath,
                "type" to "asset"
            ))
        } catch (e: Exception) {
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
                
                propagateEvent(imageView, "onLoad", mapOf(
                    "source" to drawableName,
                    "type" to "drawable",
                    "resourceId" to resourceId
                ))
            } else {
                propagateEvent(imageView, "onError", mapOf(
                    "error" to "SVG not found: $drawableName",
                    "source" to drawableName
                ))
            }
        } catch (e: Exception) {
            propagateEvent(imageView, "onError", mapOf(
                "error" to "Error loading SVG: ${e.message}",
                "source" to drawableName
            ))
        }
    }


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

