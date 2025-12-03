/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga

/**
 * ShadowView tree mirrors DCF view tree. Every node is highly stateful.
 * 1. A node is in one of three lifecycles: uninitialized, computed, dirtied.
 * 2. DCFBridge may call any of the padding/margin/width/height/top/left setters. A setter would dirty
 *    the node and all of its ancestors.
 * 3. At the end of each Bridge transaction, we call collectUpdatedFrames:widthConstraint:heightConstraint
 *    at the root node to recursively lay out the entire hierarchy.
 * 4. If a node is "computed" and the constraint passed from above is identical to the constraint used to
 *    perform the last computation, we skip laying out the subtree entirely.
 */
open class DCFShadowView: Hashable {
    
    // MARK: - Lifecycle
    
    enum UpdateLifecycle {
        case uninitialized
        case computed
        case dirtied
    }
    
    // MARK: - Properties
    
    public var viewId: Int
    public var viewName: String = ""
    public var backgroundColor: UIColor?
    public var onLayout: ((CGRect) -> Void)?
    
    /**
     * isNewView - Used to track the first time the view is introduced into the hierarchy.
     * It is initialized YES, then is set to NO after the layout pass is done and all frames
     * have been extracted to be applied to the corresponding UIViews.
     */
    public var isNewView: Bool = true
    
    /**
     * isHidden - DCFUIManager uses this to determine whether or not the UIView should be hidden.
     * Useful if the ShadowView determines that its UIView will be clipped and wants to hide it.
     */
    public var isHidden: Bool = false
    
    /**
     * Computed layout direction for the view backed to Yoga node value.
     */
    public var effectiveLayoutDirection: UIUserInterfaceLayoutDirection {
        let direction = YGNodeLayoutGetDirection(yogaNode)
        return direction == YGDirection.RTL ? .rightToLeft : .leftToRight
    }
    
    /**
     * Position and dimensions.
     * Defaults to { 0, 0, NAN, NAN }.
     */
    public var top: YGValue {
        get { YGNodeStyleGetPosition(yogaNode, YGEdge.top) }
        set { setYogaValue(newValue, setter: YGNodeStyleSetPosition, node: yogaNode, edge: YGEdge.top) }
    }
    
    public var left: YGValue {
        get { YGNodeStyleGetPosition(yogaNode, YGEdge.start) }
        set { setYogaValue(newValue, setter: YGNodeStyleSetPosition, node: yogaNode, edge: YGEdge.start) }
    }
    
    public var bottom: YGValue {
        get { YGNodeStyleGetPosition(yogaNode, YGEdge.bottom) }
        set { setYogaValue(newValue, setter: YGNodeStyleSetPosition, node: yogaNode, edge: YGEdge.bottom) }
    }
    
    public var right: YGValue {
        get { YGNodeStyleGetPosition(yogaNode, YGEdge.end) }
        set { setYogaValue(newValue, setter: YGNodeStyleSetPosition, node: yogaNode, edge: YGEdge.end) }
    }
    
    public var width: YGValue {
        get { YGNodeStyleGetWidth(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetWidth, setterPercent: YGNodeStyleSetWidthPercent, setterAuto: YGNodeStyleSetWidthAuto) }
    }
    
    public var height: YGValue {
        get { YGNodeStyleGetHeight(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetHeight, setterPercent: YGNodeStyleSetHeightPercent, setterAuto: YGNodeStyleSetHeightAuto) }
    }
    
    public var minWidth: YGValue {
        get { YGNodeStyleGetMinWidth(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetMinWidth, setterPercent: YGNodeStyleSetMinWidthPercent, setterAuto: nil) }
    }
    
    public var maxWidth: YGValue {
        get { YGNodeStyleGetMaxWidth(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetMaxWidth, setterPercent: YGNodeStyleSetMaxWidthPercent, setterAuto: nil) }
    }
    
