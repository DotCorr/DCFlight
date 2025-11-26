/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// Low-level viewport detection system - similar to web IntersectionObserver
/// Any view can register for viewport visibility callbacks
class DCFViewportObserver {
    static let shared = DCFViewportObserver()
    
    private var observedViews: [UIView: ViewportConfig] = [:]
    private var scrollViewObservers: [UIScrollView: Set<UIView>] = [:]
    
    private init() {}
    
    /// Register a view for viewport detection
    func observe(_ view: UIView, config: ViewportConfig) {
        observedViews[view] = config
        
        // Find parent scroll view
        if let scrollView = findParentScrollView(view) {
            if scrollViewObservers[scrollView] == nil {
                scrollViewObservers[scrollView] = Set<UIView>()
                setupScrollObserver(scrollView)
            }
            scrollViewObservers[scrollView]?.insert(view)
        } else {
            // No scroll view - check initial visibility
            checkVisibility(view, config: config)
        }
    }
    
    /// Unregister a view
    func unobserve(_ view: UIView) {
        observedViews.removeValue(forKey: view)
        
        // Remove from scroll view observers
        for (scrollView, views) in scrollViewObservers {
            if views.contains(view) {
                scrollViewObservers[scrollView]?.remove(view)
                if scrollViewObservers[scrollView]?.isEmpty == true {
                    scrollViewObservers.removeValue(forKey: scrollView)
                }
            }
        }
    }
    
    /// Find parent scroll view
    private func findParentScrollView(_ view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while current != nil {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            current = current?.superview
        }
        return nil
    }
    
    /// Setup scroll observer for a scroll view
    private func setupScrollObserver(_ scrollView: UIScrollView) {
        // Listen for scroll notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DCFScrollViewDidScroll"),
            object: scrollView,
            queue: .main
        ) { [weak self] _ in
            self?.checkViewsInScrollView(scrollView)
        }
        
        // Also check on initial setup
        DispatchQueue.main.async { [weak self] in
            self?.checkViewsInScrollView(scrollView)
        }
    }
    
    /// Check visibility of views in a scroll view
    private func checkViewsInScrollView(_ scrollView: UIScrollView) {
        guard let views = scrollViewObservers[scrollView] else { return }
        
        for view in views {
            if let config = observedViews[view] {
                checkVisibility(view, inScrollView: scrollView, config: config)
            }
        }
    }
    
    /// Check if view is visible (no scroll view)
    private func checkVisibility(_ view: UIView, config: ViewportConfig) {
        guard let window = view.window else { return }
        
        let viewFrame = view.convert(view.bounds, to: window)
        let windowBounds = window.bounds
        
        let isVisible = viewFrame.intersects(windowBounds)
        let intersectionRatio = calculateIntersectionRatio(viewFrame, windowBounds)
        
        handleVisibilityChange(view, isVisible: isVisible, ratio: intersectionRatio, config: config)
    }
    
    /// Check if view is visible in scroll view
    private func checkVisibility(_ view: UIView, inScrollView scrollView: UIScrollView, config: ViewportConfig) {
        let scrollViewBounds = scrollView.bounds
        let viewFrame = view.convert(view.bounds, to: scrollView)
        
        let isVisible = viewFrame.intersects(scrollViewBounds)
        let intersectionRatio = calculateIntersectionRatio(viewFrame, scrollViewBounds)
        
        handleVisibilityChange(view, isVisible: isVisible, ratio: intersectionRatio, config: config)
    }
    
    /// Calculate intersection ratio (0.0 to 1.0)
    private func calculateIntersectionRatio(_ viewFrame: CGRect, _ containerBounds: CGRect) -> CGFloat {
        let intersection = viewFrame.intersection(containerBounds)
        if intersection.isNull {
            return 0.0
        }
        
        let viewArea = viewFrame.width * viewFrame.height
        if viewArea == 0 {
            return 0.0
        }
        
        let intersectionArea = intersection.width * intersection.height
        return intersectionArea / viewArea
    }
    
    /// Handle visibility change
    private func handleVisibilityChange(_ view: UIView, isVisible: Bool, ratio: CGFloat, config: ViewportConfig) {
        // Check threshold
        let threshold = config.amount ?? 0.0
        let meetsThreshold = ratio >= CGFloat(threshold)
        
        // Get current state
        let wasVisible = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewportVisible".hashValue)!) as? Bool ?? false
        
        if isVisible && meetsThreshold && !wasVisible {
            // Entered viewport
            objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewportVisible".hashValue)!, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            propagateEvent(on: view, eventName: "onViewportEnter", data: [
                "intersectionRatio": ratio,
                "isIntersecting": true
            ])
        } else if (!isVisible || !meetsThreshold) && wasVisible {
            // Left viewport
            if !config.once {
                objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewportVisible".hashValue)!, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                propagateEvent(on: view, eventName: "onViewportLeave", data: [
                    "intersectionRatio": ratio,
                    "isIntersecting": false
                ])
            }
        }
    }
}

struct ViewportConfig {
    let once: Bool
    let amount: Double? // 0.0 to 1.0
}

