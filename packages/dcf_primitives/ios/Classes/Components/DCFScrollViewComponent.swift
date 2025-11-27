/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// Simple ScrollView implementation based on React Native's approach
/// Uses a content container view - content size is determined by container's size
class DCFScrollViewComponent: NSObject, DCFComponent, UIScrollViewDelegate {
    private static let sharedInstance = DCFScrollViewComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let scrollView = UIScrollView()
        scrollView.delegate = DCFScrollViewComponent.sharedInstance
        
        // Create content container - no constraints, Yoga will handle layout
        let contentView = UIView()
        scrollView.addSubview(contentView)
        
        // Store content view reference
        objc_setAssociatedObject(scrollView, 
                                 UnsafeRawPointer(bitPattern: "contentView".hashValue)!, 
                                 contentView, 
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Basic setup
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bounces = true
        
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        updateView(scrollView, withProps: props)
        scrollView.applyStyles(props: props)
        
        return scrollView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let scrollView = view as? UIScrollView else { return false }
        
        // Scroll indicators
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            scrollView.showsVerticalScrollIndicator = showsScrollIndicator
            scrollView.showsHorizontalScrollIndicator = showsScrollIndicator
        }
        
        // Bounces
        if let bounces = props["bounces"] as? Bool {
            scrollView.bounces = bounces
        }
        
        // Horizontal scrolling
        if let horizontal = props["horizontal"] as? Bool {
            if horizontal {
                scrollView.alwaysBounceHorizontal = true
                scrollView.alwaysBounceVertical = false
                scrollView.showsHorizontalScrollIndicator = scrollView.showsVerticalScrollIndicator
                scrollView.showsVerticalScrollIndicator = false
            } else {
                scrollView.alwaysBounceHorizontal = false
                scrollView.alwaysBounceVertical = true
                scrollView.showsHorizontalScrollIndicator = false
            }
        }
        
