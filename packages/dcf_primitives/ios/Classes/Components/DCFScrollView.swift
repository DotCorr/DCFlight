/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/**
 * Custom UIScrollView subclass (1:1 with React Native's RCTCustomScrollView)
 * Limits certain default UIKit behaviors
 */
class DCFCustomScrollView: UIScrollView {
    var centerContent: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        delaysContentTouches = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Override contentOffset property setter (React Native pattern)
    override var contentOffset: CGPoint {
        get {
            return super.contentOffset
        }
        set {
            if let scrollView = self.superview as? DCFScrollView {
                let contentView = scrollView.contentView
                if centerContent && contentView != nil {
                    let subviewSize = contentView!.frame.size
                    let scrollViewSize = self.bounds.size
                    var adjustedOffset = newValue
                    
                    if subviewSize.width <= scrollViewSize.width {
                        adjustedOffset.x = -(scrollViewSize.width - subviewSize.width) / 2.0
                    }
                    if subviewSize.height <= scrollViewSize.height {
                        adjustedOffset.y = -(scrollViewSize.height - subviewSize.height) / 2.0
                    }
                    super.contentOffset = adjustedOffset
                    return
                }
            }
            super.contentOffset = newValue
        }
    }
    
    // Override frame property setter (React Native pattern)
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            // Preserving and revalidating contentOffset (React Native pattern)
            let originalOffset = self.contentOffset
            super.frame = newValue
            
            let contentInset = self.contentInset
            let contentSize = self.contentSize
            let fullContentSize = CGSize(
                width: contentSize.width + contentInset.left + contentInset.right,
                height: contentSize.height + contentInset.top + contentInset.bottom
            )
            
            let boundsSize = self.bounds.size
            
            self.contentOffset = CGPoint(
                x: max(0, min(originalOffset.x, fullContentSize.width - boundsSize.width)),
                y: max(0, min(originalOffset.y, fullContentSize.height - boundsSize.height))
            )
        }
    }
}

/**
 * DCFScrollView - Main ScrollView class (1:1 with React Native's RCTScrollView)
 * 
 * The ScrollView may have at most one single subview (contentView). This ensures
 * that the scroll view's contentSize will be efficiently set to the size of the
 * single subview's frame. That frame size will be determined efficiently since
 * it will have already been computed by the off-main-thread layout system (Yoga).
 */
@objc public class DCFScrollView: UIView, DCFScrollableProtocol, UIScrollViewDelegate {
    private var _scrollView: DCFCustomScrollView
    private var _contentView: UIView?
    private var _lastScrollDispatchTime: TimeInterval = 0
    private var _allowNextScrollNoMatterWhat: Bool = false
    private var _scrollEventThrottle: TimeInterval = 0.0
    private var _coalescingKey: UInt16 = 0
    private var _lastEmittedEventName: String?
    private var _scrollListeners: NSHashTable<UIScrollViewDelegate> = NSHashTable<UIScrollViewDelegate>.weakObjects()
    
    // Props
    public var centerContent: Bool = false {
        didSet {
            _scrollView.centerContent = centerContent
        }
    }
    
    public var scrollEventThrottle: TimeInterval {
        get { return _scrollEventThrottle }
        set { _scrollEventThrottle = newValue }
    }
    
    public var contentInset: UIEdgeInsets = .zero {
        didSet {
            if !UIEdgeInsetsEqualToEdgeInsets(contentInset, oldValue) {
                let contentOffset = _scrollView.contentOffset
                _scrollView.contentInset = contentInset
                _scrollView.contentOffset = contentOffset
            }
        }
    }
    
    public var automaticallyAdjustContentInsets: Bool = true
    
