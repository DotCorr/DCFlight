/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.util.Log
import android.view.View
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import androidx.compose.ui.platform.ComposeView
import kotlin.math.max

/**
 * DCFTextComponent - Pure Compose Text implementation
 * 
 * Uses Jetpack Compose for rendering with Yoga layout integration.
 * ComposeView IS a View, so Yoga can measure and position it natively.
 * 
 * Benefits:
 * - No XML resources needed
 * - Modern Material Design 3 styling
 * - Consistent with Button component
 * - Works perfectly with Yoga layout
 */
class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val composeView = ComposeView(context)
        composeView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // CRITICAL: Set visibility explicitly
        composeView.visibility = View.VISIBLE
        composeView.alpha = 1.0f
        
        storeProps(composeView, props)
        
        // CRITICAL: Set content BEFORE applying styles
        // This ensures Compose can measure correctly
        updateComposeContent(composeView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        composeView.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created Compose-based Text component")
        
        return composeView
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val composeView = view as? ComposeView ?: return false
        
        // Always update content to ensure text is visible
        updateComposeContent(composeView, props)
        
        composeView.applyStyles(props)
        
        return true
    }
    
    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        val fontWeight = fontWeightFromString(props["fontWeight"]?.toString() ?: "regular")
        val textAlign = textAlignFromString(props["textAlign"]?.toString() ?: "start")
        val maxLines = (props["numberOfLines"] as? Number)?.toInt() ?: Int.MAX_VALUE
        
        // Get default color based on theme if no color is provided
        val context = composeView.context
        val isDarkTheme = (context.resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val defaultColor = if (isDarkTheme) android.graphics.Color.WHITE else android.graphics.Color.BLACK
        val finalColor = textColor ?: defaultColor
        
        composeView.setContent {
            Material3Text(
                text = content,
                color = finalColor,
                fontSize = fontSize,
                fontWeight = fontWeight,
                textAlign = textAlign,
                maxLines = if (maxLines == 0) Int.MAX_VALUE else maxLines
            )
        }
        
        if (content.isNotEmpty()) {
            Log.d(TAG, "Set text content: $content, color: ${ColorUtilities.hexString(finalColor)}")
        }
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // CRITICAL: Yoga calls getIntrinsicSize with emptyMap(), so we MUST get props from storedProps
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props
        
        val content = allProps["content"]?.toString() ?: ""
        if (content.isEmpty()) {
            Log.w(TAG, "getIntrinsicSize: No content found in props or storedProps")
            return PointF(0f, 0f)
        }
        
        // CRITICAL: ComposeView can't be reliably measured before it's laid out
        // Return preferred size - Yoga will constrain based on parent width
        // Compose Text will wrap automatically when given width constraints
        val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
        
        // For text wrapping: Return preferred width (single line estimate)
        // Yoga will constrain this based on parent width, and Compose Text will wrap
        // This matches TextView behavior where text wraps when parent width is constrained
        val preferredWidth = content.length * fontSize * 0.6f
        
        // Height: single line height (text will grow vertically when wrapping)
        val singleLineHeight = fontSize * 1.2f
        
        // Ensure minimum size
        val finalWidth = preferredWidth.coerceAtLeast(1f)
        val finalHeight = singleLineHeight.coerceAtLeast(1f)
        
        Log.d(TAG, "Text preferred size for Yoga: ${finalWidth}x${finalHeight} (will wrap if parent constrains width)")
        return PointF(finalWidth, finalHeight)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Compose Text component registered with shadow tree: $nodeId")
        
        // CRITICAL: Ensure content is set after registration
        // This fixes the issue where the last text component doesn't show
        val composeView = view as? ComposeView ?: return
        val storedProps = getStoredProps(view)
        updateComposeContent(composeView, storedProps)
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun fontWeightFromString(weight: String): FontWeight {
        return when (weight.lowercase()) {
            "thin", "100" -> FontWeight.Thin
            "ultralight", "200" -> FontWeight.ExtraLight
            "light", "300" -> FontWeight.Light
            "regular", "normal", "400" -> FontWeight.Normal
            "medium", "500" -> FontWeight.Medium
            "semibold", "600" -> FontWeight.SemiBold
            "bold", "700" -> FontWeight.Bold
            "heavy", "800" -> FontWeight.ExtraBold
            "black", "900" -> FontWeight.Black
            else -> FontWeight.Normal
        }
    }
    
    private fun textAlignFromString(align: String): TextAlign {
        return when (align.lowercase()) {
            "center" -> TextAlign.Center
            "right", "end" -> TextAlign.Right
            "left", "start" -> TextAlign.Left
            "justify" -> TextAlign.Justify
            else -> TextAlign.Start
        }
    }
}

@Composable
private fun Material3Text(
    text: String,
    color: Int,
    fontSize: Float,
    fontWeight: FontWeight,
    textAlign: TextAlign,
    maxLines: Int
) {
    // Text wraps by default in Compose when given proper constraints
    // No modifier needed - ComposeView will provide constraints from Yoga layout
    Text(
        text = text,
        color = Color(color),
        fontSize = fontSize.sp,
        fontWeight = fontWeight,
        textAlign = textAlign,
        maxLines = maxLines
    )
}
