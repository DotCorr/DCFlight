/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import dcflight

// Static pointer key for storing ScrollView reference on contentView
// Shared between DCFScrollView and DCFScrollContentViewComponent
// Using a global variable ensures both files use the same memory address
internal var ScrollViewKey: UInt8 = 0

/**
 * Custom UIScrollView subclass that limits certain default UIKit behaviors
 * to ensure proper integration with DCFlight's layout system.
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
    
    // Override contentOffset property setter
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
    
    // Override frame property setter
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            // Preserving and revalidating contentOffset
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
 * DCFScrollView - Main ScrollView class
 * 
 * The ScrollView may have at most one single subview (contentView). This ensures
 * that the scroll view's contentSize will be efficiently set to the size of the
 * single subview's frame. That frame size will be determined efficiently since
 * it will have already been computed by the off-main-thread layout system (Yoga).
 */
@objc public class DCFScrollView: UIView, DCFScrollableProtocol, DCFAutoInsetsProtocol, UIScrollViewDelegate {
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
    
    // MARK: - Content Size Management
    
    /**
     * Once you set the contentSize, to a nonzero value, it is assumed to be
     * managed by you, and we'll never automatically compute the size for you,
     * unless you manually reset it back to {0, 0}
     * 
     * contentSize is determined by contentView.frame.size
     */
    @objc public var contentSize: CGSize {
        get {
            if !CGSizeEqualToSize(_scrollView.contentSize, .zero) {
                return _scrollView.contentSize
            }
            // Use contentView.frame.size directly
            // Yoga has already calculated this, so we just use it
            return _contentView?.frame.size ?? .zero
        }
    }
    
    /**
     * Update contentSize from contentView.frame.size
     * Called after layout is complete
     * 
     * KEY INSIGHT: We use contentView.frame.size directly because
     * ScrollContentView is laid out by Yoga. Yoga calculates the frame.size based on
     * the children's layout, so we just use it directly.
     */
    public func updateContentSizeFromContentView() {
        guard let contentView = _contentView else {
            _scrollView.contentSize = .zero
            return
        }
        
        // CRITICAL: If frame is zero, try to restore it from pendingFrame
        // This handles the case where applyLayout hasn't run yet or the frame was reset
        if contentView.frame.width == 0 || contentView.frame.height == 0 {
            let pendingFrameValue = objc_getAssociatedObject(contentView,
                                                              UnsafeRawPointer(bitPattern: "pendingFrame".hashValue)!) as? NSValue
            if let pendingFrame = pendingFrameValue?.cgRectValue, pendingFrame.width > 0 && pendingFrame.height > 0 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                contentView.frame = pendingFrame
                CATransaction.commit()
                contentView.setNeedsLayout()
                contentView.layoutIfNeeded()
            }
        }
        
        // Use contentView.frame.size directly
        // ScrollContentView is in the Yoga tree, so Yoga has already calculated its size
        // DCFScrollContentViewComponent.applyLayout sets contentView.frame from Yoga layout
        let contentSize = contentView.frame.size
        