    public var minHeight: YGValue {
        get { YGNodeStyleGetMinHeight(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetMinHeight, setterPercent: YGNodeStyleSetMinHeightPercent, setterAuto: nil) }
    }
    
    public var maxHeight: YGValue {
        get { YGNodeStyleGetMaxHeight(yogaNode) }
        set { applyDimensionValue(node: yogaNode, value: newValue, setter: YGNodeStyleSetMaxHeight, setterPercent: YGNodeStyleSetMaxHeightPercent, setterAuto: nil) }
    }
    
    /**
     * Convenient alias to `width` and `height` in pixels.
     * Defaults to NAN in case of non-pixel dimension.
     */
    public var size: CGSize {
        get {
            let widthValue = YGNodeStyleGetWidth(yogaNode)
            let heightValue = YGNodeStyleGetHeight(yogaNode)
            return CGSize(
                width: widthValue.unit == YGUnit.point ? CGFloat(widthValue.value) : CGFloat.nan,
                height: heightValue.unit == YGUnit.point ? CGFloat(heightValue.value) : CGFloat.nan
            )
        }
        set {
            YGNodeStyleSetWidth(yogaNode, Float(newValue.width))
            YGNodeStyleSetHeight(yogaNode, Float(newValue.height))
        }
    }
    
    /**
     * Computed position of the view.
     * Made internal (not private) so subclasses like DCFScrollContentShadowView can modify it
     */
    public internal(set) var frame: CGRect = CGRect(x: 0, y: 0, width: CGFloat.nan, height: CGFloat.nan)
    
    /**
     * Available size for children (frame size minus compound insets)
     * Can be overridden by subclasses like DCFRootShadowView
     */
    public var availableSize: CGSize {
        let rect = CGRect(origin: .zero, size: frame.size)
        return rect.inset(by: compoundInsets).size
    }
    
