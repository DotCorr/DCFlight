/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.graphics.PorterDuff
import android.view.View
import android.widget.ImageView
import androidx.core.content.ContextCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFIconComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)
        
        ColorUtilities.getColor("iconColor", "primaryColor", props)?.let { colorInt ->
            imageView.setColorFilter(colorInt, PorterDuff.Mode.SRC_IN)
        }
        
        imageView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Icon")
        
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

        mergedProps["name"]?.let { name ->
            loadIcon(imageView, name.toString())
        }

        mergedProps["size"]?.let {
            val size = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 24
                else -> 24
            }
            val layoutParams = imageView.layoutParams ?: android.widget.LinearLayout.LayoutParams(size, size)
            layoutParams.width = size
            layoutParams.height = size
            imageView.layoutParams = layoutParams
        }

        ColorUtilities.getColor("iconColor", "primaryColor", nonNullProps)?.let { colorInt ->
            imageView.setColorFilter(colorInt, PorterDuff.Mode.SRC_IN)
        }

        view.applyStyles(nonNullProps)
        return true
    }

    private fun loadIcon(imageView: ImageView, iconName: String) {
        try {
            val resourceId = mapSFSymbolToAndroidResource(iconName)
            
            if (resourceId != 0) {
                val drawable = ContextCompat.getDrawable(imageView.context, resourceId)
                imageView.setImageDrawable(drawable)
            } else {
                val context = imageView.context
                val drawableId = context.resources.getIdentifier(iconName, "drawable", context.packageName)
                if (drawableId != 0) {
                    val drawable = ContextCompat.getDrawable(context, drawableId)
                    imageView.setImageDrawable(drawable)
                } else {
                    propagateEvent(imageView, "onError", mapOf(
                        "error" to "Icon not found: $iconName"
                    ))
                }
            }
        } catch (e: Exception) {
            propagateEvent(imageView, "onError", mapOf(
                "error" to "Icon loading error: ${e.message}",
                "iconName" to iconName
            ))
        }
    }

    private fun mapSFSymbolToAndroidResource(sfSymbolName: String): Int {
        return when (sfSymbolName) {
            "chevron.left" -> android.R.drawable.ic_menu_revert
            "chevron.right" -> android.R.drawable.ic_media_ff
            "arrow.left" -> android.R.drawable.ic_menu_revert
            "arrow.right" -> android.R.drawable.ic_media_ff
            
            "plus" -> android.R.drawable.ic_menu_add
            "minus" -> android.R.drawable.ic_menu_delete
            "xmark" -> android.R.drawable.ic_menu_close_clear_cancel
            "checkmark" -> android.R.drawable.ic_menu_save
            
            "gear" -> android.R.drawable.ic_menu_preferences
            "magnifyingglass" -> android.R.drawable.ic_menu_search
            "heart" -> android.R.drawable.btn_star_big_on
            "star" -> android.R.drawable.btn_star_big_off
            "star.fill" -> android.R.drawable.btn_star_big_on
            
            "envelope" -> android.R.drawable.ic_dialog_email
            "phone" -> android.R.drawable.ic_menu_call
            
            "play" -> android.R.drawable.ic_media_play
            "pause" -> android.R.drawable.ic_media_pause
            "stop" -> android.R.drawable.ic_media_pause
            
            "info.circle" -> android.R.drawable.ic_dialog_info
            "exclamationmark.triangle" -> android.R.drawable.ic_dialog_alert
            
            else -> 0 // Not found
        }
    }

    
    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