    override init(frame: CGRect) {
        _scrollView = DCFCustomScrollView(frame: .zero)
        _scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _scrollView.delegate = nil // Will be set after initialization
        _scrollView.delaysContentTouches = false
        
        if #available(iOS 11.0, *) {
            _scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        super.init(frame: frame)
        
        _scrollView.delegate = self
        addSubview(_scrollView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        _scrollView.delegate = nil
    }
    
    // MARK: - Public Properties
    
    public var scrollView: UIScrollView {
        return _scrollView
    }
    
    @objc public var contentView: UIView? {
        return _contentView
    }
    
    // MARK: - Content Size Management (React Native Pattern)
    
    /**
     * Once you set the contentSize, to a nonzero value, it is assumed to be
     * managed by you, and we'll never automatically compute the size for you,
     * unless you manually reset it back to {0, 0}
     * 
     * React Native pattern: contentSize is determined by contentView.frame.size
     */
    public var contentSize: CGSize {
        if !CGSizeEqualToSize(_scrollView.contentSize, .zero) {
            return _scrollView.contentSize
        }
        // React Native pattern: Use contentView.frame.size directly
        // Yoga has already calculated this, so we just use it
        return _contentView?.frame.size ?? .zero
    }
    
    /**
     * React Native pattern: Update contentSize from contentView.frame.size
     * Called after layout is complete (equivalent to reactBridgeDidFinishTransaction)
     * 
     * KEY INSIGHT: React Native doesn't measure children manually - it uses contentView.frame.size
     * which Yoga has already calculated. However, since contentView is not in the Yoga tree,
     * we need to calculate its size from the bounding box of its children.
     */
    public func updateContentSizeFromContentView() {
        guard let contentView = _contentView else {
            _scrollView.contentSize = .zero
            return
        }
        
        // React Native pattern: Calculate contentSize from direct children only
        // In React Native, ScrollContentView is laid out by Yoga, so we measure its direct children
        var minX: CGFloat = 0
        var minY: CGFloat = 0
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        var hasChildren = false
        
        // Only measure DIRECT children of contentView (not recursively)
        // Each child is already laid out by Yoga with its correct frame
        for subview in contentView.subviews {
            // Skip hidden views
            if subview.isHidden || subview.alpha <= 0 {
                continue
            }
            
            let frame = subview.frame
            
            // Skip invalid frames (including zero-sized frames that haven't been laid out yet)
            guard !frame.isNull && !frame.isInfinite && 
                  frame.width > 0 && frame.height > 0 else {
                continue
            }
            
            // Update bounding box
            if !hasChildren {
                minX = frame.minX
                minY = frame.minY
                maxX = frame.maxX
                maxY = frame.maxY
                hasChildren = true
            } else {
                minX = min(minX, frame.minX)
                minY = min(minY, frame.minY)
                maxX = max(maxX, frame.maxX)
                maxY = max(maxY, frame.maxY)
            }
        }
        
        let viewportSize = self.bounds.size
        let newContentSize: CGSize
        
        if hasChildren {
            // React Native pattern: contentView starts at (0,0) and contains all children
            // Content size should be the maximum extent needed to show all children
            // If children span from y=minY to y=maxY, contentSize.height = maxY (not maxY - minY)
            // because contentView starts at y=0, so if a child is at y=100, that's 100 points from top
            // and if the last child ends at y=300, contentSize.height should be 300
            
            // Handle negative coordinates (shouldn't happen in normal layout, but be safe)
            let adjustedMinX = min(0, minX)
            let adjustedMinY = min(0, minY)
            
            // Content dimensions: from adjusted origin (which might be negative) to maximum extent
            // If minY > 0, that's fine - it just means there's space at the top before first child
            // Content size should be maxY to ensure all children are scrollable
            let contentWidth = maxX - adjustedMinX
            let contentHeight = maxY - adjustedMinY
            
            // Content size must be at least viewport size to enable scrolling
            let finalWidth = max(contentWidth, viewportSize.width)
            let finalHeight = max(contentHeight, viewportSize.height)
            
            newContentSize = CGSize(width: finalWidth, height: finalHeight)
            
            // Update contentView frame to match content size (always at 0,0)
            contentView.frame = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
        } else {
            // No children - use viewport size
            newContentSize = viewportSize
            contentView.frame = CGRect(x: 0, y: 0, width: viewportSize.width, height: viewportSize.height)
        }
        
        if !CGSizeEqualToSize(_scrollView.contentSize, newContentSize) {
            // When contentSize is set manually, ScrollView internals will reset
            // contentOffset to {0, 0}. Since we potentially set contentSize whenever
            // anything in the ScrollView updates, we workaround this issue by manually
            // adjusting contentOffset whenever this happens (React Native pattern)
            let newOffset = calculateOffsetForContentSize(newContentSize)
            _scrollView.contentSize = newContentSize
            _scrollView.contentOffset = newOffset
        }
    }
    
    /**
     * Calculate offset for new content size (preserving scroll position when possible)
     * React Native pattern from RCTScrollView.m
     */
    private func calculateOffsetForContentSize(_ newContentSize: CGSize) -> CGPoint {
        let oldOffset = _scrollView.contentOffset
        var newOffset = oldOffset
        
        let oldContentSize = _scrollView.contentSize
        let viewportSize = self.bounds.size
        
        // If contentSize was zero (initial case), start at top
        if CGSizeEqualToSize(oldContentSize, .zero) {
            return .zero
        }
        
        // Vertical
        let fitsInViewportY = oldContentSize.height <= viewportSize.height && newContentSize.height <= viewportSize.height
        if newContentSize.height < oldContentSize.height && !fitsInViewportY {
            let offsetHeight = oldOffset.y + viewportSize.height
            if oldOffset.y < 0 {
                // Overscrolled on top, leave offset alone
            } else if offsetHeight > oldContentSize.height {
                // Overscrolled on the bottom, preserve overscroll amount
                newOffset.y = max(0, oldOffset.y - (oldContentSize.height - newContentSize.height))
            } else if offsetHeight > newContentSize.height {
                // Offset falls outside of bounds, scroll back to end of list
                newOffset.y = max(0, newContentSize.height - viewportSize.height)
            }
        }
        
        // Horizontal
        let fitsInViewportX = oldContentSize.width <= viewportSize.width && newContentSize.width <= viewportSize.width
        if newContentSize.width < oldContentSize.width && !fitsInViewportX {
            let offsetWidth = oldOffset.x + viewportSize.width
            if oldOffset.x < 0 {
                // Overscrolled at the beginning, leave offset alone
            } else if offsetWidth > oldContentSize.width && newContentSize.width > viewportSize.width {
                // Overscrolled at the end, preserve overscroll amount as much as possible
                newOffset.x = max(0, oldOffset.x - (oldContentSize.width - newContentSize.width))
            } else if offsetWidth > newContentSize.width {
                // Offset falls outside of bounds, scroll back to end
                newOffset.x = max(0, newContentSize.width - viewportSize.width)
            }
        }
        
        return newOffset
    }
    
    // MARK: - Child Management
    
    /**
     * Insert a subview (React Native pattern: RCTScrollView may only contain a single subview)
     */
    public func insertContentView(_ view: UIView) {
        assert(_contentView == nil, "DCFScrollView may only contain a single subview")
        _contentView = view
        _scrollView.addSubview(view)
    }
    
    /**
     * Remove a subview
     */
    public func removeContentView(_ subview: UIView) {
        assert(_contentView == subview, "Attempted to remove non-existent subview")
        _contentView = nil
    }
    
    // MARK: - DCFScrollableProtocol
    
    public func scrollToOffset(_ offset: CGPoint) {
        scrollToOffset(offset, animated: true)
    }
    
    public func scrollToOffset(_ offset: CGPoint, animated: Bool) {
        if !CGPointEqualToPoint(_scrollView.contentOffset, offset) {
            _allowNextScrollNoMatterWhat = true
            _scrollView.setContentOffset(offset, animated: animated)
        }
    }
    
    public func scrollToEnd(_ animated: Bool) {
        let isHorizontal = _scrollView.contentSize.width > self.frame.size.width
        var offset: CGPoint
        if isHorizontal {
            let offsetX = _scrollView.contentSize.width - _scrollView.bounds.size.width + _scrollView.contentInset.right
            offset = CGPoint(x: max(offsetX, 0), y: 0)
        } else {
            let offsetY = _scrollView.contentSize.height - _scrollView.bounds.size.height + _scrollView.contentInset.bottom
            offset = CGPoint(x: 0, y: max(offsetY, 0))
        }
        if !CGPointEqualToPoint(_scrollView.contentOffset, offset) {
            _allowNextScrollNoMatterWhat = true
            _scrollView.setContentOffset(offset, animated: animated)
        }
    }
    
    public func zoomToRect(_ rect: CGRect, animated: Bool) {
        _scrollView.zoom(to: rect, animated: animated)
    }
    
    public func addScrollListener(_ scrollListener: UIScrollViewDelegate) {
        _scrollListeners.add(scrollListener)
    }
    
    public func removeScrollListener(_ scrollListener: UIScrollViewDelegate) {
        _scrollListeners.remove(scrollListener)
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        assert(self.subviews.count == 1, "we should only have exactly one subview")
        assert(self.subviews.last == _scrollView, "our only subview should be a scrollview")
        
        // Update content size from contentView after layout
        updateContentSizeFromContentView()
    }
    
    // MARK: - UIScrollViewDelegate
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        _allowNextScrollNoMatterWhat = true
        sendScrollEvent("onScrollBeginDrag", scrollView: scrollView, userData: nil)
        
        for listener in _scrollListeners.allObjects {
            if listener.responds(to: #selector(UIScrollViewDelegate.scrollViewWillBeginDragging(_:))) {
                listener.scrollViewWillBeginDragging?(scrollView)
            }
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let userData: [String: Any] = [
            "willDecelerate": decelerate
        ]
        sendScrollEvent("onScrollEndDrag", scrollView: scrollView, userData: userData)
        
        for listener in _scrollListeners.allObjects {
            if listener.responds(to: #selector(UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:))) {
                listener.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        _allowNextScrollNoMatterWhat = true
        scrollViewDidScroll(scrollView)
        sendScrollEvent("onMomentumScrollEnd", scrollView: scrollView, userData: nil)
        
        for listener in _scrollListeners.allObjects {
            if listener.responds(to: #selector(UIScrollViewDelegate.scrollViewDidEndDecelerating(_:))) {
                listener.scrollViewDidEndDecelerating?(scrollView)
            }
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        _allowNextScrollNoMatterWhat = true
        scrollViewDidScroll(scrollView)
        sendScrollEvent("onMomentumScrollEnd", scrollView: scrollView, userData: nil)
        
        for listener in _scrollListeners.allObjects {
            if listener.responds(to: #selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation(_:))) {
                listener.scrollViewDidEndScrollingAnimation?(scrollView)
            }
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let now = CACurrentMediaTime()
        
        if _allowNextScrollNoMatterWhat ||
           (_scrollEventThrottle > 0 && _scrollEventThrottle < (now - _lastScrollDispatchTime)) {
            sendScrollEvent("onScroll", scrollView: scrollView, userData: nil)
            _lastScrollDispatchTime = now
            _allowNextScrollNoMatterWhat = false
        }
        
        for listener in _scrollListeners.allObjects {
            if listener.responds(to: #selector(UIScrollViewDelegate.scrollViewDidScroll(_:))) {
                listener.scrollViewDidScroll?(scrollView)
            }
        }
    }
    
    // MARK: - Event Sending
    
    private func sendScrollEvent(_ eventName: String, scrollView: UIScrollView, userData: [String: Any]?) {
        if _lastEmittedEventName != eventName {
            _coalescingKey += 1
            _lastEmittedEventName = eventName
        }
        
        var eventData: [String: Any] = [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ],
            "contentInset": [
                "top": scrollView.contentInset.top,
                "left": scrollView.contentInset.left,
                "bottom": scrollView.contentInset.bottom,
                "right": scrollView.contentInset.right
            ],
            "contentSize": [
                "width": scrollView.contentSize.width,
                "height": scrollView.contentSize.height
            ],
            "layoutMeasurement": [
                "width": scrollView.frame.size.width,
                "height": scrollView.frame.size.height
            ],
            "zoomScale": scrollView.zoomScale
        ]
        
        if let userData = userData {
            eventData.merge(userData) { (_, new) in new }
        }
        
        propagateEvent(on: self, eventName: eventName, data: eventData)
    }
    
    // MARK: - Property Setters (Preserve ContentOffset Pattern from React Native)
    
    // Note: setting several properties of UIScrollView has the effect of
    // resetting its contentOffset to {0, 0}. To prevent this, we generate
    // setters here that will record the contentOffset beforehand, and
    // restore it after the property has been set (React Native pattern)
    
    public func setAlwaysBounceHorizontal(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.alwaysBounceHorizontal = value
        _scrollView.contentOffset = contentOffset
    }
    
    public func setAlwaysBounceVertical(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.alwaysBounceVertical = value
        _scrollView.contentOffset = contentOffset
    }
    
    public func setBounces(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.bounces = value
        _scrollView.contentOffset = contentOffset
    }
    
    public func setScrollEnabled(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.isScrollEnabled = value
        _scrollView.contentOffset = contentOffset
    }
    
    public func setShowsHorizontalScrollIndicator(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.showsHorizontalScrollIndicator = value
        _scrollView.contentOffset = contentOffset
    }
    
    public func setShowsVerticalScrollIndicator(_ value: Bool) {
        let contentOffset = _scrollView.contentOffset
        _scrollView.showsVerticalScrollIndicator = value
        _scrollView.contentOffset = contentOffset
    }
}

