// AGENT READ THIS FIRST:
// 
// This file MUST work with DCFVirtualTextShadowNode in components.text package
// 
// The flow is:
// 1. Bridge calls createView() with props Map
// 2. DCFTextComponent creates DCFTextView
// 3. Bridge calls viewRegisteredWithShadowTree() - HERE we transfer props to shadow node
// 4. Shadow node's getText() collects text + applies spans
// 5. updateTextView() uses getText() to create StaticLayout
// 6. DCFTextView.onDraw() renders the layout
//
// CRITICAL: Props MUST be transferred to shadow node, otherwise getText() returns empty string

package com.dotcorr.dcflight.components

import android.content.Context
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.text.DCFTextView
import com.dotcorr.dcflight.components.text.DCFVirtualTextShadowNode
import com.dotcorr.dcflight.extensions.applyStyles

class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
        private const val DEFAULT_FONT_SIZE = 17f
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        android.util.Log.d(TAG, "📱 createView called with props: $props")
        
        val textView = DCFTextView(context)
        textView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // Store props for later use
        storeProps(textView, props)
        
        // NOTE: Don't call updateTextView here - shadow node doesn't exist yet
        // It will be called after viewRegisteredWithShadowTree
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        textView.applyStyles(nonNullProps)
        
        return textView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        android.util.Log.d(TAG, "🔄 updateView called with props: $props")
        
        val textView = view as? DCFTextView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(textView, mergedProps)
        
        // CRITICAL: Update shadow node props FIRST
        updateShadowNodeProps(mergedProps)
        
        // Then update the view
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        updateTextView(textView, nonNullProps)
        textView.applyStyles(nonNullProps)
        
        return true
    }
    
    /**
     * CRITICAL: Transfer props to shadow node
     * This is the KEY function that makes text work
     */
    private fun updateShadowNodeProps(props: Map<String, Any?>) {
        if (nodeId == null) {
            android.util.Log.w(TAG, "⚠️ updateShadowNodeProps: nodeId is NULL")
            return
        }
        
        val viewIdInt = nodeId?.toIntOrNull()
        if (viewIdInt == null) {
            android.util.Log.w(TAG, "⚠️ updateShadowNodeProps: Could not parse nodeId=$nodeId")
            return
        }
        
        android.util.Log.d(TAG, "🔍 Getting shadow node for viewId=$viewIdInt")
        
        val shadowNode = com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(viewIdInt) as? DCFVirtualTextShadowNode
        
        if (shadowNode == null) {
            android.util.Log.w(TAG, "⚠️ Shadow node is NULL for viewId=$viewIdInt")
            return
        }
        
        android.util.Log.d(TAG, "✅ Found shadow node for viewId=$viewIdInt")
        
        // Transfer content prop to shadow node's text property
        val content = props["content"]?.toString() ?: ""
        android.util.Log.d(TAG, "📝 Transferring content='$content' to shadow node")
        
        if (shadowNode.text != content) {
            shadowNode.text = content
            android.util.Log.d(TAG, "✅ Text set on shadow node, shadow node text is now='${shadowNode.text}'")
        }
        
        // Transfer styling props
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
        if (shadowNode.fontSize != fontSize) {
            shadowNode.fontSize = fontSize
            android.util.Log.d(TAG, "✅ fontSize set to $fontSize")
        }
        
        val fontWeight = props["fontWeight"]?.toString()
        if (shadowNode.fontWeight != fontWeight) {
            shadowNode.fontWeight = fontWeight
        }
        
        val fontFamily = props["fontFamily"]?.toString()
        if (shadowNode.fontFamily != fontFamily) {
            shadowNode.fontFamily = fontFamily
        }
        
        val letterSpacing = (props["letterSpacing"] as? Number)?.toFloat() ?: 0f
        if (shadowNode.letterSpacing != letterSpacing) {
            shadowNode.letterSpacing = letterSpacing
        }
        
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        if (shadowNode.lineHeight != lineHeight) {
            shadowNode.lineHeight = lineHeight
        }
        
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        if (shadowNode.numberOfLines != numberOfLines) {
            shadowNode.numberOfLines = numberOfLines
        }
        
        val textAlign = props["textAlign"]?.toString() ?: "start"
        if (shadowNode.textAlign != textAlign) {
            shadowNode.textAlign = textAlign
        }
        
        // Transfer color if present
        val primaryColor = props["primaryColor"]
        if (primaryColor is Number) {
            shadowNode.setTextColor(primaryColor.toDouble())
        } else {
            // Also check textColor prop
            val textColor = props["textColor"]
            if (textColor is Number) {
                shadowNode.setTextColor(textColor.toDouble())
            }
        }
        
        android.util.Log.d(TAG, "✅ All props transferred to shadow node")
    }
    
    private fun updateTextView(textView: DCFTextView, props: Map<String, Any?>) {
        android.util.Log.d(TAG, "🎨 updateTextView called")
        
        val shadowNode = nodeId?.toIntOrNull()?.let { viewId ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(viewId)
        } as? DCFVirtualTextShadowNode
        
        // Get text from shadow node (includes all spans)
        val text: CharSequence = if (shadowNode != null) {
            val collectedText = shadowNode.getText()
            android.util.Log.d(TAG, "📖 Got text from shadow node: '$collectedText' (length=${collectedText.length})")
            collectedText
        } else {
            val fallbackText = props["content"]?.toString() ?: ""
            android.util.Log.w(TAG, "⚠️ Shadow node NULL, using fallback text: '$fallbackText'")
            fallbackText
        }
        
        if (text.isEmpty()) {
            android.util.Log.w(TAG, "⚠️ Text is empty, setting textLayout to null")
            textView.textLayout = null
            return
        }
        
        // Get font size
        // CRITICAL: Use fontSize property (logical points) and convert to pixels
        // This matches applyLayout and measureText which also use fontSize property
        val fontSizePixels = if (shadowNode != null) {
            val fontSizeLogicalPoints = shadowNode.fontSize
            val displayMetrics = textView.context.resources.displayMetrics
            if (fontSizeLogicalPoints > 0) {
                android.util.TypedValue.applyDimension(
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    fontSizeLogicalPoints,
                    displayMetrics
                )
            } else {
                17f * displayMetrics.scaledDensity
            }
        } else {
            val fontSizeSp = (props["fontSize"] as? Number)?.toFloat() ?: DEFAULT_FONT_SIZE
            val displayMetrics = textView.context.resources.displayMetrics
            android.util.TypedValue.applyDimension(
                android.util.TypedValue.COMPLEX_UNIT_SP,
                fontSizeSp,
                displayMetrics
            )
        }
        
        android.util.Log.d(TAG, "🔤 Font size: ${fontSizePixels}px")
        
        // Create paint
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        paint.textSize = fontSizePixels
        paint.color = android.graphics.Color.BLACK // Ensure visible
        
        // Apply letter spacing
        val letterSpacing = if (shadowNode != null) {
            shadowNode.letterSpacing
        } else {
            (props["letterSpacing"] as? Number)?.toFloat() ?: 0f
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP && !letterSpacing.isNaN() && letterSpacing != 0f) {
            paint.letterSpacing = letterSpacing / fontSizePixels
        }
        
        // Get alignment
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        // Get other props
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        
        // Calculate max width
        val maxWidth = if (textView.width > 0) {
            textView.width
        } else {
            10000
        }
        
        android.util.Log.d(TAG, "📏 Creating layout with maxWidth=$maxWidth, alignment=$alignment")
        
        // Create layout
        val layout = createTextLayout(
            text,
            paint,
            maxWidth,
            alignment,
            numberOfLines,
            lineHeight,
            fontSizePixels
        )
        
        android.util.Log.d(TAG, "✅ Layout created: width=${layout.width}, height=${layout.height}, lineCount=${layout.lineCount}")
        
        textView.textLayout = layout
        textView.textFrameLeft = 0f
        textView.textFrameTop = 0f
        
        // Force invalidate to redraw
        textView.invalidate()
    }

    private var nodeId: String? = null

    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        android.util.Log.d(TAG, "🌳 viewRegisteredWithShadowTree called with nodeId=$nodeId")
        
        this.nodeId = nodeId
        view.setTag("nodeId".hashCode(), nodeId)
        
        // CRITICAL: Transfer initial props to shadow node NOW
        val props = getStoredProps(view)
        android.util.Log.d(TAG, "📦 Stored props: $props")
        
        updateShadowNodeProps(props)
        
        // Initial text setup - applyLayout will be called later for final positioning
        val textView = view as? DCFTextView
        if (textView != null) {
            android.util.Log.d(TAG, "📝 Initial updateTextView call from viewRegisteredWithShadowTree")
            updateTextView(textView, props)
        }
    }
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        super.applyLayout(view, layout)
        
        android.util.Log.d(TAG, "📐 applyLayout called: width=${layout.width}, height=${layout.height}")
        
        val textView = view as? DCFTextView ?: return
        
        // CRITICAL: Retrieve nodeId from view tag (component instances may be reused)
        val viewNodeId = nodeId ?: view.getTag("nodeId".hashCode())?.toString()
        val shadowNode = viewNodeId?.toIntOrNull()?.let { viewId ->
            com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(viewId)
        } as? DCFVirtualTextShadowNode
        
        if (shadowNode == null) {
            android.util.Log.w(TAG, "⚠️ Shadow node NULL in applyLayout, nodeId=$viewNodeId")
            val props = getStoredProps(view)
            updateTextView(textView, props)
            return
        }
        
        val spannableText = shadowNode.getText()
        
        if (spannableText.isEmpty()) {
            textView.textLayout = null
            return
        }
        
        val props = getStoredProps(view)
        val textAlign = props["textAlign"]?.toString() ?: "start"
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        
        // CRITICAL: Use fontSize property (logical points) and convert to pixels
        // This matches measureText which also uses fontSize property
        val fontSizeLogicalPoints = shadowNode.fontSize
        val displayMetrics = textView.context.resources.displayMetrics
        val fontSizePixels = if (fontSizeLogicalPoints > 0) {
            android.util.TypedValue.applyDimension(
                android.util.TypedValue.COMPLEX_UNIT_SP,
                fontSizeLogicalPoints,
                displayMetrics
            )
        } else {
            17f * displayMetrics.scaledDensity
        }
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        paint.textSize = fontSizePixels
        paint.color = android.graphics.Color.BLACK
        
        val letterSpacing = shadowNode.letterSpacing
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP && !letterSpacing.isNaN() && letterSpacing != 0f) {
            paint.letterSpacing = letterSpacing / fontSizePixels
        }
        
        // CRITICAL: Account for padding when creating text layout (matches iOS behavior)
        // iOS: let width = self.frame.size.width - (padding.left + padding.right)
        val padding = shadowNode.paddingAsInsets
        var layoutWidth = (layout.width - padding.left - padding.right).toInt().coerceAtLeast(0)
        
        // CRITICAL: If layoutWidth is 0 but we have text, use the view's actual width as fallback
        // This can happen if Yoga calculated 0 width due to parent constraints, but the view
        // might have been laid out with a different size. We need to render the text even if
        // the layout width is 0, otherwise text will be invisible.
        if (layoutWidth == 0 && spannableText.isNotEmpty()) {
            val viewWidth = textView.width
            if (viewWidth > 0) {
                layoutWidth = (viewWidth - padding.left - padding.right).coerceAtLeast(0)
                android.util.Log.w(TAG, "⚠️ Layout width is 0, using view width=$viewWidth (layoutWidth=$layoutWidth)")
            } else {
                // Last resort: use a large width to allow text to measure its natural width
                // This matches iOS behavior where text can measure its natural width even if
                // the constraint is 0
                layoutWidth = Int.MAX_VALUE
                android.util.Log.w(TAG, "⚠️ Layout width and view width are both 0, using Int.MAX_VALUE for text measurement")
            }
        }
        
        // Apply font family and weight to paint
        val fontWeightValue = shadowNode.fontWeight
        val fontFamilyValue = shadowNode.fontFamily
        val typefaceStyle = if (fontWeightValue != null) {
            when (fontWeightValue.lowercase()) {
                "bold", "700", "800", "900" -> android.graphics.Typeface.BOLD
                else -> android.graphics.Typeface.NORMAL
            }
        } else {
            android.graphics.Typeface.NORMAL
        }
        paint.typeface = if (fontFamilyValue != null) {
            android.graphics.Typeface.create(fontFamilyValue, typefaceStyle)
        } else {
            android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, typefaceStyle)
        }
        
        // Apply text color from shadow node's span
        // The spans in spannableText will apply color during drawing, but we need a default for measurement
        val textColorSpan = if (shadowNode is DCFVirtualTextShadowNode) {
            val span = shadowNode.getSpan()
            val colorValue = span.getTextColor()
            if (!java.lang.Double.isNaN(colorValue)) {
                // Convert Double color to Int color (ARGB32 integer stored as Double)
                val colorInt = colorValue.toLong().toInt()
                paint.color = colorInt
            } else {
                // Fallback to black if no color specified
                paint.color = android.graphics.Color.BLACK
            }
        } else {
            // Fallback to black if no color specified
            paint.color = android.graphics.Color.BLACK
        }
        
        val alignment = textAlignToLayoutAlignment(textAlign)
        
        val textLayout = createTextLayout(
            spannableText,
            paint,
            layoutWidth,
            alignment,
            numberOfLines,
            lineHeight,
            fontSizePixels
        )
        
        textView.textLayout = textLayout
        // CRITICAL: Set text frame offsets to padding (matches iOS computedContentInset)
        // Text is drawn at (padding.left, padding.top) relative to view origin
        textView.textFrameLeft = padding.left.toFloat()
        textView.textFrameTop = padding.top.toFloat()
        textView.requestLayout()
        textView.invalidate()
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun createTextLayout(
        text: CharSequence,
        paint: TextPaint,
        maxWidth: Int,
        alignment: Layout.Alignment,
        maxLines: Int,
        lineHeight: Float = 0f,
        fontSizePixels: Float = 17f
    ): StaticLayout {
        val builder = android.text.StaticLayout.Builder.obtain(text, 0, text.length, paint, maxWidth)
            .setAlignment(alignment)
            .setIncludePad(true)
        
        val spacingAdd: Float
        val spacingMult: Float
        
        if (lineHeight > 0) {
            val absoluteLineHeight = if (lineHeight < 10) {
                lineHeight * fontSizePixels
            } else {
                val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
                android.util.TypedValue.applyDimension(
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    lineHeight,
                    displayMetrics
                )
            }
            spacingAdd = absoluteLineHeight
            spacingMult = 0.0f
        } else {
            spacingAdd = 0.0f
            spacingMult = 1.0f
        }
        
        builder.setLineSpacing(spacingAdd, spacingMult)
        
        if (maxLines > 0) {
            builder.setMaxLines(maxLines)
            builder.setEllipsize(TextUtils.TruncateAt.END)
        }
        
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