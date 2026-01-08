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
import com.dotcorr.dcflight.utils.ColorUtilities

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
        // CRITICAL: Always set fontSize, even if it matches the current value
        // This ensures the span is updated correctly, especially on first initialization
        // The property setter will handle the conversion and span update
        shadowNode.fontSize = fontSize
        android.util.Log.d(TAG, "✅ fontSize set to $fontSize (current shadowNode.fontSize=${shadowNode.fontSize})")
        
        // Transfer fontWeight - property setter handles span update
        val fontWeight = props["fontWeight"]?.toString()
        shadowNode.fontWeight = fontWeight
        
        // Transfer fontFamily - property setter handles span update
        val fontFamily = props["fontFamily"]?.toString()
        shadowNode.fontFamily = fontFamily
        
        // Transfer letterSpacing - property setter handles span update
        val letterSpacing = (props["letterSpacing"] as? Number)?.toFloat() ?: 0f
        shadowNode.letterSpacing = letterSpacing
        
        // Transfer lineHeight - property setter handles span update
        val lineHeight = (props["lineHeight"] as? Number)?.toFloat() ?: 0f
        shadowNode.lineHeight = lineHeight
        
        // Transfer numberOfLines - property setter handles span update
        val numberOfLines = (props["numberOfLines"] as? Number)?.toInt() ?: 0
        shadowNode.numberOfLines = numberOfLines
        
        // Transfer textAlign - property setter handles span update
        val textAlign = props["textAlign"]?.toString() ?: "start"
        shadowNode.textAlign = textAlign
        
        // Transfer color if present - use ColorUtilities like iOS does
        // iOS: ColorUtilities.getColor(explicitColor: "textColor", semanticColor: "primaryColor", from: props)
        val colorInt = ColorUtilities.getColor(
            explicitColor = "textColor",
            semanticColor = "primaryColor",
            props = props
        )
        if (colorInt != null) {
            // Convert Int color to Double (ARGB32 integer stored as Double, matching iOS behavior)
            val colorDouble = colorInt.toLong().toDouble()
            shadowNode.setTextColor(colorDouble)
            android.util.Log.d(TAG, "✅ Text color set: ${ColorUtilities.hexString(colorInt)}")
        } else {
            android.util.Log.d(TAG, "⚠️ No text color found in props")
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
        // CRITICAL: Try multiple sources in order of preference:
        // 1. Actual view width (if laid out) - most accurate
        // 2. Shadow node's Yoga layout width (if calculated) - accurate after layout
        // 3. Parent's width constraint (if available) - reasonable estimate
        // 4. Screen width as last resort (prevents overflow on small devices, much better than 10000)
        val maxWidth: Int = when {
            textView.width > 0 -> {
                // View has been laid out - use actual width
                textView.width
            }
            shadowNode != null -> {
                // Try to get width from Yoga layout (may be 0 if not laid out yet)
                val yogaWidth = shadowNode.yogaNode.layoutWidth
                if (yogaWidth > 0) {
                    // Account for padding
                    val padding = shadowNode.paddingAsInsets
                    (yogaWidth - padding.left - padding.right).toInt().coerceAtLeast(1)
                } else {
                    // Yoga layout not calculated yet - try parent constraint
                    val parentNode = shadowNode.yogaNode.parent
                    if (parentNode != null && parentNode.layoutWidth > 0) {
                        // Use parent's width as constraint (account for parent padding)
                        // CRITICAL: layoutWidth is Float, so convert padding to Float for calculation
                        val parentPadding = shadowNode.superview?.paddingAsInsets
                        val parentPaddingLeft = parentPadding?.left?.toFloat() ?: 0f
                        val parentPaddingRight = parentPadding?.right?.toFloat() ?: 0f
                        (parentNode.layoutWidth - parentPaddingLeft - parentPaddingRight).toInt().coerceAtLeast(1)
                    } else {
                        // Last resort: use screen width (prevents overflow, much better than 10000)
                        val displayMetrics = textView.context.resources.displayMetrics
                        displayMetrics.widthPixels
                    }
                }
            }
            else -> {
                // No shadow node - use screen width as reasonable fallback
                val displayMetrics = textView.context.resources.displayMetrics
                displayMetrics.widthPixels
            }
        }
        
        android.util.Log.d(TAG, "📏 Creating layout with maxWidth=$maxWidth (viewWidth=${textView.width}, yogaWidth=${shadowNode?.yogaNode?.layoutWidth}), alignment=$alignment")
        
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
        // CRITICAL: Use Yoga's calculated width directly - don't override it with fallbacks
        // If Yoga calculated 0 width, that's the constraint we must respect to prevent overflow
        val padding = shadowNode.paddingAsInsets
        var layoutWidth = (layout.width - padding.left - padding.right).toInt().coerceAtLeast(0)
        
        // CRITICAL: If layoutWidth is 0, use at least 1 for StaticLayout creation (it requires > 0)
        // But the text will be clipped/not visible, which is correct when Yoga constrains to 0
        // This prevents overflow and respects Yoga's layout constraints
        if (layoutWidth == 0) {
            layoutWidth = 1 // Minimum width for StaticLayout, but text will be clipped
            android.util.Log.d(TAG, "📏 Layout width is 0, using 1 for StaticLayout (text will be clipped)")
        }
        
        // Apply font family and weight to paint
        val fontWeightValue = shadowNode.fontWeight
        val fontFamilyValue = shadowNode.fontFamily
        
        // Use numeric font weights (API 26+) to match iOS behavior
        // iOS medium weight (500) should render as medium, not normal
        paint.typeface = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val weight = fontWeightToNumericWeight(fontWeightValue)
            // First create base Typeface from font family string, then apply weight
            val baseTypeface = if (fontFamilyValue != null) {
                android.graphics.Typeface.create(fontFamilyValue, android.graphics.Typeface.NORMAL)
            } else {
                android.graphics.Typeface.DEFAULT
            }
            android.graphics.Typeface.create(baseTypeface, weight, false)
        } else {
            // Fallback for older Android versions
            val typefaceStyle = if (fontWeightValue != null) {
                when (fontWeightValue.lowercase()) {
                    "bold", "700", "800", "900" -> android.graphics.Typeface.BOLD
                    else -> android.graphics.Typeface.NORMAL
                }
            } else {
                android.graphics.Typeface.NORMAL
            }
            if (fontFamilyValue != null) {
                android.graphics.Typeface.create(fontFamilyValue, typefaceStyle)
            } else {
                android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, typefaceStyle)
            }
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
        
        // DEBUG: Log parent container state to diagnose background expansion issue
        val parent = textView.parent
        if (parent is android.view.View) {
            val parentViewId = parent.getTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY) as? Int
            val parentNodeId = parent.getTag("nodeId".hashCode())?.toString()
            android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] applyLayout: textView viewId=$viewNodeId, layout=(${layout.width}x${layout.height})")
            android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] Parent: type=${parent.javaClass.simpleName}, viewId=$parentViewId, nodeId=$parentNodeId")
            android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] Parent size: width=${parent.width}, height=${parent.height}, measuredWidth=${parent.measuredWidth}, measuredHeight=${parent.measuredHeight}")
            android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] TextView size: width=${textView.width}, height=${textView.height}, measuredWidth=${textView.measuredWidth}, measuredHeight=${textView.measuredHeight}")
            
            // Check if parent has a shadow node
            if (parentNodeId != null) {
                val parentShadowNode = parentNodeId.toIntOrNull()?.let { viewId ->
                    com.dotcorr.dcflight.layout.YogaShadowTree.shared.getShadowNode(viewId)
                }
                if (parentShadowNode != null) {
                    android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] Parent Yoga: width=${parentShadowNode.yogaNode.layoutWidth}, height=${parentShadowNode.yogaNode.layoutHeight}")
                    android.util.Log.d(TAG, "🔍 [CONTAINER DEBUG] Parent frame: ${parentShadowNode.frame}")
                } else {
                    android.util.Log.w(TAG, "⚠️ [CONTAINER DEBUG] Parent shadow node NOT found for nodeId=$parentNodeId")
                }
            }
        } else {
            android.util.Log.w(TAG, "⚠️ [CONTAINER DEBUG] Parent is not a View, type=${parent?.javaClass?.simpleName}")
        }
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
            builder.setHyphenationFrequency(android.text.Layout.HYPHENATION_FREQUENCY_NONE)
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
    
    /**
     * Convert font weight string to numeric weight (0-1000)
     * Matches iOS UIFont.Weight mapping
     */
    private fun fontWeightToNumericWeight(weight: String?): Int {
        if (weight == null) return 400 // Regular/default
        
        return when (weight.lowercase()) {
            "thin", "100" -> 100
            "ultralight", "200" -> 200
            "light", "300" -> 300
            "regular", "normal", "400" -> 400
            "medium", "500" -> 500 // CRITICAL: Medium should be 500, not 400 (normal)
            "semibold", "600" -> 600
            "bold", "700" -> 700
            "heavy", "800" -> 800
            "black", "900" -> 900
            else -> 400 // Default to regular
        }
    }
}