    /**
     * Represents the natural size of the view, which is used when explicit size is not set or is ambiguous.
     * Defaults to `{UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric}`.
     * 
     * CRITICAL: This can only be set on leaf nodes (nodes with no children).
     * Nodes with children size based on their children, not intrinsic size.
     * Attempting to set this on a node with children will be silently ignored to prevent crashes.
     */
    private var _intrinsicContentSize: CGSize = CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    
    public var intrinsicContentSize: CGSize {
        get {
            return _intrinsicContentSize
        }
        set {
            // CRITICAL: Only allow setting intrinsicContentSize on leaf nodes (no children)
            // Nodes with children size based on their children, not intrinsic size
            // Attempting to set this on a node with children will cause Yoga to crash
            let childCount = YGNodeGetChildCount(yogaNode)
            guard childCount == 0 else {
                // Node has children - silently ignore the assignment to prevent crash
                // This can happen if registerView is called after children are attached
                return
            }
            
            _intrinsicContentSize = newValue
            
            // Set up measure function based on the new value
            // We do NOT call YGNodeMarkDirty here because:
            // 1. Yoga will automatically mark nodes dirty when needed during layout calculation
            // 2. Calling YGNodeMarkDirty on a node that might have children (even if childCount == 0 now)
            //    can cause crashes if children are added between the check and the mark
            // 3. The measure function will be called by Yoga when it needs to measure the node
            if newValue.width == UIView.noIntrinsicMetric && newValue.height == UIView.noIntrinsicMetric {
                YGNodeSetMeasureFunc(yogaNode, nil)
            } else {
                YGNodeSetMeasureFunc(yogaNode, shadowViewMeasure)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var _propagationLifecycle: UpdateLifecycle = .uninitialized
    private var _textLifecycle: UpdateLifecycle = .uninitialized
    private var _lastParentProperties: [String: Any]?
    private var _subviews: [DCFShadowView] = []
    private var _recomputePadding: Bool = false
    private var _recomputeMargin: Bool = false
    private var _recomputeBorder: Bool = false
    private var _didUpdateSubviews: Bool = false
    
    private var _paddingMetaProps: [MetaProp: YGValue] = [:]
    private var _marginMetaProps: [MetaProp: YGValue] = [:]
    private var _borderMetaProps: [MetaProp: YGValue] = [:]
    
    internal enum MetaProp: Int {
        case left = 0
        case top
        case right
        case bottom
        case horizontal
        case vertical
        case all
        case count
    }
    
    // MARK: - Parent-Child Relationships
    
    public private(set) weak var superview: DCFShadowView?
    public var subviews: [DCFShadowView] {
        return _subviews
    }
    
    // MARK: - Yoga Node
    
    public private(set) var yogaNode: YGNodeRef
    
    // MARK: - Yoga Config
    
    static var yogaConfig: YGConfigRef = {
        guard let config = YGConfigNew() else {
            fatalError("Failed to create Yoga config")
        }
        // Configure Yoga to match DCFlight's layout behavior
        YGConfigSetPointScaleFactor(config, 0.0)
        // Use legacy stretch behavior for compatibility
        // In newer Yoga versions, this is done via YGConfigSetErrata with YGErrataClassic
        // YGErrataClassic matches Yoga 1.x behavior including UseLegacyStretchBehaviour
        YGConfigSetErrata(config, YGErrata.classic)
        return config
    }()
    
    // MARK: - Initialization
    
    public required init(viewId: Int) {
        self.viewId = viewId
        
        // Initialize meta props
        for i in 0..<MetaProp.count.rawValue {
            _paddingMetaProps[MetaProp(rawValue: i)!] = YGValueUndefined
            _marginMetaProps[MetaProp(rawValue: i)!] = YGValueUndefined
            _borderMetaProps[MetaProp(rawValue: i)!] = YGValueUndefined
        }
        
        // Create Yoga node
        yogaNode = YGNodeNewWithConfig(Self.yogaConfig)
        YGNodeSetContext(yogaNode, Unmanaged.passUnretained(self).toOpaque())
    }
    
    deinit {
        YGNodeFree(yogaNode)
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
    public func canHaveSubviews() -> Bool {
        return true
    }
    
    /**
     * Returns whether or not this node acts as a leaf node in the eyes of Yoga.
     * For example `DCFShadowText` has children which it does not want Yoga
     * to lay out so in the eyes of Yoga it is a leaf node.
     * Defaults to `false`. Can be overridden in subclasses.
     */
    public func isYogaLeafNode() -> Bool {
        return false
    }
    
    public func insertSubview(_ subview: DCFShadowView, atIndex index: Int) {
        assert(canHaveSubviews(), "Attempt to insert subview inside leaf view.")
        
        // CRITICAL: Remove measure function and clear intrinsic content size BEFORE adding children
        // Yoga rule: Nodes with measure functions cannot have children
        // Nodes with children size based on their children, not intrinsic size
        if !isYogaLeafNode() {
            // Clear measure function first
            if YGNodeHasMeasureFunc(yogaNode) {
                YGNodeSetMeasureFunc(yogaNode, nil)
            }
            // Directly clear the stored intrinsic content size property
            // We cannot use the setter here because it checks childCount == 0,
            // but we're about to add a child, so we need to bypass the setter
            _intrinsicContentSize = CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
            
            // NOW add the child to the Yoga node
            YGNodeInsertChild(yogaNode, subview.yogaNode, index)
        }
        
        _subviews.insert(subview, at: index)
        subview.superview = self
        _didUpdateSubviews = true
        dirtyText()
        dirtyPropagation()
    }
    
    public func removeSubview(_ subview: DCFShadowView) {
        subview.dirtyText()
        subview.dirtyPropagation()
        _didUpdateSubviews = true
        subview.superview = nil
        _subviews.removeAll { $0 === subview }
        if !isYogaLeafNode() {
            YGNodeRemoveChild(yogaNode, subview.yogaNode)
        }
    }
    
    // MARK: - Lifecycle Management
    
    public func dirtyPropagation() {
        if _propagationLifecycle != .dirtied {
            _propagationLifecycle = .dirtied
            superview?.dirtyPropagation()
        }
    }
    
    public func isPropagationDirty() -> Bool {
        return _propagationLifecycle != .computed
    }
    
    public func dirtyText() {
        if _textLifecycle != .dirtied {
            _textLifecycle = .dirtied
            superview?.dirtyText()
        }
    }
    
    public func isTextDirty() -> Bool {
        return _textLifecycle != .computed
    }
    
    public func setTextComputed() {
        _textLifecycle = .computed
    }
    
    // MARK: - Layout
    
    open func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        if !YGNodeGetHasNewLayout(node) {
            return
        }
        
        assert(!YGNodeIsDirty(node), "Attempt to get layout metrics from dirtied Yoga node.")
        
        YGNodeSetHasNewLayout(node, false)
        
        if YGNodeStyleGetDisplay(node) == YGDisplay.none {
            // If the node is hidden (has `display: none;`), its (and its descendants)
            // layout metrics are invalid and/or dirtied, so we have to stop here.
            return
        }
        
        // Calculate frame from Yoga layout results
        // Position is relative to parent (YGNodeLayoutGetLeft/Top)
        // Size is calculated from absolute positions
        let absoluteTopLeft = CGPoint(
            x: absolutePosition.x + CGFloat(YGNodeLayoutGetLeft(node)),
            y: absolutePosition.y + CGFloat(YGNodeLayoutGetTop(node))
        )
        
        let absoluteBottomRight = CGPoint(
            x: absolutePosition.x + CGFloat(YGNodeLayoutGetLeft(node)) + CGFloat(YGNodeLayoutGetWidth(node)),
            y: absolutePosition.y + CGFloat(YGNodeLayoutGetTop(node)) + CGFloat(YGNodeLayoutGetHeight(node))
        )
        
        let newFrame = CGRect(
            x: roundPixelValue(CGFloat(YGNodeLayoutGetLeft(node))),
            y: roundPixelValue(CGFloat(YGNodeLayoutGetTop(node))),
            width: roundPixelValue(absoluteBottomRight.x - absoluteTopLeft.x),
            height: roundPixelValue(absoluteBottomRight.y - absoluteTopLeft.y)
        )
        
        // DEBUG: Log problematic frames (negative Y or zero height)
        if newFrame.origin.y < 0 || newFrame.size.height == 0 {
            let yogaLeft = YGNodeLayoutGetLeft(node)
            let yogaTop = YGNodeLayoutGetTop(node)
            let yogaWidth = YGNodeLayoutGetWidth(node)
            let yogaHeight = YGNodeLayoutGetHeight(node)
            print("⚠️ DCFShadowView: viewId=\(viewId) has problematic frame:")
            print("   Yoga values: left=\(yogaLeft), top=\(yogaTop), width=\(yogaWidth), height=\(yogaHeight)")
            print("   absolutePosition=\(absolutePosition)")
            print("   absoluteTopLeft=\(absoluteTopLeft), absoluteBottomRight=\(absoluteBottomRight)")
            print("   Calculated frame=\(newFrame)")
            print("   Parent frame=\(frame)")
        }
        
        if !frame.equalTo(newFrame) {
            frame = newFrame
            viewsWithNewFrame.add(self)
        }
        
        var newAbsolutePosition = absolutePosition
        newAbsolutePosition.x += CGFloat(YGNodeLayoutGetLeft(node))
        newAbsolutePosition.y += CGFloat(YGNodeLayoutGetTop(node))
        
        applyLayoutToChildren(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: newAbsolutePosition)
    }
    
    public func applyLayoutToChildren(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        let childCount = YGNodeGetChildCount(node)
        for i in 0..<Int(childCount) {
            if let childNode = YGNodeGetChild(node, i), i < _subviews.count {
                let child = _subviews[i]
                child.applyLayoutNode(childNode, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
            }
        }
    }
    
    public func didUpdateSubviews() {
        // Does nothing by default
    }
    
    // MARK: - Prop Processing
    
    /**
     * Called when props are set to process meta props (margin/padding/border).
     * Meta properties are composite properties that affect multiple edges (e.g., margin affects all sides).
     */
    public func didSetProps(_ changedProps: [String]) {
        if _recomputePadding {
            processMetaPropsPadding()
        }
        if _recomputeMargin {
            processMetaPropsMargin()
        }
        if _recomputeBorder {
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
    private func processMetaPropsPadding() {
        let node = yogaNode
        
        if let value = _paddingMetaProps[.left] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .start)
        }
        if let value = _paddingMetaProps[.right] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .end)
        }
        if let value = _paddingMetaProps[.top] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .top)
        }
        if let value = _paddingMetaProps[.bottom] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .bottom)
        }
        if let value = _paddingMetaProps[.horizontal] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .horizontal)
        }
        if let value = _paddingMetaProps[.vertical] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .vertical)
        }
        if let value = _paddingMetaProps[.all] {
            setYogaValue(value, setter: YGNodeStyleSetPadding, node: node, edge: .all)
        }
    }
    
    /**
     * Process margin meta props and apply to Yoga node.
     * Handles: margin, marginTop, marginRight, marginBottom, marginLeft,
     * marginHorizontal, marginVertical
     */
    private func processMetaPropsMargin() {
        let node = yogaNode
        
        if let value = _marginMetaProps[.left] {
            applyMarginValue(node: node, edge: .start, value: value)
        }
        if let value = _marginMetaProps[.right] {
            applyMarginValue(node: node, edge: .end, value: value)
        }
        if let value = _marginMetaProps[.top] {
            applyMarginValue(node: node, edge: .top, value: value)
        }
        if let value = _marginMetaProps[.bottom] {
            applyMarginValue(node: node, edge: .bottom, value: value)
        }
        if let value = _marginMetaProps[.horizontal] {
            applyMarginValue(node: node, edge: .horizontal, value: value)
        }
        if let value = _marginMetaProps[.vertical] {
            applyMarginValue(node: node, edge: .vertical, value: value)
        }
        if let value = _marginMetaProps[.all] {
            applyMarginValue(node: node, edge: .all, value: value)
        }
    }
    
    /**
     * Apply margin value to Yoga node, handling auto, undefined, point, and percent units.
     */
    private func applyMarginValue(node: YGNodeRef, edge: YGEdge, value: YGValue) {
        switch value.unit {
        case .auto:
            YGNodeStyleSetMarginAuto(node, edge)
        case .undefined:
            YGNodeStyleSetMargin(node, edge, Float.nan)
        case .point:
            YGNodeStyleSetMargin(node, edge, value.value)
        case .percent:
            YGNodeStyleSetMarginPercent(node, edge, value.value)
        }
        dirtyText()
    }
    
    /**
     * Process border meta props and apply to Yoga node.
     * Handles: borderWidth, borderTopWidth, borderRightWidth, borderBottomWidth, borderLeftWidth
     */
    private func processMetaPropsBorder() {
        let node = yogaNode
        
        if let value = _borderMetaProps[.left] {
            YGNodeStyleSetBorder(node, YGEdge.start, value.value)
        }
        if let value = _borderMetaProps[.right] {
            YGNodeStyleSetBorder(node, YGEdge.end, value.value)
        }
        if let value = _borderMetaProps[.top] {
            YGNodeStyleSetBorder(node, YGEdge.top, value.value)
        }
        if let value = _borderMetaProps[.bottom] {
            YGNodeStyleSetBorder(node, YGEdge.bottom, value.value)
        }
        if let value = _borderMetaProps[.horizontal] {
            YGNodeStyleSetBorder(node, YGEdge.horizontal, value.value)
        }
        if let value = _borderMetaProps[.vertical] {
            YGNodeStyleSetBorder(node, YGEdge.vertical, value.value)
        }
        if let value = _borderMetaProps[.all] {
            YGNodeStyleSetBorder(node, YGEdge.all, value.value)
        }
    }
    
    /**
     * Store meta prop value for later processing.
     * Called by YogaShadowTree when layout props are updated.
     */
    internal func storeMetaProp(_ prop: MetaProp, value: YGValue, type: MetaPropType) {
        switch type {
        case .padding:
            _paddingMetaProps[prop] = value
            _recomputePadding = true
        case .margin:
            _marginMetaProps[prop] = value
            _recomputeMargin = true
        case .border:
            _borderMetaProps[prop] = value
            _recomputeBorder = true
        }
    }
    
    internal enum MetaPropType {
        case padding
        case margin
        case border
    }
    
    // MARK: - Helper Functions
    
    private func roundPixelValue(_ value: CGFloat) -> CGFloat {
        return round(value * UIScreen.main.scale) / UIScreen.main.scale
    }
    
    private func setYogaValue(_ value: YGValue, setter: (YGNodeRef, YGEdge, Float) -> Void, node: YGNodeRef, edge: YGEdge) {
        switch value.unit {
        case .auto, .undefined:
            setter(node, edge, Float.nan)
        case .point:
            setter(node, edge, value.value)
        case .percent:
            YGNodeStyleSetPositionPercent(node, edge, value.value)
        }
        dirtyText()
    }
    
    /**
     * Apply dimension value (width/height) to Yoga node, handling auto, undefined, point, and percent units.
     * Used for properties that don't have an edge parameter.
     */
    private func applyDimensionValue(
        node: YGNodeRef,
        value: YGValue,
        setter: (YGNodeRef, Float) -> Void,
        setterPercent: (YGNodeRef, Float) -> Void,
        setterAuto: ((YGNodeRef) -> Void)?
    ) {
        switch value.unit {
        case .auto:
            if let autoSetter = setterAuto {
                autoSetter(node)
            } else {
            setter(node, Float.nan)
            }
        case .undefined:
            setter(node, Float.nan)
        case .point:
            setter(node, value.value)
        case .percent:
            setterPercent(node, value.value)
        }
        dirtyText()
    }
    
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(viewId)
    }
    
    public static func == (lhs: DCFShadowView, rhs: DCFShadowView) -> Bool {
        return lhs.viewId == rhs.viewId
    }
}