        if !CGSizeEqualToSize(_scrollView.contentSize, contentSize) {
            // When contentSize is set manually, ScrollView internals will reset
            // contentOffset to {0, 0}. Since we potentially set contentSize whenever
            // anything in the ScrollView updates, we workaround this issue by manually
            // adjusting contentOffset whenever this happens
            let newOffset = calculateOffsetForContentSize(contentSize)
            _scrollView.contentSize = contentSize
            _scrollView.contentOffset = newOffset
        }
    }
    
    /**
     * Calculate offset for new content size (preserving scroll position when possible)
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
     * Insert a subview (DCFScrollView may only contain a single subview)
     * 
     * If a contentView already exists, remove it first before adding the new one.
     * This handles the case where ScrollContentView component is replaced or re-attached.
     */
    public func insertContentView(_ view: UIView) {
        // Remove existing contentView if it exists and is different
        // This prevents assertion errors when ScrollContentView is re-attached or replaced
        if let existingContentView = _contentView, existingContentView != view {
            existingContentView.removeFromSuperview()
            _contentView = nil
        }
        
        // Assert that we don't already have this exact view (shouldn't happen, but safety check)
        assert(_contentView == nil || _contentView == view, "DCFScrollView may only contain a single subview")
        
        // If this is the same view, we're done (already attached)
        if _contentView == view {
            return
        }
        
        // CRITICAL: Get the frame that should be restored after addSubview
        // UIKit resets the frame to zero when adding a view to a superview
        let pendingFrameValue = objc_getAssociatedObject(view,
                                                          UnsafeRawPointer(bitPattern: "pendingFrame".hashValue)!) as? NSValue
        let pendingFrame = pendingFrameValue?.cgRectValue
        let frameBeforeAdd = view.frame
        
        _contentView = view
        
        // CRITICAL: Store reference to this DCFScrollView on the contentView
        // This allows applyLayout to find the ScrollView even if superview is nil
        // Use static pointer key and RETAIN to ensure the reference persists
        // Note: This creates a retain cycle (ScrollView -> contentView -> ScrollView), but that's intentional
        // The ScrollView owns the contentView, so this cycle is broken when ScrollView is deallocated
        objc_setAssociatedObject(view,
                                 &ScrollViewKey,
                                 self,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Verify the stored reference was set correctly
        let storedRef = objc_getAssociatedObject(view, &ScrollViewKey) as? DCFScrollView
        
        _scrollView.addSubview(view)
        
        // CRITICAL: Restore frame immediately after addSubview
        // UIKit resets the frame when adding to superview, so we restore it from the stored value
        // Priority: 1) pendingFrame (from applyLayout), 2) frameBeforeAdd (if valid)
        let frameToRestore: CGRect?
        if let frame = pendingFrame, frame.width > 0 && frame.height > 0 {
            frameToRestore = frame
        } else if frameBeforeAdd.width > 0 && frameBeforeAdd.height > 0 {
            frameToRestore = frameBeforeAdd
        } else {
            frameToRestore = nil
        }
        
        if let frame = frameToRestore {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            view.frame = frame
            CATransaction.commit()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            // Update contentSize immediately since frame is valid
            updateContentSizeFromContentView()
        } else {
            // Set a flag so applyLayout knows to restore the frame and update contentSize
            objc_setAssociatedObject(view,
                                     UnsafeRawPointer(bitPattern: "needsFrameRestore".hashValue)!,
                                     NSNumber(booleanLiteral: true),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        print("✅ DCFScrollView.insertContentView: Added view to _scrollView, finalFrame=\(view.frame), superview=\(view.superview?.description ?? "nil")")
    }
    
    /**
     * Remove a subview
     * CRASH PROTECTION: Convert assertion to warning to prevent app crashes
     */
    public func removeContentView(_ subview: UIView) {
        if _contentView != subview {
            print("⚠️ DCFScrollView.removeContentView: Attempted to remove non-existent subview. Expected: \(String(describing: _contentView?.description)), Got: \(subview.description)")
            // Don't crash - just return if it's not the contentView
            return
        }
        subview.removeFromSuperview()
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
        
        // CRASH PROTECTION: Convert assertions to warnings to prevent app crashes
        // React Native-style error handling - log errors instead of crashing
        if self.subviews.count != 1 {
            print("⚠️ DCFScrollView.layoutSubviews: Expected 1 subview, got \(self.subviews.count). This may indicate a reconciliation issue.")
            // Try to recover by removing extra subviews
            while self.subviews.count > 1 {
                self.subviews[0].removeFromSuperview()
            }
        }
        
        if self.subviews.count > 0 && self.subviews.last != _scrollView {
            print("⚠️ DCFScrollView.layoutSubviews: Expected _scrollView as last subview, got \(type(of: self.subviews.last ?? UIView())). Attempting to fix...")
            // Try to recover by ensuring _scrollView is present
            if !self.subviews.contains(_scrollView) {
                _scrollView.removeFromSuperview()
                self.addSubview(_scrollView)
            }
        }
        
        // Only proceed if we have valid structure
        guard self.subviews.count == 1, self.subviews.last == _scrollView else {
            print("❌ DCFScrollView.layoutSubviews: Invalid structure, skipping contentSize update")
            return
        }
        
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
    
    // MARK: - Property Setters
    
    // Note: setting several properties of UIScrollView has the effect of
    // resetting its contentOffset to {0, 0}. To prevent this, we generate
    // setters here that will record the contentOffset beforehand, and
    // restore it after the property has been set
    
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
    
    // MARK: - DCFAutoInsetsProtocol
    
    /**
     * Refresh content insets based on layout guides.
     * Called automatically by DCFWrapperViewController when layout guides change.
     */
    public func refreshContentInset() {
        UIView.autoAdjustInsets(
            for: self,
            with: _scrollView,
            updateOffset: true
        )
    }
}
