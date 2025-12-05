/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.PointF
import android.util.Log
import com.facebook.yoga.*

/**
 * Root shadow node for the entire view hierarchy
 * This is the Android equivalent of iOS DCFRootShadowView - MUST match 1:1
 */
class DCFRootShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    companion object {
        private const val TAG = "DCFRootShadowNode"
    }
    
    /**
     * Available size to layout all views.
     * Defaults to {INFINITY, INFINITY}
     * Overrides the computed property from DCFShadowNode
     */
    private var _availableSize: PointF = PointF(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)
    
    override var availableSize: PointF
        get() = _availableSize
        set(value) {
            _availableSize = value
            // Mark as dirty when available size changes
            dirtyPropagation()
        }
    
    /**
     * Layout direction (LTR or RTL) inherited from native environment and
     * is using as a base direction value in layout engine.
     * Defaults to LTR.
     */
    var baseDirection: YogaDirection = YogaDirection.LTR
    
    /**
     * Calculate all views whose frame needs updating after layout has been calculated.
     * Returns a set contains the shadow nodes that need updating.
     * Matches iOS collectViewsWithUpdatedFrames exactly
     */
    fun collectViewsWithUpdatedFrames(): Set<DCFShadowNode> {
        // Treating `INFINITY` as undefined (which equals `Float.NaN`).
        // Yoga API: calculateLayout accepts Float, use Float.NaN for undefined
        val availableWidth = if (availableSize.x == Float.POSITIVE_INFINITY) {
            Float.NaN
        } else {
            availableSize.x
        }
        val availableHeight = if (availableSize.y == Float.POSITIVE_INFINITY) {
            Float.NaN
        } else {
            availableSize.y
        }
        
        // DEBUG: Log root node state before layout
        Log.d(TAG, "🔍 DCFRootShadowNode: Before layout - availableSize=${availableSize}, yogaNode width=${yogaNode.width.value}, height=${yogaNode.height.value}")
        
        yogaNode.calculateLayout(availableWidth, availableHeight)
        
        // DEBUG: Log root node layout after calculation
        Log.d(TAG, "🔍 DCFRootShadowNode: After layout - root node layout: left=${yogaNode.layoutX}, top=${yogaNode.layoutY}, width=${yogaNode.layoutWidth}, height=${yogaNode.layoutHeight}")
        
        // DEBUG: Log first child if exists
        if (yogaNode.childCount > 0) {
            val firstChild = yogaNode.getChildAt(0)
            Log.d(TAG, "🔍 DCFRootShadowNode: First child layout: left=${firstChild.layoutX}, top=${firstChild.layoutY}, width=${firstChild.layoutWidth}, height=${firstChild.layoutHeight}")
        }
        
        val viewsWithNewFrame = mutableSetOf<DCFShadowNode>()
        applyLayoutNode(yogaNode, viewsWithNewFrame, PointF(0f, 0f))
        
        return viewsWithNewFrame
    }
}

