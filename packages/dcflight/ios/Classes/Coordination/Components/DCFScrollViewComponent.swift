/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import dcflight

/**
 * DCFScrollViewComponent - Component manager
 * Manages creation and updates of DCFScrollView instances
 */
class DCFScrollViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let scrollView = DCFScrollView(frame: .zero)
        
        // Don't create contentView here
        // Wait for ScrollContentView component to be attached via attachView
        // This prevents the assertion error when insertContentView is called twice
        
        // Basic setup
        scrollView.scrollView.showsVerticalScrollIndicator = true
        scrollView.scrollView.showsHorizontalScrollIndicator = true
        scrollView.scrollView.bounces = true
        scrollView.scrollView.isScrollEnabled = true
        scrollView.setAlwaysBounceVertical(true)
        scrollView.setAlwaysBounceHorizontal(false)
        
        if #available(iOS 11.0, *) {
            scrollView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        updateView(scrollView, withProps: props)
        scrollView.applyStyles(props: props)
        
        return scrollView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let scrollView = view as? DCFScrollView else { return false }
        
        // Scroll indicators
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            scrollView.setShowsVerticalScrollIndicator(showsScrollIndicator)
            scrollView.setShowsHorizontalScrollIndicator(showsScrollIndicator)
        }
        
        // Bounces
        if let bounces = props["bounces"] as? Bool {
            scrollView.setBounces(bounces)
        }
        
        // Horizontal scrolling
        if let horizontal = props["horizontal"] as? Bool {
            if horizontal {
                scrollView.setAlwaysBounceHorizontal(true)
                scrollView.setAlwaysBounceVertical(false)
                scrollView.setShowsHorizontalScrollIndicator(scrollView.scrollView.showsVerticalScrollIndicator)
                scrollView.setShowsVerticalScrollIndicator(false)
            } else {
                scrollView.setAlwaysBounceHorizontal(false)
                scrollView.setAlwaysBounceVertical(true)
                scrollView.setShowsHorizontalScrollIndicator(false)
            }
        }
        
        // Paging
        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            let contentOffset = scrollView.scrollView.contentOffset
            scrollView.scrollView.isPagingEnabled = pagingEnabled
            scrollView.scrollView.contentOffset = contentOffset
        }
        
        // Scroll enabled
        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            scrollView.setScrollEnabled(scrollEnabled)
        }
        
        // Content insets
        if let contentInset = props["contentInset"] as? [String: Any] {
            let top = (contentInset["top"] as? CGFloat) ?? 0
            let left = (contentInset["left"] as? CGFloat) ?? 0
            let bottom = (contentInset["bottom"] as? CGFloat) ?? 0
            let right = (contentInset["right"] as? CGFloat) ?? 0
            scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
        
        // Center content
        if let centerContent = props["centerContent"] as? Bool {
            scrollView.centerContent = centerContent
        }
        
        // Scroll event throttle
        if let throttle = props["scrollEventThrottle"] as? Double {
            scrollView.scrollEventThrottle = throttle
        }
        
        // Handle commands
        handleCommand(scrollView: scrollView, props: props)
        
        scrollView.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let scrollView = view as? DCFScrollView else { return }
        
        // Apply layout to scroll view
        scrollView.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        
        // CRITICAL: Don't update contentSize here because ScrollContentView's layout hasn't been applied yet
        // Layouts are applied parent-first, so ScrollView's layout is applied before ScrollContentView's layout
        // ScrollContentViewComponent.applyLayout will trigger updateContentSizeFromContentView after it sets its frame
        // This ensures we read the correct frame size
        print("🔍 DCFScrollViewComponent.applyLayout: Applied frame=\(scrollView.frame), deferring contentSize update until ScrollContentView layout is applied")
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        guard let scrollView = view as? DCFScrollView else { return }
        
        objc_setAssociatedObject(view,
                                 UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                                 nodeId,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Update content size after children are added
        DispatchQueue.main.async {
            scrollView.updateContentSizeFromContentView()
        }
    }
    
    
    /// Handle commands
    private func handleCommand(scrollView: DCFScrollView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any] else {
            return
        }
        
        if let scrollToPositionData = commandData["scrollToPosition"] as? [String: Any] {
            if let x = scrollToPositionData["x"] as? Double, let y = scrollToPositionData["y"] as? Double {
                let animated = scrollToPositionData["animated"] as? Bool ?? true
                scrollView.scrollToOffset(CGPoint(x: CGFloat(x), y: CGFloat(y)), animated: animated)
            }
        }
        
        if let scrollToTopData = commandData["scrollToTop"] as? [String: Any] {
            let animated = scrollToTopData["animated"] as? Bool ?? true
            scrollView.scrollToOffset(CGPoint(x: scrollView.scrollView.contentOffset.x, y: 0), animated: animated)
        }
        
        if let scrollToBottomData = commandData["scrollToBottom"] as? [String: Any] {
            let animated = scrollToBottomData["animated"] as? Bool ?? true
            scrollView.scrollToEnd(animated)
        }
        
        if let flashScrollIndicators = commandData["flashScrollIndicators"] as? Bool, flashScrollIndicators {
            scrollView.scrollView.flashScrollIndicators()
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

