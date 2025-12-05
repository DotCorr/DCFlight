/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.Rect
import android.util.Log
import com.facebook.yoga.*
import java.lang.ref.WeakReference

/**
 * ShadowNode tree mirrors DCF view tree. Every node is highly stateful.
 * 1. A node is in one of three lifecycles: uninitialized, computed, dirtied.
 * 2. DCFBridge may call any of the padding/margin/width/height/top/left setters. A setter would dirty
 *    the node and all of its ancestors.
 * 3. At the end of each Bridge transaction, we call calculateAndApplyLayout at the root node
 *    to recursively lay out the entire hierarchy.
 * 4. If a node is "computed" and the constraint passed from above is identical to the constraint used to
 *    perform the last computation, we skip laying out the subtree entirely.
 * 
 * This is the Android equivalent of iOS DCFShadowView - MUST match 1:1
 */
open class DCFShadowNode {
    
    companion object {
        private const val TAG = "DCFShadowNode"
        private const val NO_INTRINSIC_METRIC = -1f
        
        // Shared Yoga config - matches iOS
        val yogaConfig: YogaConfig = YogaConfigFactory.create()
    }
    
    // MARK: - Lifecycle
    
    enum class UpdateLifecycle {
        UNINITIALIZED,
        COMPUTED,
        DIRTIED
    }
    
    // MARK: - Properties
    
    val viewId: Int
    var viewName: String = ""
    var backgroundColor: Int? = null
    var onLayout: ((Rect) -> Unit)? = null
    
    /**
     * isNewView - Used to track the first time the view is introduced into the hierarchy.
     * It is initialized true, then is set to false after the layout pass is done and all frames
     * have been extracted to be applied to the corresponding Views.
     */
    var isNewView: Boolean = true
    
    /**
     * isHidden - DCFUIManager uses this to determine whether or not the View should be hidden.
     * Useful if the ShadowNode determines that its View will be clipped and wants to hide it.
     */
    var isHidden: Boolean = false
    
    /**
     * Computed layout direction for the view backed to Yoga node value.
     */
    val effectiveLayoutDirection: YogaDirection
        get() = yogaNode.layoutDirection
    
    /**
     * Computed position of the view.
     * Made internal (not private) so subclasses like DCFScrollContentShadowNode can modify it
     */
    var frame: Rect = Rect(0, 0, 0, 0)
        internal set
    
    /**
     * Available size for children (frame size minus compound insets)
     * Can be overridden by subclasses like DCFRootShadowNode
     */
    open val availableSize: android.graphics.PointF
        get() {
            val insets = compoundInsets
            return android.graphics.PointF(
                (frame.width().toFloat() - insets.left.toFloat() - insets.right.toFloat()).coerceAtLeast(0f),
                (frame.height().toFloat() - insets.top.toFloat() - insets.bottom.toFloat()).coerceAtLeast(0f)
            )
        }
    
    /**
     * Padding as Rect (top, left, bottom, right)
     */
    val paddingAsInsets: android.graphics.Rect
        get() {
            return android.graphics.Rect(
                yogaNode.getLayoutPadding(YogaEdge.LEFT).toInt(),
                yogaNode.getLayoutPadding(YogaEdge.TOP).toInt(),
                yogaNode.getLayoutPadding(YogaEdge.RIGHT).toInt(),
                yogaNode.getLayoutPadding(YogaEdge.BOTTOM).toInt()
            )
        }
    
    /**
     * Border as Rect (top, left, bottom, right)
     */
    val borderAsInsets: android.graphics.Rect
        get() {
            return android.graphics.Rect(
                yogaNode.getLayoutBorder(YogaEdge.LEFT).toInt(),
                yogaNode.getLayoutBorder(YogaEdge.TOP).toInt(),
                yogaNode.getLayoutBorder(YogaEdge.RIGHT).toInt(),
                yogaNode.getLayoutBorder(YogaEdge.BOTTOM).toInt()
            )
        }
    
