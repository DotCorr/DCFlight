package com.dotcorr.dcflight.components

import android.content.Context
import android.text.Layout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.text.DCFTextView
import com.dotcorr.dcflight.extensions.applyStyles

/**
 * DCFTextComponent - Native Android text rendering using StaticLayout
 * 
 * This implementation follows React Native's flat renderer (RCTText) approach:
 * - Uses StaticLayout for text measurement and rendering (matches React Native's TextLayoutBuilder)
 * - Draws text manually on canvas (matches React Native's DrawTextLayout)
 * - Uses custom View with onDraw() to render StaticLayout
 * 
 * This matches React Native's flat renderer which uses StaticLayout, not TextView.
 */
class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
        private const val DEFAULT_FONT_SIZE = 17f // Match iOS default (iOS uses 17, React Native uses 14)
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
        // CRITICAL: Always try to get collected text from shadow node (matches React Native's flat renderer)
        // Text components always use DCFVirtualTextShadowNode (created in YogaShadowTree.createNode)
        val shadowNode = nodeId?.let { id ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(id.toIntOrNull() ?: 0)
        } as? com.dotcorr.dcflight.components.text.DCFVirtualTextShadowNode
        
        val text: CharSequence = if (shadowNode != null) {
            // CRITICAL: Use collected text from shadow node (includes text from children with spans)
            // This matches React Native's RCTVirtualText.getText() - a Spannable with all styling
            // When shadow tree changes, getText() will return updated text automatically
            shadowNode.getText()
        } else {
            // Fallback to content prop if shadow node not available yet
            props["content"]?.toString() ?: ""
        }
        
        if (text.isEmpty()) {
            textView.textLayout = null
            return
        }
        
        // CRITICAL: Get font size from shadow node (matches React Native's flat renderer)
        val fontSize = if (shadowNode != null) {
            shadowNode.getFontSize().toFloat()
        } else {
            (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
        }
        
        // Create TextPaint for layout (matches React Native's flat renderer)
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        paint.textSize = fontSize
        
        // Apply letter spacing if specified (available since API 21, matches React Native)
        val letterSpacing = if (shadowNode != null) {
            shadowNode.letterSpacing
        } else {
            (props["letterSpacing"] as? Number)?.toFloat() ?: 0f
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP && !letterSpacing.isNaN() && letterSpacing != 0f) {
            paint.letterSpacing = letterSpacing / fontSize // Android uses em-based letter spacing
        }
        
        // Get text alignment
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        // Get number of lines
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        
        // Get line height
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        
        // Use view width if available, otherwise use a large value for initial layout
        // The actual layout will be recreated with correct width in applyLayout
        val maxWidth = if (textView.width > 0) {
            textView.width
        } else {
            10000 // Large but finite width for initial layout
        }
        
        // Create StaticLayout (matches React Native's flat renderer createTextLayout)
        // CRITICAL: Use collected text with spans (matches React Native's DrawTextLayout)
        val layout = createTextLayout(
            text,
            paint,
            maxWidth,
            alignment,
            numberOfLines,
            lineHeight
        )
        
        textView.textLayout = layout
        
        // Set text frame position (will be updated in applyLayout with correct padding)
        textView.textFrameLeft = 0f
        textView.textFrameTop = 0f
        
        // CRITICAL: When shadow tree changes, mark node dirty to trigger re-measurement
        // This matches React Native's flat renderer notifyChanged behavior
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
        // This matches React Native's flat renderer which updates layout in collectState
        // CRITICAL: Always use shadow node's collected text (matches React Native's flat renderer)
        val textView = view as? DCFTextView ?: return
        
        // Get shadow node to retrieve text and styling
        // CRITICAL: Text components always use DCFVirtualTextShadowNode (created in YogaShadowTree.createNode)
        val shadowNode = nodeId?.let { id ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(id.toIntOrNull() ?: 0)
        } as? com.dotcorr.dcflight.components.text.DCFVirtualTextShadowNode
        
        if (shadowNode == null) {
            // Fallback to props if shadow node not available
            val props = getStoredProps(view)
            updateTextView(textView, props)
            return
        }
        
        // CRITICAL: Always get collected text from shadow node (includes text from children with spans)
        // This matches React Native's flat renderer RCTText.collectState which uses getText()
        // When shadow tree changes, getText() will return updated text automatically
        val spannableText = shadowNode.getText()
        
        if (spannableText.isEmpty()) {
            textView.textLayout = null
            return
        }
        
        // Get props for styling
        val props = getStoredProps(view)
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        
        // Create paint for layout (spans are already applied to spannableText)
        // CRITICAL: Use shadow node's font size (matches React Native's flat renderer)
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        val fontSize = shadowNode.getFontSize().toFloat()
        paint.textSize = fontSize
        
        // Apply letter spacing if specified (matches React Native's flat renderer)
        val letterSpacing = shadowNode.letterSpacing
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP && !letterSpacing.isNaN() && letterSpacing != 0f) {
            paint.letterSpacing = letterSpacing / fontSize
        }
        
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        // CRITICAL: Get padding from shadow node to calculate text frame (matches React Native)
        // React Native's flat renderer: left += getPadding(Spacing.LEFT); top += getPadding(Spacing.TOP)
        val padding = shadowNode.paddingAsInsets
        val textFrameLeft = padding.left.toFloat()
        val textFrameTop = padding.top.toFloat()
        val textWidth = (layout.width - padding.left - padding.right).toInt().coerceAtLeast(0)
        
        // Create layout with correct width (accounting for padding) and spannable text
        // Matches React Native's flat renderer createTextLayout exactly
        // CRITICAL: Use collected text with spans (matches React Native's DrawTextLayout)
        val layoutObj = createTextLayout(
            spannableText,
            paint,
            textWidth,
            alignment,
            numberOfLines,
            lineHeight
        )
        
        textView.textLayout = layoutObj
        textView.textFrameLeft = textFrameLeft
        textView.textFrameTop = textFrameTop
        
        // Request layout to update measured dimensions
        textView.requestLayout()
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    /**
     * Create StaticLayout matching React Native's flat renderer createTextLayout exactly
     * React Native uses TextLayoutBuilder, but we use StaticLayout.Builder directly
     */
    private fun createTextLayout(
        text: CharSequence,
        paint: TextPaint,
        maxWidth: Int,
        alignment: Layout.Alignment,
        maxLines: Int,
        lineHeight: Float = 0f
    ): Layout {
        // CRITICAL: Match React Native's flat renderer StaticLayout.Builder configuration EXACTLY
        // React Native flat renderer (RCTText.createTextLayout):
        // - setEllipsize(ellipsize)
        // - setMaxLines(maxLines)
        // - setSingleLine(isSingleLine)
        // - setText(text)
        // - setTextSize(textSize)
        // - setWidth(width, textMeasureMode)
        // - setTextStyle(textStyle)
        // - setTextDirection(TextDirectionHeuristicsCompat.FIRSTSTRONG_LTR)
        // - setIncludeFontPadding(shouldIncludeFontPadding) // true in React Native
        // - setTextSpacingExtra(extraSpacing)
        // - setTextSpacingMultiplier(spacingMultiplier)
        // - setAlignment(textAlignment)
        
        val builder = android.text.StaticLayout.Builder.obtain(text, 0, text.length, paint, maxWidth)
            .setAlignment(alignment)
            .setIncludePad(true) // CRITICAL: Match React Native - shouldIncludeFontPadding = true
        
        // Apply line height if specified
        // React Native flat renderer (RCTText.setLineHeight):
        // - If lineHeight is NaN: spacingMult = 1.0f, spacingAdd = 0.0f
        // - If lineHeight is set: spacingMult = 0.0f, spacingAdd = PixelUtil.toPixelFromSP(lineHeight)
        // This means: setLineSpacing(spacingAdd, spacingMult)
        if (lineHeight > 0) {
            // React Native converts lineHeight using PixelUtil.toPixelFromSP which accounts for font scale
            // For now, treat lineHeight as pixels directly (matches DCFlight's approach)
            val absoluteLineHeight = if (lineHeight < 10) {
                // Treat as multiplier (e.g., 1.6 means 1.6 * fontSize)
                lineHeight * paint.textSize
            } else {
                // Treat as absolute value in pixels
                lineHeight
            }
            // React Native flat renderer: spacingMult = 0.0f, spacingAdd = absoluteLineHeight
            builder.setLineSpacing(absoluteLineHeight, 0f)
        } else {
            // React Native default: spacingMult = 1.0f, spacingAdd = 0.0f
            builder.setLineSpacing(0f, 1f)
        }
        
        if (maxLines > 0) {
            builder.setMaxLines(maxLines)
            builder.setEllipsize(TextUtils.TruncateAt.END)
        }
        
        // Apply text break strategy (available since API 23, matches React Native)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            builder.setBreakStrategy(android.text.Layout.BREAK_STRATEGY_HIGH_QUALITY)
            builder.setHyphenationFrequency(android.text.Layout.HYPHENATION_FREQUENCY_NORMAL)
        }
        
        return builder.build()
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
