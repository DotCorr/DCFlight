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
     * Set root frame before layout calculation (matches iOS 1:1)
     * This ensures children are positioned correctly relative to a properly sized root
     * NOTE: We do NOT set explicit width/height on Yoga node (matches iOS behavior)
     * iOS root node uses availableSize passed to calculateLayout, not explicit width/height
     */
    fun setRootFrame(width: Float, height: Float) {
        frame = android.graphics.Rect(0, 0, width.toInt(), height.toInt())
        Log.d(TAG, "✅ setRootFrame: Set root frame to (0, 0, ${width.toInt()}, ${height.toInt()})")
    }
    
    /**
     * Override applyLayoutNode to ensure root frame is always set correctly
     * Root node should always be at (0, 0) with the correct width/height from Yoga layout
     * This prevents children from being positioned incorrectly relative to the root
     */
    override fun applyLayoutNode(
        node: YogaNode,
        viewsWithNewFrame: MutableSet<DCFShadowNode>,
        absolutePosition: android.graphics.PointF
    ) {
        if (!node.hasNewLayout()) {
            return
        }
        
        require(!node.isDirty) { "Attempt to get layout metrics from dirtied Yoga node." }
        
        node.markLayoutSeen()
        
        if (node.display == YogaDisplay.NONE) {
            return
        }
        
        // CRITICAL: Root node should always be at (0, 0) with correct width/height
        // Yoga should return layoutX=0, layoutY=0 for root, but we ensure it's correct
        val layoutX = node.layoutX.coerceAtLeast(0f) // Clamp to 0
        val layoutY = node.layoutY.coerceAtLeast(0f) // Clamp to 0
        val layoutWidth = node.layoutWidth
        val layoutHeight = node.layoutHeight
        
        // Validate root layout values
        val isValidLayout = !layoutX.isNaN() && !layoutX.isInfinite() && 
                           !layoutY.isNaN() && !layoutY.isInfinite() &&
                           !layoutWidth.isNaN() && !layoutWidth.isInfinite() && layoutWidth > 0 &&
                           !layoutHeight.isNaN() && !layoutHeight.isInfinite() && layoutHeight > 0
        
        if (!isValidLayout) {
            Log.e(TAG, "❌ Invalid root layout values: layoutX=$layoutX, layoutY=$layoutY, layoutWidth=$layoutWidth, layoutHeight=$layoutHeight")
            // Use availableSize as fallback
            val fallbackWidth = if (availableSize.x.isFinite()) availableSize.x.toInt() else 1080
            val fallbackHeight = if (availableSize.y.isFinite()) availableSize.y.toInt() else 1920
            val rootFrame = android.graphics.Rect(0, 0, fallbackWidth, fallbackHeight)
            if (frame != rootFrame) {
                frame = rootFrame
                viewsWithNewFrame.add(this)
            }
            return
        }
        
        // Root frame should always be at (0, 0) with correct width/height
        val rootFrame = android.graphics.Rect(0, 0, layoutWidth.toInt(), layoutHeight.toInt())
        
        if (frame != rootFrame) {
            frame = rootFrame
            viewsWithNewFrame.add(this)
            Log.d(TAG, "✅ Root frame updated to $rootFrame (from Yoga layout)")
        }
        
        // CRITICAL: Root node's absolute position is always (0, 0)
        // Children will be positioned relative to this
        val newAbsolutePosition = android.graphics.PointF(0f, 0f)
        
        applyLayoutToChildren(node, viewsWithNewFrame, newAbsolutePosition)
    }
    
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
        Log.d(TAG, "🔍 DCFRootShadowNode: Before layout")
        Log.d(TAG, "   availableSize=${availableSize}")
        Log.d(TAG, "   availableWidth=$availableWidth, availableHeight=$availableHeight")
        Log.d(TAG, "   Root frame BEFORE layout: $frame")
        Log.d(TAG, "   Root Yoga node style: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
        Log.d(TAG, "   Root Yoga node childCount: ${yogaNode.childCount}")
        Log.d(TAG, "   Root Yoga node flexDirection: ${yogaNode.flexDirection}")
        Log.d(TAG, "   Root Yoga node justifyContent: ${yogaNode.justifyContent}")
        Log.d(TAG, "   Root Yoga node alignItems: ${yogaNode.alignItems}")
        
        // Log all children before layout
        for (i in 0 until yogaNode.childCount) {
            val child = yogaNode.getChildAt(i)
            val childShadowNode = YogaShadowTree.shared.getShadowNode(child)
            Log.d(TAG, "   Child $i (viewId=${childShadowNode?.viewId}):")
            Log.d(TAG, "     Yoga style: width=${child.width.value} (unit=${child.width.unit}), height=${child.height.value} (unit=${child.height.unit})")
            Log.d(TAG, "     minWidth=${child.minWidth.value}, minHeight=${child.minHeight.value}")
            Log.d(TAG, "     flexDirection=${child.flexDirection}, justifyContent=${child.justifyContent}, alignItems=${child.alignItems}")
            Log.d(TAG, "     Child frame BEFORE layout: ${childShadowNode?.frame}")
        }
        
        yogaNode.calculateLayout(availableWidth, availableHeight)
        
        // CRITICAL: Validate root node layout values immediately after calculation
        val rootLayoutX = yogaNode.layoutX
        val rootLayoutY = yogaNode.layoutY
        val rootLayoutWidth = yogaNode.layoutWidth
        val rootLayoutHeight = yogaNode.layoutHeight
        
        val isRootLayoutValid = !rootLayoutX.isNaN() && !rootLayoutX.isInfinite() &&
                               !rootLayoutY.isNaN() && !rootLayoutY.isInfinite() &&
                               !rootLayoutWidth.isNaN() && !rootLayoutWidth.isInfinite() && rootLayoutWidth > 0 &&
                               !rootLayoutHeight.isNaN() && !rootLayoutHeight.isInfinite() && rootLayoutHeight > 0
        
        if (!isRootLayoutValid) {
            Log.e(TAG, "❌❌❌ CRITICAL: Root node has invalid layout values after calculateLayout!")
            Log.e(TAG, "   layoutX=$rootLayoutX, layoutY=$rootLayoutY, layoutWidth=$rootLayoutWidth, layoutHeight=$rootLayoutHeight")
            Log.e(TAG, "   availableWidth=$availableWidth, availableHeight=$availableHeight")
            Log.e(TAG, "   Root Yoga node style: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
            Log.e(TAG, "   Root Yoga node childCount: ${yogaNode.childCount}")
            // Use availableSize as fallback for root node
            val fallbackWidth = if (availableWidth.isNaN() || availableWidth.isInfinite()) 1080f else availableWidth
            val fallbackHeight = if (availableHeight.isNaN() || availableHeight.isInfinite()) 1920f else availableHeight
            Log.e(TAG, "   Using fallback root frame: (0, 0, $fallbackWidth, $fallbackHeight)")
            frame = android.graphics.Rect(0, 0, fallbackWidth.toInt(), fallbackHeight.toInt())
            // Return empty set - children can't be laid out if root is invalid
            return emptySet()
        }
        
        // DEBUG: Log root node layout after calculation
        Log.d(TAG, "🔍 DCFRootShadowNode: After layout")
        Log.d(TAG, "   Root node layout: left=$rootLayoutX, top=$rootLayoutY, width=$rootLayoutWidth, height=$rootLayoutHeight")
        Log.d(TAG, "   Root frame AFTER layout calculation: $frame")
        
        // DEBUG: Log ALL children after layout
        Log.d(TAG, "   Root has ${yogaNode.childCount} children after layout:")
        for (i in 0 until yogaNode.childCount) {
            val child = yogaNode.getChildAt(i)
            val childShadowNode = YogaShadowTree.shared.getShadowNode(child)
            Log.d(TAG, "   Child $i (viewId=${childShadowNode?.viewId}):")
            Log.d(TAG, "     Yoga layout: left=${child.layoutX}, top=${child.layoutY}, width=${child.layoutWidth}, height=${child.layoutHeight}")
            Log.d(TAG, "     Child frame AFTER layout: ${childShadowNode?.frame}")
            if (child.layoutY < 0) {
                Log.w(TAG, "     ⚠️ WARNING: Child has negative Y position!")
            }
        }
        
        val viewsWithNewFrame = mutableSetOf<DCFShadowNode>()
        
        // CRITICAL: Call applyLayoutNode on root first (matches iOS 1:1)
        // This sets the root frame BEFORE calculating children, ensuring parent frame is available
        // iOS does: applyLayoutNode(yogaNode, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: .zero)
        // The overridden applyLayoutNode will ensure root frame is always set correctly
        applyLayoutNode(yogaNode, viewsWithNewFrame, PointF(0f, 0f))
        
        return viewsWithNewFrame
    }
}


