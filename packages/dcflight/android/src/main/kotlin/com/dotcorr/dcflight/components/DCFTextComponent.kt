package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.Typeface
import android.text.Layout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.text.DCFTextView
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
        private const val DEFAULT_FONT_SIZE = 14f
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val textView = DCFTextView(context)
        textView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        storeProps(textView, props)
        updateTextView(textView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        textView.applyStyles(nonNullProps)
        
        return textView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val textView = view as? DCFTextView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(textView, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        updateTextView(textView, nonNullProps)
        textView.applyStyles(nonNullProps)
        
        return true
    }
    
    private fun updateTextView(textView: DCFTextView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
        val fontWeight = props["fontWeight"]?.toString() ?: "normal"
        val fontFamily = props["fontFamily"]?.toString()
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        paint.textSize = fontSize
        
        val typefaceStyle = fontWeightToTypefaceStyle(fontWeight)
        paint.typeface = if (fontFamily != null) {
            Typeface.create(fontFamily, typefaceStyle)
        } else {
            Typeface.create(Typeface.DEFAULT, typefaceStyle)
        }
        
        if (textColor != null) {
            paint.color = textColor
        }
        
        val alignment = textAlignToLayoutAlignment(textAlign)
        val maxWidth = 10000
        
        val layout = if (content.isNotEmpty()) {
            createTextLayout(
                content,
                paint,
                maxWidth,
                alignment,
                numberOfLines
            )
        } else {
            null
        }
        
        textView.textLayout = layout
        
        if (layout != null) {
            textView.textFrameLeft = 0f
            textView.textFrameTop = 0f
        }
        
        nodeId?.let { id ->
            com.dotcorr.dcflight.layout.DCFLayoutManager.shared.markNodeDirty(id)
            com.dotcorr.dcflight.layout.DCFLayoutManager.shared.triggerLayoutCalculation()
        }
    }

    private var nodeId: String? = null

    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        this.nodeId = nodeId
        view.setTag("nodeId".hashCode(), nodeId)
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun createTextLayout(
        text: String,
        paint: TextPaint,
        maxWidth: Int,
        alignment: Layout.Alignment,
        maxLines: Int
    ): Layout {
        val builder = android.text.StaticLayout.Builder.obtain(text, 0, text.length, paint, maxWidth)
            .setAlignment(alignment)
            .setLineSpacing(0f, 1f)
            .setIncludePad(true)
        
        if (maxLines > 0) {
            builder.setMaxLines(maxLines)
            builder.setEllipsize(TextUtils.TruncateAt.END)
        }
        
        return builder.build()
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
    
    private fun textAlignToLayoutAlignment(align: String): Layout.Alignment {
        return when (align.lowercase()) {
            "center" -> Layout.Alignment.ALIGN_CENTER
            "right", "end" -> Layout.Alignment.ALIGN_OPPOSITE
            "left", "start" -> Layout.Alignment.ALIGN_NORMAL
            "justify" -> Layout.Alignment.ALIGN_NORMAL
            else -> Layout.Alignment.ALIGN_NORMAL
        }
    }
}
