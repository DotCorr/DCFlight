/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
            return
        }
        
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
        
        // Step 3. Reset the position.
        val scale = android.content.res.Resources.getSystem().displayMetrics.density
        val roundedRight = (node.layoutWidth * scale).toInt() / scale.toInt()
        frame.left = roundedRight
    }
}