    /**
     * Compound insets (border + padding)
     */
    val compoundInsets: android.graphics.Rect
        get() {
            val border = borderAsInsets
            val padding = paddingAsInsets
            return android.graphics.Rect(
                border.left + padding.left,
                border.top + padding.top,
                border.right + padding.right,
                border.bottom + padding.bottom
            )
        }
    
    /**
     * Represents the natural size of the view, which is used when explicit size is not set or is ambiguous.
     * Defaults to `{NO_INTRINSIC_METRIC, NO_INTRINSIC_METRIC}`.
     * 
     * CRITICAL: This can only be set on leaf nodes (nodes with no children).
     * Nodes with children size based on their children, not intrinsic size.
     * Attempting to set this on a node with children will be silently ignored to prevent crashes.
     */
    private var _intrinsicContentSize: android.graphics.PointF = android.graphics.PointF(NO_INTRINSIC_METRIC, NO_INTRINSIC_METRIC)
    
    var intrinsicContentSize: android.graphics.PointF
        get() = _intrinsicContentSize
        set(value) {
            // CRITICAL: Only allow setting intrinsicContentSize on leaf nodes (no children)
            // Nodes with children size based on their children, not intrinsic size
            // Attempting to set this on a node with children will cause Yoga to crash
            val childCount = yogaNode.childCount
            if (childCount > 0) {
                // Node has children - silently ignore the assignment to prevent crash
                // This can happen if registerView is called after children are attached
                Log.w(TAG, "Attempted to set intrinsicContentSize on node with children (viewId=$viewId, childCount=$childCount)")
                return
            }
            
            _intrinsicContentSize = value
            
            // Set up measure function based on the new value
            // We do NOT call yogaNode.dirty() here because:
            // 1. Yoga will automatically mark nodes dirty when needed during layout calculation
            // 2. Calling dirty() on a node that might have children (even if childCount == 0 now)
            //    can cause crashes if children are added between the check and the mark
            // 3. The measure function will be called by Yoga when it needs to measure the node
            if (value.x == NO_INTRINSIC_METRIC && value.y == NO_INTRINSIC_METRIC) {
                yogaNode.setMeasureFunction(null)
            } else {
                yogaNode.setMeasureFunction(createMeasureFunction())
            }
        }
    
    // MARK: - Private Properties
    
    private var _propagationLifecycle: UpdateLifecycle = UpdateLifecycle.UNINITIALIZED
    private var _textLifecycle: UpdateLifecycle = UpdateLifecycle.UNINITIALIZED
    private var _lastParentProperties: Map<String, Any>? = null
    private val _subviews: MutableList<DCFShadowNode> = mutableListOf()
    private var _recomputePadding: Boolean = false
    private var _recomputeMargin: Boolean = false
    private var _recomputeBorder: Boolean = false
    private var _didUpdateSubviews: Boolean = false
    
    private val _paddingMetaProps: MutableMap<MetaProp, YogaValue> = mutableMapOf()
    private val _marginMetaProps: MutableMap<MetaProp, YogaValue> = mutableMapOf()
    private val _borderMetaProps: MutableMap<MetaProp, YogaValue> = mutableMapOf()
    
    internal enum class MetaProp {
        LEFT,
        TOP,
        RIGHT,
        BOTTOM,
        HORIZONTAL,
        VERTICAL,
        ALL
    }
    
    // MARK: - Parent-Child Relationships
    
    private var _superview: WeakReference<DCFShadowNode>? = null
    val superview: DCFShadowNode?
        get() = _superview?.get()
    
    val subviews: List<DCFShadowNode>
        get() = _subviews.toList()
    
    // MARK: - Yoga Node
    
    val yogaNode: YogaNode
    
    // MARK: - Initialization
    
    constructor(viewId: Int) {
        this.viewId = viewId
        
        // Initialize meta props
        MetaProp.values().forEach { prop ->
            _paddingMetaProps[prop] = YogaValue(0f, YogaUnit.UNDEFINED)
            _marginMetaProps[prop] = YogaValue(0f, YogaUnit.UNDEFINED)
            _borderMetaProps[prop] = YogaValue(0f, YogaUnit.UNDEFINED)
        }
        
        // Create Yoga node
        yogaNode = YogaNodeFactory.create()
        yogaNode.setData(this)
    }
    
