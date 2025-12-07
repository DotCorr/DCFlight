package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.Typeface
import android.text.Layout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
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
        // Try to get collected text from shadow node if available
        // This ensures we use text collected from children (for nested text styling)
        val shadowNode = nodeId?.let { id ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(id.toIntOrNull() ?: 0)
        } as? com.dotcorr.dcflight.components.text.DCFVirtualTextShadowNode
        
        val text: CharSequence = if (shadowNode != null) {
            // Use collected text from shadow node (includes text from children with spans)
            shadowNode.getText()
        } else {
            // Fallback to content prop if shadow node not available yet
            props["content"]?.toString() ?: ""
        }
        
        if (text.isEmpty()) {
            textView.textLayout = null
            return
        }
        
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        
        // Layout will be created with proper width in applyLayout
        // For now, create a temporary layout for initial rendering
        // The actual layout will be recreated with correct width during layout application
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        // Set default text size (spans will override if needed)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
        paint.textSize = fontSize
        
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        // Use view width if available, otherwise use a large value for initial layout
        val maxWidth = if (textView.width > 0) {
            textView.width
        } else {
            // Large but finite width for initial layout (will be recreated with correct width in applyLayout)
            10000
        }
        
        val layout = createTextLayout(
            text,
            paint,
            maxWidth,
            alignment,
            numberOfLines
        )
        
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
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        // First, apply the frame (matches iOS behavior)
        super.applyLayout(view, layout)
        
        // Then, update the text layout with the correct width
        // This matches iOS DCFTextComponent.applyLayout which updates textStorage and textFrame
        val textView = view as? DCFTextView ?: return
        
        // Get shadow node to retrieve text and styling
        val shadowNode = nodeId?.let { id ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(id.toIntOrNull() ?: 0)
        } as? com.dotcorr.dcflight.components.text.DCFVirtualTextShadowNode
        
        if (shadowNode == null) {
            // Fallback to props if shadow node not available
            val props = getStoredProps(view)
            updateTextView(textView, props)
            return
        }
        
        // Get collected text from shadow node (includes text from children with spans)
        val spannableText = shadowNode.getText()
        
        if (spannableText.isEmpty()) {
            textView.textLayout = null
            return
        }
        
        // Get props for styling (spans are already applied to spannableText)
        val props = getStoredProps(view)
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        
        // Create paint for layout (spans will override paint properties)
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        // Set default text size (spans will override if needed)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
        paint.textSize = fontSize
        
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        // CRITICAL: Use the actual layout width (not a large default)
        // This ensures the text layout matches the view's actual width
        val maxWidth = layout.width.toInt().coerceAtLeast(0)
        
        // Create layout with correct width and spannable text (spans are preserved)
        val layoutObj = createTextLayout(
            spannableText,
            paint,
            maxWidth,
            alignment,
            numberOfLines
        )
        
        textView.textLayout = layoutObj
        
        // Request layout to update measured dimensions
        textView.requestLayout()
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun createTextLayout(
        text: CharSequence,
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