// MARK: - Yoga Measure Function

private func shadowViewMeasure(node: YGNodeRef?, width: Float, widthMode: YGMeasureMode, height: Float, heightMode: YGMeasureMode) -> YGSize {
    guard let node = node else {
        return YGSize(width: 0, height: 0)
    }
    guard let context = YGNodeGetContext(node) else {
        return YGSize(width: 0, height: 0)
    }
    
    let shadowView = Unmanaged<DCFShadowView>.fromOpaque(context).takeUnretainedValue()
    var intrinsicContentSize = shadowView.intrinsicContentSize
    
    // Replace `UIViewNoIntrinsicMetric` (which equals `-1`) with zero.
    intrinsicContentSize.width = max(0, intrinsicContentSize.width)
    intrinsicContentSize.height = max(0, intrinsicContentSize.height)
    
    var result = YGSize(width: 0, height: 0)
    
    switch widthMode {
    case .undefined:
        result.width = Float(intrinsicContentSize.width)
    case .exactly:
        result.width = width
    case .atMost:
        result.width = min(width, Float(intrinsicContentSize.width))
    }
    
    switch heightMode {
    case .undefined:
        result.height = Float(intrinsicContentSize.height)
    case .exactly:
        result.height = height
    case .atMost:
        result.height = min(height, Float(intrinsicContentSize.height))
    }
    
    return result
}