    // MARK: - Subview Management
    
    /**
     * Returns whether or not this view can have any subviews.
     * Adding/inserting a child view to leaf view (`canHaveSubviews` equals `false`)
     * will throw an error.
     * Return `false` for components which must not have any descendants
     * (like Image, for example.)
     * Defaults to `true`. Can be overridden in subclasses.
     */
    open fun canHaveSubviews(): Boolean = true
    
    /**
     * Returns whether or not this node acts as a leaf node in the eyes of Yoga.
     * For example `DCFTextShadowNode` has children which it does not want Yoga
     * to lay out so in the eyes of Yoga it is a leaf node.
     * Defaults to `false`. Can be overridden in subclasses.
     */
    open fun isYogaLeafNode(): Boolean = false
    
    fun insertSubview(subview: DCFShadowNode, atIndex: Int) {
        require(canHaveSubviews()) { "Attempt to insert subview inside leaf view." }
        
        // CRITICAL: Remove measure function and clear intrinsic content size BEFORE adding children
        // Yoga rule: Nodes with measure functions cannot have children
        // Nodes with children size based on their children, not intrinsic size
        if (!isYogaLeafNode()) {
            // Clear measure function first
            if (yogaNode.isMeasureDefined) {
                yogaNode.setMeasureFunction(null)
            }
            // Directly clear the stored intrinsic content size property
            // We cannot use the setter here because it checks childCount == 0,
            // but we're about to add a child, so we need to bypass the setter
            _intrinsicContentSize = android.graphics.PointF(NO_INTRINSIC_METRIC, NO_INTRINSIC_METRIC)
            
            // NOW add the child to the Yoga node
            yogaNode.addChildAt(subview.yogaNode, atIndex)
        }
        
        _subviews.add(atIndex, subview)
        subview._superview = WeakReference(this)
        _didUpdateSubviews = true
        dirtyText()
        dirtyPropagation()
    }
    
    fun removeSubview(subview: DCFShadowNode) {
        subview.dirtyText()
        subview.dirtyPropagation()
        _didUpdateSubviews = true
        subview._superview = null
        _subviews.remove(subview)
        if (!isYogaLeafNode()) {
            val index = yogaNode.indexOf(subview.yogaNode)
            if (index >= 0) {
                yogaNode.removeChildAt(index)
            }
        }
    }
    
    // MARK: - Lifecycle Management
    
    fun dirtyPropagation() {
        if (_propagationLifecycle != UpdateLifecycle.DIRTIED) {
            _propagationLifecycle = UpdateLifecycle.DIRTIED
            superview?.dirtyPropagation()
        }
    }
    
    fun isPropagationDirty(): Boolean {
        return _propagationLifecycle != UpdateLifecycle.COMPUTED
    }
    
    fun dirtyText() {
        if (_textLifecycle != UpdateLifecycle.DIRTIED) {
            _textLifecycle = UpdateLifecycle.DIRTIED
            superview?.dirtyText()
        }
    }
    
    fun isTextDirty(): Boolean {
        return _textLifecycle != UpdateLifecycle.COMPUTED
    }
    
    fun setTextComputed() {
        _textLifecycle = UpdateLifecycle.COMPUTED
    }
    
    // MARK: - Layout
    
    /**
     * Apply layout from Yoga node calculation results.
     * Matches iOS applyLayoutNode exactly.
     */
    open fun applyLayoutNode(
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
            // If the node is hidden (has `display: none;`), its (and its descendants)
            // layout metrics are invalid and/or dirtied, so we have to stop here.
            return
        }
        
        // Calculate frame from Yoga layout results
        // Position is relative to parent (layoutX/layoutY)
        // Size is calculated from layout dimensions
        val absoluteTopLeft = android.graphics.PointF(
            absolutePosition.x + node.layoutX,
            absolutePosition.y + node.layoutY
        )
        
