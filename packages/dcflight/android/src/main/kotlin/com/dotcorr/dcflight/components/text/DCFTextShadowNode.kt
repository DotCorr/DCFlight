package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import android.text.TextPaint
 import android.text.StaticLayout
import com.dotcorr.dcflight.layout.DCFShadowNode
import com.facebook.yoga.*

abstract class DCFTextShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    private var mTextBegin: Int = 0
    private var mTextEnd: Int = 0
    
    init {
        // Set up custom measure function for text
        yogaNode.setMeasureFunction(createTextMeasureFunction())
        android.util.Log.d("DCFTextShadowNode", "✅ Measure function set for viewId=$viewId, isMeasureDefined=${yogaNode.isMeasureDefined}")
    }
    
    /**
     * Create measure function for text nodes
     */
    private fun createTextMeasureFunction(): YogaMeasureFunction {
        return YogaMeasureFunction { node, width, widthMode, height, heightMode ->
            measureText(width, widthMode, height, heightMode)
         }
     }
     
     /**
     * Custom measure function for text nodes
     * Uses getText() from DCFVirtualTextShadowNode which includes all spans
     * 
     * CRITICAL: Yoga passes available width (after padding) to measure function
     * We should NOT subtract padding again - this matches iOS behavior exactly
     */
    private fun measureText(
        width: Float,
        widthMode: YogaMeasureMode,
        height: Float,
        heightMode: YogaMeasureMode
    ): Long {
        android.util.Log.d("DCFTextShadowNode", "📏 measureText called: viewId=$viewId, width=$width, widthMode=$widthMode, height=$height, heightMode=$heightMode")
        
        // Get text with all spans applied
        val spannedText = if (this is DCFVirtualTextShadowNode) {
            (this as DCFVirtualTextShadowNode).getText()
        } else {
            android.text.SpannableStringBuilder(text)
        }
        
        android.util.Log.d("DCFTextShadowNode", "📝 Text content: '${spannedText}' (length=${spannedText.length})")
        
        if (spannedText.isEmpty()) {
            val minHeight = if (fontSize > 0) {
                // Convert from logical points (SP) to pixels
                val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
                android.util.TypedValue.applyDimension(
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    fontSize,
                    displayMetrics
                )
            } else {
                17f * android.content.res.Resources.getSystem().displayMetrics.scaledDensity
            }
            android.util.Log.d("DCFTextShadowNode", "⚠️ Empty text, returning min size: 1x$minHeight")
            return YogaMeasureOutput.make(1f, minHeight)
        }
        
        // Create TextPaint with font properties
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        val fontSizePixels = if (fontSize > 0) {
            // Convert from logical points (SP) to pixels
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            android.util.TypedValue.applyDimension(
                android.util.TypedValue.COMPLEX_UNIT_SP,
                fontSize,
                displayMetrics
            )
        } else {
            17f * android.content.res.Resources.getSystem().displayMetrics.scaledDensity
        }
        paint.textSize = fontSizePixels
        
        // Apply font family and weight to paint (matches iOS behavior)
        val fontWeightValue = fontWeight
        val fontFamilyValue = fontFamily
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
        
        // Apply letter spacing if specified (matches iOS behavior)
        val letterSpacingValue = letterSpacing
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP && 
            !letterSpacingValue.isNaN() && letterSpacingValue != 0f) {
            paint.letterSpacing = letterSpacingValue / fontSizePixels
        }
        
        // CRITICAL: Yoga passes available width (after padding) to measure function
        // We should NOT subtract padding again - this matches iOS behavior exactly
        // iOS: let availableWidth: CGFloat = widthMode == .undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(width)
        // Match iOS exactly - use width directly when not undefined
        val availableWidth = if (widthMode == YogaMeasureMode.UNDEFINED) {
            // For UNDEFINED, use a large width to allow text to measure its natural size
            Int.MAX_VALUE
        } else {
            // Use width directly - Yoga already subtracted padding
            // If width is 0, use 1 for measurement to get height
            width.toInt().coerceAtLeast(1)
        }
        
        android.util.Log.d("DCFTextShadowNode", "📐 Creating layout with availableWidth=$availableWidth (constraint width=$width, widthMode=$widthMode), fontSize=$fontSizePixels")
        
        // Get text alignment
        val alignment = when (textAlign.lowercase()) {
            "center" -> android.text.Layout.Alignment.ALIGN_CENTER
            "right", "end" -> android.text.Layout.Alignment.ALIGN_OPPOSITE
            "left", "start" -> android.text.Layout.Alignment.ALIGN_NORMAL
            "justify" -> android.text.Layout.Alignment.ALIGN_NORMAL
            else -> android.text.Layout.Alignment.ALIGN_NORMAL
        }
        
        // Build StaticLayout with line height support
        // CRITICAL: Match createTextLayout in DCFTextComponent exactly
        val builder = StaticLayout.Builder
            .obtain(spannedText, 0, spannedText.length, paint, availableWidth)
            .setAlignment(alignment)
            .setIncludePad(true)
            .setMaxLines(if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE)
            .setEllipsize(if (numberOfLines > 0) android.text.TextUtils.TruncateAt.END else null)
        
        // Apply line height if specified (matches iOS behavior and DCFTextComponent.createTextLayout)
        val spacingAdd: Float
        val spacingMult: Float
        if (lineHeight > 0) {
            val absoluteLineHeight = if (lineHeight < 10) {
                // Treat as multiplier (matches DCFTextComponent.createTextLayout)
                lineHeight * fontSizePixels
            } else {
                // Treat as absolute value
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
        
        val layout = builder.build()
        
        // CRITICAL: Calculate actual used width (longest line width) instead of container width
        // iOS uses layoutManager.usedRect(for: textContainer).size.width which gives the actual bounding box
        // StaticLayout.width returns the container width, not the actual text width
        // We need to find the longest line's width to match iOS behavior
        val actualUsedWidth = if (layout.lineCount > 0) {
            var maxLineWidth = 0f
            for (i in 0 until layout.lineCount) {
                val lineWidth = layout.getLineWidth(i)
                if (lineWidth > maxLineWidth) {
                    maxLineWidth = lineWidth
                }
            }
            maxLineWidth
        } else {
            0f
        }
        
        android.util.Log.d("DCFTextShadowNode", "✅ Layout created: containerWidth=${layout.width}, actualUsedWidth=$actualUsedWidth, height=${layout.height}, lineCount=${layout.lineCount}, availableWidth=$availableWidth")
        
        // Round up to pixel boundaries (matches iOS RCTCeilPixelValue)
        val scale = android.content.res.Resources.getSystem().displayMetrics.density
        val roundedWidth = kotlin.math.ceil(actualUsedWidth * scale) / scale
        val roundedHeight = kotlin.math.ceil(layout.height * scale) / scale
        
        // Return measured size naturally - let Yoga handle constraints
        val finalWidth = if (widthMode == YogaMeasureMode.EXACTLY && width <= 0) {
            // If constraint is exactly 0, return 0 to respect the constraint
            0f
        } else {
            // Return the actual measured width
            roundedWidth.toFloat()
        }
        
        // For height, always return the measured height (matches iOS behavior)
        // But ensure it's at least the font size if text is not empty
        val finalHeight = if (roundedHeight <= 0) {
            // If height is 0, use font size as minimum (matches iOS fallback)
            val minHeight = if (fontSize > 0) {
                val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
                android.util.TypedValue.applyDimension(
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    fontSize,
                    displayMetrics
                )
             } else {
                17f * android.content.res.Resources.getSystem().displayMetrics.scaledDensity
            }
            android.util.Log.w("DCFTextShadowNode", "⚠️ Layout height is 0, using minimum height of $minHeight")
            minHeight
        } else {
            roundedHeight.toFloat()
        }
        
        android.util.Log.d("DCFTextShadowNode", "📊 Returning measure output: width=$finalWidth (measured=$roundedWidth), height=$finalHeight (widthMode=$widthMode, constraintWidth=$width)")
        
        // Return just the text size (no padding added)
        // Yoga automatically accounts for padding when calculating the final frame
        return YogaMeasureOutput.make(finalWidth, finalHeight)
    }
    
    var text: String = ""
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
                // CRITICAL: Mark Yoga node as dirty so measure function is called
                // This ensures Yoga will re-measure the text when it changes
                if (yogaNode.isMeasureDefined && yogaNode.childCount == 0) {
                    yogaNode.markLayoutSeen()
                    yogaNode.dirty()
                    android.util.Log.d("DCFTextShadowNode", "✅ Marked Yoga node dirty for viewId=$viewId after text change")
                }
            }
        }
    
    open var fontSize: Float = 17f // Match iOS default (iOS uses 17, React Native uses 14)
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var fontWeight: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var fontFamily: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var letterSpacing: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var lineHeight: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var numberOfLines: Int = 0
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var textAlign: String = "start"
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    /**
     * Propagates changes up to top-level text node without dirtying current node.
     * Matches React Native's FlatTextShadowNode.notifyChanged exactly.
     * When shouldRemeasure is true, marks the top-level text node's Yoga node as dirty.
     */
    protected fun notifyChanged(shouldRemeasure: Boolean) {
        val parent = superview
        if (parent is DCFTextShadowNode) {
            // Propagate up the tree (matches React Native)
            parent.notifyChanged(shouldRemeasure)
        } else {
            // We've reached a non-text parent - find the top-level text node
            // The top-level text node is the one with a measure function (layout/DCFTextShadowNode)
            // Find it by walking up the tree or by checking if this node has a measure function
            var currentNode: com.dotcorr.dcflight.layout.DCFShadowNode? = this
            while (currentNode != null) {
                // Check if this node has a measure function (it's the top-level text node)
                if (currentNode.yogaNode.isMeasureDefined) {
                    // This is the top-level text node - mark it dirty if remeasurement is needed
                    // CRITICAL: Only mark as dirty if it's a leaf node (no children)
                    // Yoga only allows calling dirty() on leaf nodes with custom measure functions
                    if (shouldRemeasure && currentNode.yogaNode.childCount == 0) {
                        currentNode.yogaNode.markLayoutSeen() // Reset layout seen flag
                        currentNode.yogaNode.dirty() // Mark as dirty to force re-measure
                    }
                    break
                }
                currentNode = currentNode.superview
            }
        }
    }
    
    final fun collectText(builder: SpannableStringBuilder) {
        mTextBegin = builder.length
        performCollectText(builder)
        mTextEnd = builder.length
    }
    
    protected open fun shouldAllowEmptySpans(): Boolean {
        return false
    }
    
    protected open fun isEditable(): Boolean {
        return false
    }
    
    final fun applySpans(builder: SpannableStringBuilder, isEditable: Boolean) {
        if (mTextBegin != mTextEnd || shouldAllowEmptySpans()) {
            performApplySpans(builder, mTextBegin, mTextEnd, isEditable)
        }
    }
    
    protected abstract fun performCollectText(builder: SpannableStringBuilder)
    protected abstract fun performApplySpans(
        builder: SpannableStringBuilder,
        begin: Int,
        end: Int,
        isEditable: Boolean
    )
    
    open fun performCollectAttachDetachListeners() {
    }
}