        // Paging
        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            scrollView.isPagingEnabled = pagingEnabled
        }
        
        // Scroll enabled
        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            scrollView.isScrollEnabled = scrollEnabled
        }
        
        // Content insets
        if let contentInset = props["contentInset"] as? [String: Any] {
            let top = (contentInset["top"] as? CGFloat) ?? 0
            let left = (contentInset["left"] as? CGFloat) ?? 0
            let bottom = (contentInset["bottom"] as? CGFloat) ?? 0
            let right = (contentInset["right"] as? CGFloat) ?? 0
            scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
        
        // Handle commands
        handleCommand(scrollView: scrollView, props: props)
        
        scrollView.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let scrollView = view as? UIScrollView,
              let contentView = objc_getAssociatedObject(scrollView, 
                                                         UnsafeRawPointer(bitPattern: "contentView".hashValue)!) as? UIView else {
            return
        }
        
        // Apply layout to scroll view
        scrollView.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        
        // Content view should match scroll view's width, height will be determined by children
        contentView.frame = CGRect(x: 0, y: 0, width: layout.width, height: layout.height)
        
        // Update content size after layout
        DispatchQueue.main.async {
            self.updateContentSize(scrollView: scrollView)
        }
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        guard let scrollView = view as? UIScrollView else { return }
        
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Update content size after children are added
        DispatchQueue.main.async {
            self.updateContentSize(scrollView: scrollView)
        }
    }
    
    /// Set children - route to content container instead of scroll view directly
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        guard let scrollView = view as? UIScrollView,
              let contentView = objc_getAssociatedObject(scrollView, 
                                                         UnsafeRawPointer(bitPattern: "contentView".hashValue)!) as? UIView else {
            return false
        }
        
        // Remove existing children from content view
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new children to content view
        for childView in childViews {
            contentView.addSubview(childView)
        }
        
        // Update content size after children are added
        DispatchQueue.main.async {
            self.updateContentSize(scrollView: scrollView)
        }
        
        return true
    }
    
    /// Update content size based on content container's size
    /// Simple approach: let Yoga layout children, then measure their bounds
    private func updateContentSize(scrollView: UIScrollView) {
        guard let contentView = objc_getAssociatedObject(scrollView, 
                                                        UnsafeRawPointer(bitPattern: "contentView".hashValue)!) as? UIView else {
            return
        }
        
        // Wait for layout to complete
        DispatchQueue.main.async {
            // Force layout pass
            contentView.setNeedsLayout()
            contentView.layoutIfNeeded()
            
            // Calculate bounding box of all children
            var minX: CGFloat = 0
            var minY: CGFloat = 0
            var maxX: CGFloat = scrollView.bounds.width
            var maxY: CGFloat = scrollView.bounds.height
            
            var hasChildren = false
            
            for subview in contentView.subviews {
                guard !subview.isHidden && subview.alpha > 0 else { continue }
                hasChildren = true
                
                let frame = subview.frame
                minX = min(minX, frame.minX)
                minY = min(minY, frame.minY)
                maxX = max(maxX, frame.maxX)
                maxY = max(maxY, frame.maxY)
            }
            
            if !hasChildren {
                // No children - use scroll view bounds
                let defaultSize = CGSize(width: scrollView.bounds.width, height: scrollView.bounds.height)
                if scrollView.contentSize != defaultSize {
                    scrollView.contentSize = defaultSize
                }
                return
            }
            
            // Content size is the bounding box
            let contentWidth = maxX - minX
            let contentHeight = maxY - minY
            
            // Ensure minimum size
            let finalWidth = max(contentWidth, scrollView.bounds.width)
            let finalHeight = max(contentHeight, scrollView.bounds.height)
            
            let newContentSize = CGSize(width: finalWidth, height: finalHeight)
            
            if scrollView.contentSize != newContentSize {
                scrollView.contentSize = newContentSize
                
                // Adjust content offset if content starts at negative position
                if minY < 0 && scrollView.contentOffset.y == 0 {
                    scrollView.contentOffset = CGPoint(x: 0, y: -minY)
                }
                
                // Notify Dart side
                propagateEvent(on: scrollView, eventName: "onContentSizeChange", data: [
                    "width": newContentSize.width,
                    "height": newContentSize.height
                ])
            }
        }
    }
    
    /// Handle commands
    private func handleCommand(scrollView: UIScrollView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any] else {
            return
        }
        
        if let scrollToPositionData = commandData["scrollToPosition"] as? [String: Any] {
            if let x = scrollToPositionData["x"] as? Double, let y = scrollToPositionData["y"] as? Double {
                let animated = scrollToPositionData["animated"] as? Bool ?? true
                scrollView.setContentOffset(CGPoint(x: CGFloat(x), y: CGFloat(y)), animated: animated)
            }
        }
        
        if let scrollToTopData = commandData["scrollToTop"] as? [String: Any] {
            let animated = scrollToTopData["animated"] as? Bool ?? true
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: animated)
        }
        
        if let scrollToBottomData = commandData["scrollToBottom"] as? [String: Any] {
            let animated = scrollToBottomData["animated"] as? Bool ?? true
            let bottomOffset = CGPoint(x: scrollView.contentOffset.x, 
                                     y: scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(bottomOffset, animated: animated)
        }
        
        if let flashScrollIndicators = commandData["flashScrollIndicators"] as? Bool, flashScrollIndicators {
            scrollView.flashScrollIndicators()
        }
        
        if let shouldUpdateContentSize = commandData["updateContentSize"] as? Bool, shouldUpdateContentSize {
            self.updateContentSize(scrollView: scrollView)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScrollBeginDrag", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ]
        ])
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        propagateEvent(on: scrollView, eventName: "onScrollEndDrag", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ],
            "willDecelerate": decelerate
        ])
        
        if !decelerate {
            propagateEvent(on: scrollView, eventName: "onScrollEnd", data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y
                ]
            ])
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScrollEnd", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ]
        ])
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScroll", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ],
            "contentSize": [
                "width": scrollView.contentSize.width,
                "height": scrollView.contentSize.height
            ],
            "layoutMeasurement": [
                "width": scrollView.bounds.width,
                "height": scrollView.bounds.height
            ]
        ])
        
        // Viewport detection
        DCFViewportObserver.shared.checkViewsInScrollView(scrollView)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize.zero
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