        val absoluteBottomRight = android.graphics.PointF(
            absolutePosition.x + node.layoutX + node.layoutWidth,
            absolutePosition.y + node.layoutY + node.layoutHeight
        )
        
        val newFrame = Rect(
            roundPixelValue(node.layoutX),
            roundPixelValue(node.layoutY),
            roundPixelValue(absoluteBottomRight.x),
            roundPixelValue(absoluteBottomRight.y)
        )
        
        // DEBUG: Log problematic frames (negative Y or zero height)
        if (newFrame.top < 0 || newFrame.height() == 0) {
            Log.w(TAG, "⚠️ DCFShadowNode: viewId=$viewId has problematic frame:")
            Log.w(TAG, "   Yoga values: left=${node.layoutX}, top=${node.layoutY}, width=${node.layoutWidth}, height=${node.layoutHeight}")
            Log.w(TAG, "   absolutePosition=$absolutePosition")
            Log.w(TAG, "   absoluteTopLeft=$absoluteTopLeft, absoluteBottomRight=$absoluteBottomRight")
            Log.w(TAG, "   Calculated frame=$newFrame")
            Log.w(TAG, "   Parent frame=$frame")
        }
        
        if (frame != newFrame) {
            frame = newFrame
            viewsWithNewFrame.add(this)
        }
        
        val newAbsolutePosition = android.graphics.PointF(
            absolutePosition.x + node.layoutX,
            absolutePosition.y + node.layoutY
        )
        
