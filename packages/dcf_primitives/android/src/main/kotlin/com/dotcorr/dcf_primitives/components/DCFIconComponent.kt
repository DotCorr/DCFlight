/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.graphics.PorterDuff
import android.view.View
import android.widget.ImageView
import androidx.core.content.ContextCompat
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcf_primitives.utils.AdaptiveColorHelper
import com.dotcorr.dcf_primitives.utils.ColorUtilities

/**
 * DCFIconComponent - 1:1 mapping with iOS DCFIconComponent
 * Displays system and custom icons like iOS SF Symbols
 */
class DCFIconComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val imageView = ImageView(context)
        
        // Set component identifier
        imageView.setTag(R.id.dcf_component_type, "Icon")
        
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

        // name prop - icon name (matches iOS SF Symbols system)
        props["name"]?.let { name ->
            val iconName = name.toString()
            loadIcon(imageView, iconName)
            hasUpdates = true
        }

        // size prop - icon size
        props["size"]?.let {
            val size = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 24
                else -> 24
            }
            val layoutParams = imageView.layoutParams ?: android.widget.LinearLayout.LayoutParams(size, size)
            layoutParams.width = size
            layoutParams.height = size
            imageView.layoutParams = layoutParams
            hasUpdates = true
        }

        // color prop
        props["color"]?.let {
            val colorInt = ColorUtilities.parseColor(it.toString())
            imageView.setColorFilter(colorInt, PorterDuff.Mode.SRC_IN)
            hasUpdates = true
        }

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Use adaptive text color for icon tint
                val adaptiveColor = AdaptiveColorHelper.getSystemTextColor(imageView.context)
                imageView.setColorFilter(adaptiveColor, PorterDuff.Mode.SRC_IN)
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    private fun loadIcon(imageView: ImageView, iconName: String) {
        try {
            // Map iOS SF Symbol names to Android Material Icons
            val resourceId = mapSFSymbolToAndroidResource(iconName)
            
            if (resourceId != 0) {
                val drawable = ContextCompat.getDrawable(imageView.context, resourceId)
                imageView.setImageDrawable(drawable)
            } else {
                // Try loading from drawable resources directly
                val context = imageView.context
                val drawableId = context.resources.getIdentifier(iconName, "drawable", context.packageName)
                if (drawableId != 0) {
                    val drawable = ContextCompat.getDrawable(context, drawableId)
                    imageView.setImageDrawable(drawable)
                } else {
                    // Fall back to a default icon
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
        // Map common iOS SF Symbol names to Android Material Icons
        return when (sfSymbolName) {
            // Navigation
            "chevron.left" -> android.R.drawable.ic_menu_revert
            "chevron.right" -> android.R.drawable.ic_media_ff
            "arrow.left" -> android.R.drawable.ic_menu_revert
            "arrow.right" -> android.R.drawable.ic_media_ff
            
            // Actions
            "plus" -> android.R.drawable.ic_menu_add
            "minus" -> android.R.drawable.ic_menu_delete
            "xmark" -> android.R.drawable.ic_menu_close_clear_cancel
            "checkmark" -> android.R.drawable.ic_menu_save
            
            // UI
            "gear" -> android.R.drawable.ic_menu_preferences
            "magnifyingglass" -> android.R.drawable.ic_menu_search
            "heart" -> android.R.drawable.btn_star_big_on
            "star" -> android.R.drawable.btn_star_big_off
            "star.fill" -> android.R.drawable.btn_star_big_on
            
            // Communication
            "envelope" -> android.R.drawable.ic_dialog_email
            "phone" -> android.R.drawable.ic_menu_call
            
            // Media
            "play" -> android.R.drawable.ic_media_play
            "pause" -> android.R.drawable.ic_media_pause
            "stop" -> android.R.drawable.ic_media_pause
            
            // Info
            "info.circle" -> android.R.drawable.ic_dialog_info
            "exclamationmark.triangle" -> android.R.drawable.ic_dialog_alert
            
            else -> 0 // Not found
        }
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val imageView = view as? ImageView ?: return PointF(0f, 0f)
        
        // Get icon size from props or use default
        val size = props["size"]?.let {
            when (it) {
                is Number -> it.toFloat()
                is String -> it.toFloatOrNull() ?: 24f
                else -> 24f
            }
        } ?: 24f
        
        return PointF(size, size)
    }

    // MARK: - Lifecycle Management - MATCH iOS
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Additional setup when view is registered, if needed
    }
}

