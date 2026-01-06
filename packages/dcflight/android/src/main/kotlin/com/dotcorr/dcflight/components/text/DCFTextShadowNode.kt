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
     */
    private fun measureText(
        width: Float,
        widthMode: YogaMeasureMode,
        height: Float,
        heightMode: YogaMeasureMode
    ): Long {
        // Get text with all spans applied
        val spannedText = if (this is DCFVirtualTextShadowNode) {
            (this as DCFVirtualTextShadowNode).getText()
        } else {
            android.text.SpannableStringBuilder(text)
        }
        
        if (spannedText.isEmpty()) {
            val minHeight = if (fontSize > 0) fontSize else 17f
            return YogaMeasureOutput.make(1f, minHeight)
        }
        
        // Create TextPaint with default font size
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
        
        // Calculate available width
        val availableWidth = if (widthMode == YogaMeasureMode.UNDEFINED) {
            Int.MAX_VALUE
        } else {
            // Subtract padding from available width
            val padding = paddingAsInsets
            (width - padding.left - padding.right).toInt().coerceAtLeast(0)
        }
        
        // Build StaticLayout
        val layout = StaticLayout.Builder
            .obtain(spannedText, 0, spannedText.length, paint, availableWidth)
            .setAlignment(android.text.Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(true)
            .setMaxLines(if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE)
            .setEllipsize(if (numberOfLines > 0) android.text.TextUtils.TruncateAt.END else null)
            .build()
        
        return YogaMeasureOutput.make(
            layout.width.toFloat(),
            layout.height.toFloat()
        )
    }
    
    var text: String = ""
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
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

