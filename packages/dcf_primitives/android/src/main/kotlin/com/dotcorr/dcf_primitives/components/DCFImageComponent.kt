/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.ImageView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import java.net.URL

/**
 * DCFImageComponent - Image display component matching iOS DCFImageComponent
 */
class DCFImageComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)

        // Set default scale type
        imageView.scaleType = ImageView.ScaleType.FIT_CENTER

        // Apply props
        updateView(imageView, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        imageView.applyStyles(nonNullStyleProps)

        // Store component type for identification
        imageView.setTag(R.id.dcf_component_type, "Image")

        return imageView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val imageView = view as? ImageView ?: return false

        // Handle image source
        props["source"]?.let { source ->
            when (source) {
                is String -> loadImageFromSource(imageView, source)
                is Map<*, *> -> {
                    // Handle object format like { uri: "..." }
                    (source["uri"] as? String)?.let { uri ->
                        loadImageFromSource(imageView, uri)
                    }
                }

                is Int -> {
                    // Resource ID
                    imageView.setImageResource(source)
                }
            }
        }

        // Handle resize mode
        props["resizeMode"]?.let { mode ->
            imageView.scaleType = when (mode) {
                "cover" -> ImageView.ScaleType.CENTER_CROP
                "contain" -> ImageView.ScaleType.FIT_CENTER
                "stretch" -> ImageView.ScaleType.FIT_XY
                "repeat" -> ImageView.ScaleType.CENTER // Android doesn't have built-in repeat
                "center" -> ImageView.ScaleType.CENTER
                else -> ImageView.ScaleType.FIT_CENTER
            }
        }

        imageView.scaleType = scaleType
        }

        return true
    }
    }

    private fun loadImageFromSource(imageView: ImageView, source: String) {
        when {
            source.startsWith("http://") || source.startsWith("https://") -> {
                // Network image - would need image loading library like Glide/Picasso
                // For now, store the URL
                imageView.setTag(R.id.dcf_image_source, source)
                // TODO: Implement actual network image loading
                // Example with Glide:
                // Glide.with(imageView.context)
                //     .load(source)
                //     .into(imageView)
            }

            source.startsWith("file://") -> {
                // Local file
                val path = source.removePrefix("file://")
                // TODO: Load from file path
                imageView.setTag(R.id.dcf_image_source, path)
            }

            source.startsWith("asset://") -> {
                // Asset file
                val assetPath = source.removePrefix("asset://")
                loadImageFromAssets(imageView, assetPath)
            }

            source.startsWith("drawable://") -> {
                // Drawable resource
                val drawableName = source.removePrefix("drawable://")
                loadImageFromDrawable(imageView, drawableName)
            }

            else -> {
                // Try as drawable resource name
                loadImageFromDrawable(imageView, source)
            }
        }
    }

    private fun loadImageFromAssets(imageView: ImageView, assetPath: String) {
        try {
            val context = imageView.context
            val inputStream = context.assets.open(assetPath)
            val drawable = Drawable.createFromStream(inputStream, null)
            imageView.setImageDrawable(drawable)
            inputStream.close()
        } catch (e: Exception) {
            // Asset not found or error loading
            e.printStackTrace()
        }
    }

    private fun loadImageFromDrawable(imageView: ImageView, drawableName: String) {
        try {
            val context = imageView.context
            val resourceId = context.resources.getIdentifier(
                drawableName,
                "drawable",
                context.packageName
            )
            if (resourceId != 0) {
                imageView.setImageResource(resourceId)
            }
        } catch (e: Exception) {
            // Drawable not found
            e.printStackTrace()
        }
    }

    companion object {
        // Image loading modes matching iOS
        const val SCALE_MODE_FILL = "fill"
        const val SCALE_MODE_ASPECT_FIT = "aspectFit"
        const val SCALE_MODE_ASPECT_FILL = "aspectFill"
        const val SCALE_MODE_CENTER = "center"

        // Content modes matching iOS UIViewContentMode
        const val CONTENT_MODE_SCALE_TO_FILL = 0
        const val CONTENT_MODE_SCALE_ASPECT_FIT = 1
        const val CONTENT_MODE_SCALE_ASPECT_FILL = 2
        const val CONTENT_MODE_CENTER = 4
        const val CONTENT_MODE_TOP = 5
        const val CONTENT_MODE_BOTTOM = 6
        const val CONTENT_MODE_LEFT = 7
        const val CONTENT_MODE_RIGHT = 8
    }
}
