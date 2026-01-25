/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
        // Match iOS exactly - use Yoga's layout values directly without clamping
        // iOS DCFRootShadowView.applyLayoutNode uses YGNodeLayoutGetLeft/Top directly
        // If Yoga returns non-zero for root, it indicates a setup issue, but we trust Yoga
        val layoutX = node.layoutX
        val layoutY = node.layoutY
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
        
        // CRITICAL: Root frame should ALWAYS be at (0, 0) with dimensions matching available size
        // Match iOS exactly - root frame is always (0, 0, availableWidth, availableHeight)
        // Yoga should return layoutX=0, layoutY=0 for root, but we enforce it to prevent coordinate system issues
        // If Yoga returns non-zero for root, it indicates a setup issue, but we correct it here
        val rootFrame = android.graphics.Rect(0, 0, layoutWidth.toInt(), layoutHeight.toInt())
        
        // CRITICAL: If Yoga returned non-zero position for root, log a warning but use (0, 0)
        if (layoutX != 0f || layoutY != 0f) {
            Log.w(TAG, "⚠️ WARNING: Yoga returned non-zero position for root node: layoutX=$layoutX, layoutY=$layoutY")
            Log.w(TAG, "   This indicates a Yoga setup issue. Root should always be at (0, 0).")
            Log.w(TAG, "   Correcting root frame to (0, 0, $layoutWidth, $layoutHeight)")
        }
        
        if (frame != rootFrame) {
            frame = rootFrame
            viewsWithNewFrame.add(this)
            Log.d(TAG, "✅ Root frame set to $rootFrame (Yoga layout: left=$layoutX, top=$layoutY, width=$layoutWidth, height=$layoutHeight)")
        }
        
        // CRITICAL: Root node's absolute position is always (0, 0)
        // Children will be positioned relative to this
        // Match iOS exactly - root's absolutePosition is always .zero
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
        
        // CRITICAL: Match iOS behavior exactly - DO NOT set explicit width/height on root Yoga node
        // iOS DCFRootShadowView does NOT set explicit width/height on the root Yoga node
        // Instead, it passes availableWidth/availableHeight to YGNodeCalculateLayout, and Yoga determines
        // the root node's size from those constraints. This is the correct approach that prevents
        // coordinate system mismatches and negative child positions.
        // Setting explicit dimensions can cause Yoga to use those instead of the available size,
        // leading to incorrect layout calculations for children.
        
        // CRITICAL: Ensure root node doesn't have explicit dimensions set (clear any that might exist)
        // This ensures Yoga uses availableWidth/availableHeight passed to calculateLayout
        // If explicit dimensions are set, Yoga might use those instead, causing coordinate mismatches
        // Root node should have UNDEFINED or AUTO dimensions so Yoga uses available size from calculateLayout
        val hasExplicitWidth = yogaNode.width.unit == YogaUnit.POINT || yogaNode.width.unit == YogaUnit.PERCENT
        val hasExplicitHeight = yogaNode.height.unit == YogaUnit.POINT || yogaNode.height.unit == YogaUnit.PERCENT
        if (hasExplicitWidth || hasExplicitHeight) {
            Log.d(TAG, "⚠️ Root Yoga node has explicit dimensions - clearing to match iOS behavior")
            Log.d(TAG, "   Before: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
            // Set to AUTO so Yoga uses available size from calculateLayout (matches iOS behavior)
            yogaNode.setWidthAuto()
            yogaNode.setHeightAuto()
            Log.d(TAG, "   After: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
        }
        
        // CRITICAL: Ensure root node's flex properties allow children to expand
        // Root node should allow its first child (ScrollView) to expand to fill the screen
        // Set flexGrow to 1 for root node to ensure it fills available space
        if (yogaNode.flexGrow != 1.0f) {
            Log.d(TAG, "🔧 Setting root node flexGrow to 1.0 to ensure it fills available space")
            yogaNode.setFlexGrow(1.0f)
        }
        
        // CRITICAL: Ensure root node's direction is set correctly before calculateLayout
        // This matches React Native's approach - direction must be set on the Yoga node itself
        // React Native sets direction via setDirection() before calculateLayout
        // Always set direction to ensure it's correct (YogaNode doesn't have a readable direction property)
        yogaNode.setDirection(baseDirection)
        Log.d(TAG, "🔧 Root Yoga node direction set to $baseDirection")
        
        // CRITICAL: Ensure root node has no margins or padding that could affect child positioning
        // Root node should be at (0, 0) with no insets - margins/padding on root can cause coordinate system issues
        // Match iOS exactly - root node should have zero margins and padding
        // Note: We check layout values (computed after layout) as a diagnostic, but the real fix is to ensure
        // margins/padding are never set on root node in the first place (handled in prop setting code)
        // This check is just for debugging - if layout margins/padding are non-zero, it indicates a setup issue
        val rootMarginLeft = yogaNode.getLayoutMargin(YogaEdge.LEFT)
        val rootMarginTop = yogaNode.getLayoutMargin(YogaEdge.TOP)
        val rootPaddingLeft = yogaNode.getLayoutPadding(YogaEdge.LEFT)
        val rootPaddingTop = yogaNode.getLayoutPadding(YogaEdge.TOP)
        if (rootMarginLeft != 0f || rootMarginTop != 0f || rootPaddingLeft != 0f || rootPaddingTop != 0f) {
            Log.w(TAG, "⚠️ WARNING: Root node has non-zero layout margins/padding!")
            Log.w(TAG, "   layoutMarginLeft=$rootMarginLeft, layoutMarginTop=$rootMarginTop, layoutPaddingLeft=$rootPaddingLeft, layoutPaddingTop=$rootPaddingTop")
            Log.w(TAG, "   This can cause coordinate system issues. Root should have zero margins/padding.")
            Log.w(TAG, "   This is a diagnostic warning - margins/padding should not be set on root node.")
        }
        
        // Log all children before layout
        for (i in 0 until yogaNode.childCount) {
            val child = yogaNode.getChildAt(i)
            val childShadowNode = YogaShadowTree.shared.getShadowNode(child)
            Log.d(TAG, "   Child $i (viewId=${childShadowNode?.viewId}):")
            Log.d(TAG, "     Yoga style: width=${child.width.value} (unit=${child.width.unit}), height=${child.height.value} (unit=${child.height.unit})")
            Log.d(TAG, "     minWidth=${child.minWidth.value}, minHeight=${child.minHeight.value}")
            Log.d(TAG, "     flexDirection=${child.flexDirection}, justifyContent=${child.justifyContent}, alignItems=${child.alignItems}")
            Log.d(TAG, "     Child frame BEFORE layout: ${childShadowNode?.frame}")
            
            // CRITICAL: Ensure root view's first child expands to fill parent
            // If the child has undefined width/height, it should expand to fill the root
            // This is especially important for ScrollView which should fill the screen
            if (i == 0 && child.width.unit == YogaUnit.UNDEFINED && child.height.unit == YogaUnit.UNDEFINED) {
                Log.d(TAG, "     🔧 Root's first child has undefined dimensions - ensuring it expands to fill parent")
                // CRITICAL: Set flexGrow to 1.0 to ensure child expands to fill parent
                // This is necessary for ScrollView to fill the screen
                if (child.flexGrow != 1.0f) {
                    Log.d(TAG, "     🔧 Setting first child flexGrow to 1.0 to ensure it expands")
                    child.setFlexGrow(1.0f)
                }
            }
        }
        
        yogaNode.calculateLayout(availableWidth, availableHeight)
        
        // CRITICAL: Validate root node layout values immediately after calculation
        // Match iOS behavior exactly - Yoga should calculate root node at (0, 0) with size matching available size
        val rootLayoutX = yogaNode.layoutX
        val rootLayoutY = yogaNode.layoutY
        val rootLayoutWidth = yogaNode.layoutWidth
        val rootLayoutHeight = yogaNode.layoutHeight
        
        // CRITICAL: Root node should always be at (0, 0) with dimensions matching available size
        // If root layout position is not (0, 0), it indicates a fundamental coordinate system issue
        val rootPositionValid = rootLayoutX == 0f && rootLayoutY == 0f
        val rootSizeValid = if (!availableWidth.isNaN() && !availableWidth.isInfinite() && availableWidth > 0) {
            // Allow small floating point differences (within 1 pixel)
            kotlin.math.abs(rootLayoutWidth - availableWidth) < 1f
        } else {
            rootLayoutWidth > 0
        } && if (!availableHeight.isNaN() && !availableHeight.isInfinite() && availableHeight > 0) {
            kotlin.math.abs(rootLayoutHeight - availableHeight) < 1f
        } else {
            rootLayoutHeight > 0
        }
        
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
        
        // CRITICAL: Warn if root position or size doesn't match expectations
        // This indicates a coordinate system mismatch that could cause negative child positions
        if (!rootPositionValid) {
            Log.e(TAG, "❌❌❌ CRITICAL: Root node position is not (0, 0)! layoutX=$rootLayoutX, layoutY=$rootLayoutY")
            Log.e(TAG, "   This indicates a serious Yoga layout bug - root should always be at (0, 0)")
            Log.e(TAG, "   This will cause all children to be positioned incorrectly!")
            Log.e(TAG, "   Root Yoga node style: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
            Log.e(TAG, "   Root Yoga node has explicit dimensions: ${yogaNode.width.unit != YogaUnit.UNDEFINED || yogaNode.height.unit != YogaUnit.UNDEFINED}")
        }
        if (!rootSizeValid) {
            Log.w(TAG, "⚠️ WARNING: Root node size doesn't match available size!")
            Log.w(TAG, "   layoutWidth=$rootLayoutWidth (expected ~$availableWidth), layoutHeight=$rootLayoutHeight (expected ~$availableHeight)")
            Log.w(TAG, "   Root Yoga node style: width=${yogaNode.width.value} (unit=${yogaNode.width.unit}), height=${yogaNode.height.value} (unit=${yogaNode.height.unit})")
            Log.w(TAG, "   This might cause layout issues, but continuing...")
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