        applyLayoutToChildren(node, viewsWithNewFrame, newAbsolutePosition)
    }
    
    open fun applyLayoutToChildren(
        node: YogaNode,
        viewsWithNewFrame: MutableSet<DCFShadowNode>,
        absolutePosition: android.graphics.PointF
    ) {
        val childCount = node.childCount
        for (i in 0 until childCount) {
            if (i < _subviews.size) {
                val child = _subviews[i]
                val childNode = node.getChildAt(i)
                child.applyLayoutNode(childNode, viewsWithNewFrame, absolutePosition)
            }
        }
    }
    
    fun didUpdateSubviews() {
        // Does nothing by default
    }
    
    // MARK: - Prop Processing
    
    /**
     * Called when props are set to process meta props (margin/padding/border).
     * Meta properties are composite properties that affect multiple edges (e.g., margin affects all sides).
     */
    fun didSetProps(changedProps: List<String>) {
        if (_recomputePadding) {
            processMetaPropsPadding()
        }
        if (_recomputeMargin) {
            processMetaPropsMargin()
        }
        if (_recomputeBorder) {
            processMetaPropsBorder()
        }
        _recomputeMargin = false
        _recomputePadding = false
        _recomputeBorder = false
    }
    
    /**
     * Process padding meta props and apply to Yoga node.
     * Handles: padding, paddingTop, paddingRight, paddingBottom, paddingLeft,
     * paddingHorizontal, paddingVertical
     */
    private fun processMetaPropsPadding() {
        _paddingMetaProps[MetaProp.LEFT]?.let { value ->
            applyPaddingValue(value, YogaEdge.START)
        }
        _paddingMetaProps[MetaProp.RIGHT]?.let { value ->
            applyPaddingValue(value, YogaEdge.END)
        }
        _paddingMetaProps[MetaProp.TOP]?.let { value ->
            applyPaddingValue(value, YogaEdge.TOP)
        }
        _paddingMetaProps[MetaProp.BOTTOM]?.let { value ->
            applyPaddingValue(value, YogaEdge.BOTTOM)
        }
        _paddingMetaProps[MetaProp.HORIZONTAL]?.let { value ->
            applyPaddingValue(value, YogaEdge.HORIZONTAL)
        }
        _paddingMetaProps[MetaProp.VERTICAL]?.let { value ->
            applyPaddingValue(value, YogaEdge.VERTICAL)
        }
        _paddingMetaProps[MetaProp.ALL]?.let { value ->
            applyPaddingValue(value, YogaEdge.ALL)
        }
    }
    
    private fun applyPaddingValue(value: YogaValue, edge: YogaEdge) {
        when (value.unit) {
            YogaUnit.AUTO, YogaUnit.UNDEFINED -> {
                yogaNode.setPadding(edge, Float.NaN)
            }
            YogaUnit.POINT -> {
                yogaNode.setPadding(edge, value.value)
            }
            YogaUnit.PERCENT -> {
                yogaNode.setPaddingPercent(edge, value.value)
            }
        }
        dirtyText()
    }
    
    /**
     * Process margin meta props and apply to Yoga node.
     * Handles: margin, marginTop, marginRight, marginBottom, marginLeft,
     * marginHorizontal, marginVertical
     */
    private fun processMetaPropsMargin() {
        _marginMetaProps[MetaProp.LEFT]?.let { value ->
            applyMarginValue(value, YogaEdge.START)
        }
        _marginMetaProps[MetaProp.RIGHT]?.let { value ->
            applyMarginValue(value, YogaEdge.END)
        }
        _marginMetaProps[MetaProp.TOP]?.let { value ->
            applyMarginValue(value, YogaEdge.TOP)
        }
        _marginMetaProps[MetaProp.BOTTOM]?.let { value ->
            applyMarginValue(value, YogaEdge.BOTTOM)
        }
        _marginMetaProps[MetaProp.HORIZONTAL]?.let { value ->
            applyMarginValue(value, YogaEdge.HORIZONTAL)
        }
        _marginMetaProps[MetaProp.VERTICAL]?.let { value ->
            applyMarginValue(value, YogaEdge.VERTICAL)
        }
        _marginMetaProps[MetaProp.ALL]?.let { value ->
            applyMarginValue(value, YogaEdge.ALL)
        }
    }
    
    /**
     * Apply margin value to Yoga node, handling auto, undefined, point, and percent units.
     */
    private fun applyMarginValue(value: YogaValue, edge: YogaEdge) {
        when (value.unit) {
            YogaUnit.AUTO -> yogaNode.setMarginAuto(edge)
            YogaUnit.UNDEFINED -> yogaNode.setMargin(edge, Float.NaN)
            YogaUnit.POINT -> yogaNode.setMargin(edge, value.value)
            YogaUnit.PERCENT -> yogaNode.setMarginPercent(edge, value.value)
        }
        dirtyText()
    }
    
    /**
     * Process border meta props and apply to Yoga node.
     * Handles: borderWidth, borderTopWidth, borderRightWidth, borderBottomWidth, borderLeftWidth
     */
    private fun processMetaPropsBorder() {
        _borderMetaProps[MetaProp.LEFT]?.let { value ->
            yogaNode.setBorder(YogaEdge.START, value.value)
        }
        _borderMetaProps[MetaProp.RIGHT]?.let { value ->
            yogaNode.setBorder(YogaEdge.END, value.value)
        }
        _borderMetaProps[MetaProp.TOP]?.let { value ->
            yogaNode.setBorder(YogaEdge.TOP, value.value)
        }
        _borderMetaProps[MetaProp.BOTTOM]?.let { value ->
            yogaNode.setBorder(YogaEdge.BOTTOM, value.value)
        }
        _borderMetaProps[MetaProp.HORIZONTAL]?.let { value ->
            yogaNode.setBorder(YogaEdge.HORIZONTAL, value.value)
        }
        _borderMetaProps[MetaProp.VERTICAL]?.let { value ->
            yogaNode.setBorder(YogaEdge.VERTICAL, value.value)
        }
        _borderMetaProps[MetaProp.ALL]?.let { value ->
            yogaNode.setBorder(YogaEdge.ALL, value.value)
        }
    }
    
    /**
     * Store meta prop value for later processing.
     * Called by YogaShadowTree when layout props are updated.
     */
    internal fun storeMetaProp(prop: MetaProp, value: YogaValue, type: MetaPropType) {
        when (type) {
            MetaPropType.PADDING -> {
                _paddingMetaProps[prop] = value
                _recomputePadding = true
            }
            MetaPropType.MARGIN -> {
                _marginMetaProps[prop] = value
                _recomputeMargin = true
            }
            MetaPropType.BORDER -> {
                _borderMetaProps[prop] = value
                _recomputeBorder = true
            }
        }
    }
    
    internal enum class MetaPropType {
        PADDING,
        MARGIN,
        BORDER
    }
    
    // MARK: - Helper Functions
    
    private fun roundPixelValue(value: Float): Int {
        // Android uses density-independent pixels, so we round to nearest pixel
        return value.toInt()
    }
    
    private fun setYogaValue(value: YogaValue, edge: YogaEdge, setter: (YogaNode, YogaEdge, Float) -> Unit) {
        when (value.unit) {
            YogaUnit.AUTO, YogaUnit.UNDEFINED -> {
                setter(yogaNode, edge, Float.NaN)
            }
            YogaUnit.POINT -> {
                setter(yogaNode, edge, value.value)
            }
            YogaUnit.PERCENT -> {
                // For position, use setPositionPercent
                // For padding, use setPaddingPercent
                // This is handled by the caller
            }
        }
        dirtyText()
    }
    
    /**
     * Apply dimension value (width/height) to Yoga node, handling auto, undefined, point, and percent units.
     * Used for properties that don't have an edge parameter.
     */
    private fun applyDimensionValue(
        value: YogaValue,
        setter: (YogaNode, Float) -> Unit,
        setterPercent: (YogaNode, Float) -> Unit,
        setterAuto: ((YogaNode) -> Unit)?
    ) {
        when (value.unit) {
            YogaUnit.AUTO -> {
                if (setterAuto != null) {
                    setterAuto(yogaNode)
                } else {
                    setter(yogaNode, Float.NaN)
                }
            }
            YogaUnit.UNDEFINED -> {
                setter(yogaNode, Float.NaN)
            }
            YogaUnit.POINT -> {
                setter(yogaNode, value.value)
            }
            YogaUnit.PERCENT -> {
                setterPercent(yogaNode, value.value)
            }
        }
        dirtyText()
    }
    
    /**
     * Create measure function for this shadow node.
     * Uses intrinsicContentSize to measure the node.
     */
    private fun createMeasureFunction(): YogaMeasureFunction {
        return YogaMeasureFunction { node, width, widthMode, height, heightMode ->
            val shadowNode = node.data as? DCFShadowNode ?: return@YogaMeasureFunction YogaMeasureOutput.make(0f, 0f)
            
            var intrinsicWidth = shadowNode.intrinsicContentSize.x
            var intrinsicHeight = shadowNode.intrinsicContentSize.y
            
            // Replace NO_INTRINSIC_METRIC (which equals -1) with zero
            if (intrinsicWidth == NO_INTRINSIC_METRIC) intrinsicWidth = 0f
            if (intrinsicHeight == NO_INTRINSIC_METRIC) intrinsicHeight = 0f
            
            var resultWidth = 0f
            var resultHeight = 0f
            
            when (widthMode) {
                YogaMeasureMode.UNDEFINED -> resultWidth = intrinsicWidth
                YogaMeasureMode.EXACTLY -> resultWidth = width
                YogaMeasureMode.AT_MOST -> resultWidth = minOf(width, intrinsicWidth)
            }
            
            when (heightMode) {
                YogaMeasureMode.UNDEFINED -> resultHeight = intrinsicHeight
                YogaMeasureMode.EXACTLY -> resultHeight = height
                YogaMeasureMode.AT_MOST -> resultHeight = minOf(height, intrinsicHeight)
            }
            
            YogaMeasureOutput.make(resultWidth, resultHeight)
        }
    }
    
    // MARK: - Equals/HashCode
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is DCFShadowNode) return false
        return viewId == other.viewId
    }
    
    override fun hashCode(): Int {
        return viewId
    }
}

