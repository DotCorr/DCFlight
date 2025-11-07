/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.PointF
import android.graphics.drawable.Drawable
import android.util.Log
import android.view.View
import android.widget.ImageView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max

/**
 * EXACT iOS DCFImageComponent port for Android
 * Matches iOS DCFImageComponent.swift behavior 1:1
 */
class DCFImageComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFImageComponent"
        
        private val imageCache = ConcurrentHashMap<String, Drawable>()
        
        private fun getCachedImage(key: String): Drawable? = imageCache[key]
        private fun setCachedImage(image: Drawable, key: String) { imageCache[key] = image }
        private fun removeCachedImage(key: String) { imageCache.remove(key) }
        private fun clearAllCache() { imageCache.clear() }
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)
        
        
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.clipToOutline = true
        
        // Use updateView (not updateViewInternal) - framework handles props merging
        updateView(imageView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        imageView.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created image component")
        
        return imageView
    }

    // Remove override - let base class handle props merging
    // Note: ImageView type check is now in updateViewInternal

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val imageView = view as? ImageView ?: return false

        Log.d(TAG, "Updating image view with props: $props")

        // Framework-level helper: Only reload image if source actually changed (prevents reload on theme toggle)
        if (hasPropChanged("source", existingProps, props)) {
            props["source"]?.let { sourceAny ->
            val source: String
            
            source = when (sourceAny) {
                is String -> sourceAny
                is Number -> sourceAny.toString()
                else -> {
                    propagateEvent(imageView, "onError", mapOf("error" to "Invalid source type"))
                    return false
                }
            }
            
            if (source.isEmpty()) {
                propagateEvent(imageView, "onError", mapOf("error" to "Empty source"))
                return false
            }
            
            loadImageFromSource(imageView, source)
        }
        }

        // Framework-level helper: Only update resizeMode if it actually changed
        if (hasPropChanged("resizeMode", existingProps, props)) {
            props["resizeMode"]?.let { mode ->
            val scaleType = when (mode.toString()) {
                "cover" -> ImageView.ScaleType.CENTER_CROP  // scaleAspectFill
                "contain" -> ImageView.ScaleType.FIT_CENTER // scaleAspectFit
                "stretch" -> ImageView.ScaleType.FIT_XY     // scaleToFill
                "repeat" -> ImageView.ScaleType.CENTER      // scaleAspectFit with tiling
                "center" -> ImageView.ScaleType.CENTER      // center
                else -> ImageView.ScaleType.FIT_CENTER
            }
            imageView.scaleType = scaleType
            Log.d(TAG, "Set resize mode: $mode")
        }
        }

        imageView.applyStyles(props)

        return true
    }

    private fun loadImageFromSource(imageView: ImageView, source: String) {
        Log.d(TAG, "Loading image from source: $source")
        
        when {
            source.startsWith("http://") || source.startsWith("https://") -> {
                Log.d(TAG, "Loading network image: $source")
                imageView.setTag(R.id.dcf_image_source, source)
                
                propagateEvent(imageView, "onLoadStart", mapOf("source" to source))
            }
            
            source.startsWith("file://") -> {
                loadImageFromFile(imageView, source.substring(7))
            }
            
            source.contains("/") -> {
                loadImageFromAssets(imageView, source)
            }
            
            else -> {
                loadImageFromDrawable(imageView, source)
            }
        }
    }

    private fun loadImageFromFile(imageView: ImageView, filePath: String) {
        Log.d(TAG, "Loading image from file: $filePath")
        
        try {
            val cachedImage = getCachedImage(filePath)
            if (cachedImage != null) {
                imageView.setImageDrawable(cachedImage)
                propagateEvent(imageView, "onLoad", mapOf("source" to filePath))
                return
            }
            
            val drawable = Drawable.createFromPath(filePath)
            if (drawable != null) {
                setCachedImage(drawable, filePath)
                imageView.setImageDrawable(drawable)
                propagateEvent(imageView, "onLoad", mapOf("source" to filePath))
            } else {
                propagateEvent(imageView, "onError", mapOf("error" to "File not found: $filePath"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading image from file: $filePath", e)
            propagateEvent(imageView, "onError", mapOf<String, Any?>("error" to (e.message ?: "Unknown error")))
        }
    }

    private fun loadImageFromAssets(imageView: ImageView, assetPath: String) {
        Log.d(TAG, "Loading image from assets: $assetPath")
        
        try {
            val cachedImage = getCachedImage(assetPath)
            if (cachedImage != null) {
                imageView.setImageDrawable(cachedImage)
                propagateEvent(imageView, "onLoad", mapOf("source" to assetPath))
                return
            }
            
            val inputStream = imageView.context.assets.open(assetPath)
            val drawable = Drawable.createFromStream(inputStream, null)
            inputStream.close()
            
            if (drawable != null) {
                setCachedImage(drawable, assetPath)
                imageView.setImageDrawable(drawable)
                propagateEvent(imageView, "onLoad", mapOf("source" to assetPath))
            } else {
                propagateEvent(imageView, "onError", mapOf("error" to "Asset not found: $assetPath"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading image from assets: $assetPath", e)
            propagateEvent(imageView, "onError", mapOf<String, Any?>("error" to (e.message ?: "Unknown error")))
        }
    }

    private fun loadImageFromDrawable(imageView: ImageView, drawableName: String) {
        Log.d(TAG, "Loading image from drawable: $drawableName")
        
        try {
            val context = imageView.context
            val resourceId = context.resources.getIdentifier(drawableName, "drawable", context.packageName)
            
            if (resourceId != 0) {
                imageView.setImageResource(resourceId)
                propagateEvent(imageView, "onLoad", mapOf("source" to drawableName))
            } else {
                propagateEvent(imageView, "onError", mapOf("error" to "Drawable not found: $drawableName"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading drawable: $drawableName", e)
            propagateEvent(imageView, "onError", mapOf<String, Any?>("error" to (e.message ?: "Unknown error")))
        }
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val imageView = view as? ImageView ?: return PointF(0f, 0f)

        val drawable = imageView.drawable
        if (drawable != null) {
            val intrinsicWidth = drawable.intrinsicWidth.toFloat()
            val intrinsicHeight = drawable.intrinsicHeight.toFloat()
            
            if (intrinsicWidth > 0 && intrinsicHeight > 0) {
                Log.d(TAG, "Image intrinsic size: ${intrinsicWidth}x${intrinsicHeight}")
                return PointF(intrinsicWidth, intrinsicHeight)
            }
        }

        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Image component registered with shadow tree: $nodeId")
    }
}
