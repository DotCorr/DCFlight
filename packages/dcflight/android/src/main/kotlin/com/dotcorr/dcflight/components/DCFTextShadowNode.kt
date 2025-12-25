/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.Rect
import android.text.TextPaint
import android.text.StaticLayout
import android.text.TextUtils
import android.util.Log
import com.facebook.yoga.*
import kotlin.math.ceil
import kotlin.math.max

/**
 * DCFTextShadowNode - Specialized shadow node for Text components
 * 
 * Text components require custom measurement logic because:
 * 1. Text size depends on content and available width (wrapping behavior)
 * 2. Padding must be subtracted from available width before measurement
 * 3. Accurate measurement requires TextPaint/StaticLayout for proper
 *    text layout, line breaks, and truncation
 * 4. Text properties (font, line height, letter spacing) affect measurement
 * 
 * This is the Android equivalent of iOS DCFTextShadowView - MUST match 1:1
 */
open class DCFTextShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    companion object {
        private const val TAG = "DCFTextShadowNode"
        private const val AUTO_SIZE_GRANULARITY = 0.001f
        private const val AUTO_SIZE_WIDTH_ERROR_MARGIN = 0.01f
        private const val AUTO_SIZE_HEIGHT_ERROR_MARGIN = 0.01f
    }
    
    // MARK: - Properties
    
    // Text properties
    var text: String = ""
    var fontSize: Float = Float.NaN
    var fontWeight: String? = null
    var fontFamily: String? = null
    var letterSpacing: Float = Float.NaN
    var lineHeight: Float = 0f
    var numberOfLines: Int = 0
    var textAlign: String = "start"
    var textColor: Int? = null
    var adjustsFontSizeToFit: Boolean = false
    var minimumFontScale: Float = 0f
    
    // Cached text storage for measurement
    private var cachedTextPaint: TextPaint? = null
    private var cachedTextPaintWidth: Float = -1f
    private var cachedTextPaintWidthMode: YogaMeasureMode? = null
    private var cachedAttributedString: String? = null
    
    var computedTextLayout: StaticLayout? = null
    var computedTextFrame: Rect = Rect(0, 0, 0, 0)
    var computedContentInset: android.graphics.Rect = android.graphics.Rect(0, 0, 0, 0)
    
    // MARK: - Initialization
    
    init {
        // Set up custom measure function for text
        yogaNode.setMeasureFunction(createTextMeasureFunction())
    }
    
    // MARK: - Text Measurement
    
    /**
     * Create measure function for text nodes
     */
    private fun createTextMeasureFunction(): YogaMeasureFunction {
        return YogaMeasureFunction { node, width, widthMode, height, heightMode ->
            measureText(node, width, widthMode, height, heightMode)
        }
    }
    
    /**
     * Custom measure function for text nodes
     * Matches iOS approach: measurement returns text size only, padding handled separately
     */
    private fun measureText(
        node: YogaNode,
        width: Float,
        widthMode: YogaMeasureMode,
        height: Float,
        heightMode: YogaMeasureMode
    ): Long {
        // Match iOS approach: Yoga passes available width (after padding) to measure function
        // When widthMode is undefined, use Float.MAX_VALUE for unlimited width
        val availableWidth: Float = if (widthMode == YogaMeasureMode.UNDEFINED) {
            Float.MAX_VALUE
        } else {
            width
        }
        
        Log.d(TAG, "🔍 measureText: viewId=$viewId, text='$text' (length=${text.length}), availableWidth=$availableWidth, widthMode=$widthMode")
        
        val textPaint = buildTextPaintForWidth(availableWidth, widthMode)
        
        if (text.isEmpty()) {
            // Fallback: return minimum size based on font
            val minHeight = if (!fontSize.isNaN()) max(1f, fontSize) else 17f
            Log.w(TAG, "⚠️ measureText: Text is empty for viewId=$viewId, returning min size: 1x$minHeight")
            return YogaMeasureOutput.make(1f, minHeight)
        }
        
        // Calculate the actual text size using StaticLayout
        val layout = buildTextLayout(textPaint, availableWidth)
        
        // Get computed size from layout
        val computedWidth = layout.width.toFloat()
        val computedHeight = layout.height.toFloat()
        
        // Round up to pixel boundaries (match iOS: RCTCeilPixelValue)
        val scale = android.content.res.Resources.getSystem().displayMetrics.density
        val roundedWidth = ceil(computedWidth * scale) / scale
        val roundedHeight = ceil(computedHeight * scale) / scale
        
        // Handle negative letter spacing (match iOS)
        var finalWidth = roundedWidth
        if (!letterSpacing.isNaN() && letterSpacing < 0) {
            finalWidth -= kotlin.math.abs(letterSpacing)
        }
        
        // Match iOS approach: return just the text size (no padding added)
        // Yoga automatically accounts for padding when calculating the final frame
        Log.d(TAG, "✅ measureText: viewId=$viewId, computed size: ${finalWidth}x${roundedHeight}")
        return YogaMeasureOutput.make(finalWidth, roundedHeight)
    }
    
    /**
     * Build text paint for a given width constraint
     * Caches results to avoid recomputation
     */
    private fun buildTextPaintForWidth(width: Float, widthMode: YogaMeasureMode): TextPaint {
        // Check cache
        if (cachedTextPaint != null &&
            cachedTextPaintWidth == width &&
            cachedTextPaintWidthMode == widthMode &&
            cachedAttributedString == text) {
            return cachedTextPaint!!
        }
        
        // Create new TextPaint
        val paint = TextPaint().apply {
            isAntiAlias = true
            textSize = if (!fontSize.isNaN()) fontSize else 17f
            
            // TODO: Apply font family and weight when font system is implemented
            // For now, use default system font
            
            // Apply letter spacing if specified
            if (!letterSpacing.isNaN()) {
                letterSpacing = this@DCFTextShadowNode.letterSpacing
            }
            
            // Apply text color - default to black if not specified (matches iOS)
            color = textColor ?: android.graphics.Color.BLACK
        }
        
        // Cache the result
        cachedTextPaint = paint
        cachedTextPaintWidth = width
        cachedTextPaintWidthMode = widthMode
        cachedAttributedString = text
        
        return paint
    }
    
    /**
     * Build StaticLayout for text measurement
     * CRITICAL: Match React Native's ReactTextShadowNode.buildTextLayout exactly
     */
    private fun buildTextLayout(paint: TextPaint, availableWidth: Float): StaticLayout {
        val width = if (availableWidth == Float.MAX_VALUE) {
            Int.MAX_VALUE
        } else {
            availableWidth.toInt()
        }
        
        // CRITICAL: React Native uses ALIGN_NORMAL for measurement, alignment is handled separately
        // React Native: .setAlignment(Layout.Alignment.ALIGN_NORMAL)
        val alignment = when (textAlign.lowercase()) {
            "center" -> android.text.Layout.Alignment.ALIGN_CENTER
            "right", "end" -> android.text.Layout.Alignment.ALIGN_OPPOSITE
            "left", "start" -> android.text.Layout.Alignment.ALIGN_NORMAL
            else -> android.text.Layout.Alignment.ALIGN_NORMAL
        }
        
        val ellipsize = if (numberOfLines > 0) {
            TextUtils.TruncateAt.END
        } else {
            null
        }
        
        // CRITICAL: Match React Native's StaticLayout.Builder configuration EXACTLY
        // React Native uses: .setLineSpacing(0.f, 1.f) - NOT (lineHeight - textSize, 1f)
        // Line height is handled through CustomLineHeightSpan or spacingAdd/spacingMult, not setLineSpacing
        // React Native: .setIncludePad(true) - essential for proper text positioning
        return StaticLayout.Builder
            .obtain(text, 0, text.length, paint, width)
            .setAlignment(alignment)
            .setLineSpacing(0f, 1f) // CRITICAL: Match React Native - use 0f, 1f not lineHeight calculation
            .setIncludePad(true) // CRITICAL: Match React Native - includes extra padding for proper text positioning
            .setEllipsize(ellipsize)
            .setMaxLines(if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE)
            .build()
    }
    
    /**
     * Override applyLayoutNode to build textLayout and calculate textFrame
     * Matches iOS DCFTextShadowView.applyLayoutNode exactly
     */
    override fun applyLayoutNode(
        node: YogaNode,
        viewsWithNewFrame: MutableSet<DCFShadowNode>,
        absolutePosition: android.graphics.PointF
    ) {
        // Call super to handle frame calculation
        // CRITICAL: Match iOS behavior exactly - don't clamp negative positions
        // iOS DCFTextShadowView.applyLayoutNode does NOT clamp - it trusts Yoga's calculations
        // Negative positions are valid and may be intentional (e.g., text overflow, centering)
        // The frame is already set correctly by super.applyLayoutNode() which matches iOS exactly
        super.applyLayoutNode(node, viewsWithNewFrame, absolutePosition)
        
        // Build text layout and calculate text frame for rendering
        // Use frame width minus padding (matches iOS approach)
        try {
            val padding = paddingAsInsets
            val frameWidth = frame.width()
            val availableWidth = frameWidth.toFloat() - (padding.left + padding.right).toFloat()
            
            Log.d(TAG, "🔍 DCFTextShadowNode.applyLayoutNode: viewId=$viewId, frame=$frame, padding=$padding, availableWidth=$availableWidth")
            
            // Build text paint and layout for the final width
            val textPaint = buildTextPaintForWidth(availableWidth, YogaMeasureMode.EXACTLY)
            
            // CRITICAL: Ensure paint color is set (default to black if not set)
            if (textPaint.color == 0 || textPaint.color == android.graphics.Color.TRANSPARENT) {
                textPaint.color = android.graphics.Color.BLACK
                Log.w(TAG, "⚠️ DCFTextShadowNode: Paint color was 0/transparent, forcing to BLACK for viewId=$viewId")
            }
            
            Log.d(TAG, "🔍 DCFTextShadowNode: Building text layout with paint color=0x${Integer.toHexString(textPaint.color)}, textSize=${textPaint.textSize}, text='$text'")
            
            val textLayout = buildTextLayout(textPaint, availableWidth)
            
            // Calculate text frame (accounts for padding)
            val textFrame = calculateTextFrame(textLayout, padding)
            
            // Store for use by DCFTextComponent.applyLayout
            computedTextLayout = textLayout
            computedTextFrame = textFrame
            computedContentInset = android.graphics.Rect(padding.left, padding.top, padding.right, padding.bottom)
            
            Log.d(TAG, "✅ DCFTextShadowNode.applyLayoutNode: viewId=$viewId, set computedTextLayout (width=${textLayout.width}, height=${textLayout.height}), textFrame=$textFrame, text='${textLayout.text}'")
        } catch (e: Exception) {
            Log.e(TAG, "❌ DCFTextShadowNode.applyLayoutNode: Error building text layout for viewId=$viewId", e)
        }
    }
    
    /**
     * Calculate text frame from text layout (accounts for padding)
     * Matches iOS calculateTextFrame approach exactly
     * iOS: var textFrame = CGRect(origin: .zero, size: self.frame.size).inset(by: padding)
     * This creates a frame with origin at (0, 0) and size matching the view's frame, then insets by padding
     * So textFrame is the content area (frame size minus padding), positioned at (padding.left, padding.top)
     */
    private fun calculateTextFrame(layout: StaticLayout, padding: android.graphics.Rect): Rect {
        // Match iOS exactly: CGRect(origin: .zero, size: self.frame.size).inset(by: padding)
        // This gives us the content area (available space for text) inside the padding
        // Android Rect: frame.width() and frame.height() give us the size
        val frameWidth = frame.width()
        val frameHeight = frame.height()
        val textFrame = android.graphics.Rect(
            padding.left,
            padding.top,
            frameWidth - padding.right,
            frameHeight - padding.bottom
        )
        
        // TODO: Handle adjustsFontSizeToFit if needed (iOS does this in updateStorage)
        // For now, return the content area frame (matches iOS when adjustsFontSizeToFit is false)
        return textFrame
    }
    
    /**
     * Override to mark as Yoga leaf node (text nodes don't have Yoga children)
     */
    override fun isYogaLeafNode(): Boolean = true
    
    /**
     * Text nodes can have subviews (for nested text), but Yoga treats them as leaf nodes
     */
    override fun canHaveSubviews(): Boolean = true
}

