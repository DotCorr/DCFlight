/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.graphics.Typeface
import android.text.TextUtils
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val textView = TextView(context)
        textView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        storeProps(textView, props)
        
        updateTextView(textView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        textView.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created TextView-based Text component")
        
        return textView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val textView = view as? TextView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(textView, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        updateTextView(textView, nonNullProps)
        textView.applyStyles(nonNullProps)
        
        return true
    }
    
    private fun updateTextView(textView: TextView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        textView.text = content
        
        // CRITICAL: Always set text color - use primaryColor from styleSheet or default
        // This ensures text is visible even if color isn't explicitly set
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        if (textColor != null) {
            textView.setTextColor(textColor)
        } else {
            // Default to black/white based on theme if no color specified
            val context = textView.context
            val isDarkTheme = (context.resources.configuration.uiMode and 
                android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
                android.content.res.Configuration.UI_MODE_NIGHT_YES
            val defaultColor = if (isDarkTheme) android.graphics.Color.WHITE else android.graphics.Color.BLACK
            textView.setTextColor(defaultColor)
        }
        
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        textView.textSize = fontSize
        
        val fontWeight = props["fontWeight"]?.toString() ?: "regular"
        textView.setTypeface(null, fontWeightToTypefaceStyle(fontWeight))
        
        val textAlign = props["textAlign"]?.toString() ?: "start"
        textView.gravity = textAlignToGravity(textAlign)
        
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        if (numberOfLines > 0) {
            textView.maxLines = numberOfLines
            textView.ellipsize = TextUtils.TruncateAt.END
        } else {
            textView.maxLines = Int.MAX_VALUE
        }
        
        if (content.isNotEmpty()) {
            Log.d(TAG, "Updated text content: $content, color: ${textColor?.let { ColorUtilities.hexString(it) }}")
        }
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val textView = view as? TextView ?: return PointF(0f, 0f)
        
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props
        val content = allProps["content"]?.toString() ?: ""
        
        if (content.isEmpty()) {
            return PointF(0f, 0f)
        }
        
        // Match iOS: Use actual measurement, not estimate
        // iOS: label.sizeThatFits(maxSize) - we do the same with TextView
        val maxWidth = 10000 // Large but finite width for measurement
        textView.measure(
            View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        
        val measuredWidth = textView.measuredWidth.toFloat()
        val measuredHeight = textView.measuredHeight.toFloat()
        
        return PointF(measuredWidth.coerceAtLeast(1f), measuredHeight.coerceAtLeast(1f))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // TextView is ready immediately, no special handling needed
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun fontWeightToTypefaceStyle(weight: String): Int {
        return when (weight.lowercase()) {
            "thin", "100" -> Typeface.NORMAL
            "ultralight", "200" -> Typeface.NORMAL
            "light", "300" -> Typeface.NORMAL
            "regular", "normal", "400" -> Typeface.NORMAL
            "medium", "500" -> Typeface.NORMAL
            "semibold", "600" -> Typeface.BOLD
            "bold", "700" -> Typeface.BOLD
            "heavy", "800" -> Typeface.BOLD
            "black", "900" -> Typeface.BOLD
            else -> Typeface.NORMAL
        }
    }
    
    private fun textAlignToGravity(align: String): Int {
        return when (align.lowercase()) {
            "center" -> Gravity.CENTER
            "right", "end" -> Gravity.END or Gravity.CENTER_VERTICAL
            "left", "start" -> Gravity.START or Gravity.CENTER_VERTICAL
            "justify" -> Gravity.START or Gravity.CENTER_VERTICAL
            else -> Gravity.START or Gravity.CENTER_VERTICAL
        }
    }
}
