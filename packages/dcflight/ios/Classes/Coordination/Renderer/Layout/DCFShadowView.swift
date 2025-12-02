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
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetWidth, node: yogaNode) }
    }
    
    public var height: YGValue {
        get { YGNodeStyleGetHeight(yogaNode) }
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetHeight, node: yogaNode) }
    }
    
    public var minWidth: YGValue {
        get { YGNodeStyleGetMinWidth(yogaNode) }
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetMinWidth, node: yogaNode) }
    }
    
    public var maxWidth: YGValue {
        get { YGNodeStyleGetMaxWidth(yogaNode) }
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetMaxWidth, node: yogaNode) }
    }
    
    public var minHeight: YGValue {
        get { YGNodeStyleGetMinHeight(yogaNode) }
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetMinHeight, node: yogaNode) }
    }
    
    public var maxHeight: YGValue {
        get { YGNodeStyleGetMaxHeight(yogaNode) }
        set { setYogaValueAuto(newValue, setter: YGNodeStyleSetMaxHeight, node: yogaNode) }
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
     */
    public var intrinsicContentSize: CGSize = CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) {
        didSet {
            if intrinsicContentSize.width == UIView.noIntrinsicMetric && intrinsicContentSize.height == UIView.noIntrinsicMetric {
                YGNodeSetMeasureFunc(yogaNode, nil)
            } else {
                YGNodeSetMeasureFunc(yogaNode, shadowViewMeasure)
            }
            YGNodeMarkDirty(yogaNode)
        }
    }
    
    // MARK: - Private Properties
    
    private var _propagationLifecycle: UpdateLifecycle = .uninitialized
    private var _textLifecycle: UpdateLifecycle = .uninitialized
    private var _lastParentProperties: [String: Any]?
    private var _reactSubviews: [DCFShadowView] = []
    private var _recomputePadding: Bool = false
    private var _recomputeMargin: Bool = false
    private var _recomputeBorder: Bool = false
    private var _didUpdateSubviews: Bool = false
    
    private var _paddingMetaProps: [MetaProp: YGValue] = [:]
    private var _marginMetaProps: [MetaProp: YGValue] = [:]
    private var _borderMetaProps: [MetaProp: YGValue] = [:]
    
    private enum MetaProp: Int {
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
    public var reactSubviews: [DCFShadowView] {
        return _reactSubviews
    }
    
    public var reactSuperview: DCFShadowView? {
        return superview
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
    
    public func insertReactSubview(_ subview: DCFShadowView, atIndex index: Int) {
        assert(canHaveSubviews(), "Attempt to insert subview inside leaf view.")
        
        // CRITICAL: Remove measure function before adding children
        // Yoga rule: Nodes with measure functions cannot have children
        if !isYogaLeafNode() {
            if YGNodeHasMeasureFunc(yogaNode) {
                YGNodeSetMeasureFunc(yogaNode, nil)
            }
            YGNodeInsertChild(yogaNode, subview.yogaNode, index)
        }
        
        _reactSubviews.insert(subview, at: index)
        subview.superview = self
        _didUpdateSubviews = true
        dirtyText()
        dirtyPropagation()
    }
    
    public func removeReactSubview(_ subview: DCFShadowView) {
        subview.dirtyText()
        subview.dirtyPropagation()
        _didUpdateSubviews = true
        subview.superview = nil
        _reactSubviews.removeAll { $0 === subview }
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
            if let childNode = YGNodeGetChild(node, i), i < _reactSubviews.count {
                let child = _reactSubviews[i]
                child.applyLayoutNode(childNode, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
            }
        }
    }
    
    public func didUpdateReactSubviews() {
        // Does nothing by default
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
    
    private func setYogaValueAuto(_ value: YGValue, setter: (YGNodeRef, Float) -> Void, node: YGNodeRef) {
        switch value.unit {
        case .auto:
            setter(node, Float.nan)
        case .undefined:
            setter(node, Float.nan)
        case .point:
            setter(node, value.value)
        case .percent:
            break
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


