/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.layout

import android.graphics.PointF
import android.graphics.Rect
import android.util.Log
import com.facebook.yoga.*

/**
 * Shadow node for ScrollContentView
 * Handles RTL layout compensation
 * This is the Android equivalent of iOS DCFScrollContentShadowView - MUST match 1:1
 */
class DCFScrollContentShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    companion object {
        private const val TAG = "DCFScrollContentShadowNode"
    }
    
    init {
        // Enforce column layout for ScrollContentView by default
        yogaNode.setFlexDirection(YogaFlexDirection.COLUMN)
    }
    
    override fun applyLayoutNode(
        node: YogaNode,
        viewsWithNewFrame: MutableSet<DCFShadowNode>,
        absolutePosition: PointF
    ) {
        // Call super method if LTR layout is enforced.
        if (effectiveLayoutDirection == YogaDirection.LTR) {
            super.applyLayoutNode(node, viewsWithNewFrame, absolutePosition)
        } else {
            // Motivation:
            // Yoga places `contentView` on the right side of `scrollView` when RTL layout is enforced.
            // That breaks everything; it is completely pointless to (re)position `contentView`
            // because it is `contentView`'s job. So, we work around it here.
            
            // Step 1. Compensate `absolutePosition` change.
            var newAbsolutePosition = absolutePosition
            val xCompensation = node.layoutWidth - node.layoutX
            newAbsolutePosition.x += xCompensation
            
            // Step 2. Call super method.
            super.applyLayoutNode(node, viewsWithNewFrame, newAbsolutePosition)
            
            // Step 3. Reset the X position for RTL.
            val scale = android.content.res.Resources.getSystem().displayMetrics.density
            val roundedRight = (node.layoutWidth * scale).toInt() / scale.toInt()
            frame.left = roundedRight
        }
        
        // CRITICAL: ScrollContentView should always start at y=0 relative to ScrollView
        // Yoga may calculate a negative Y position, but we need to reset it to 0 (matches iOS 1:1)
        // This MUST happen in the shadow node because layout validation happens BEFORE component.applyLayout
        // If we don't reset here, the frame with negative Y will be rejected by isValidLayoutBounds
        // For RTL, left is already set correctly above, so we only reset top
        val originalTop = frame.top
        val width = frame.width() // Use frame's width (already calculated by super)
        val height = frame.height() // Use frame's height (already calculated by super)
        val currentLeft = frame.left // Preserve left (may be adjusted for RTL)
        
        // Reset top to 0 if needed (always reset top, preserve left for RTL)
        if (originalTop != 0) {
            frame = Rect(
                currentLeft, // Preserve left (may be non-zero for RTL)
                0, // Always start at y=0 relative to ScrollView (ignore Yoga's calculated top)
                currentLeft + width, // Keep frame's width
                height // Keep frame's height
            )
            // CRITICAL: Add to viewsWithNewFrame so the corrected frame gets applied
            viewsWithNewFrame.add(this)
            Log.d(TAG, "✅ DCFScrollContentShadowNode: Reset frame.top from $originalTop to 0 for viewId=$viewId. New frame: $frame")
        }
    }
}


