/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/**
 * DCFViewportComponent - Viewport component for measuring layout and detecting viewport visibility
 * 
 * Supports:
 * - measure() callback: Returns x, y, width, height, pageX, pageY
 * - measureInWindow() callback: Returns x, y, width, height in window coordinates
 * - onViewportEnter/onViewportLeave callbacks: Detects when view enters/leaves viewport
 */
class DCFViewportComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        
        // Enable clipping to ensure children respect bounds
        view.clipsToBounds = true
        
        // Store initial props
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!,
                                props.mapValues { $0 as Any? },
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        view.applyStyles(props: props)
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        // Enable clipping
        view.clipsToBounds = true
        
        // Store props in associated object (same pattern as DCFComponentProtocol)
        let existingProps = getStoredProps(from: view)
        let mergedProps = mergeProps(existingProps, with: props.mapValues { $0 as Any? })
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!,
                                mergedProps,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Setup viewport detection if callbacks are registered
        let hasViewportCallbacks = mergedProps["onViewportEnter"] != nil || mergedProps["onViewportLeave"] != nil
        if hasViewportCallbacks {
            // Viewport detection will be handled in viewRegisteredWithShadowTree after the view is laid out
        }
        
        view.applyStyles(props: mergedProps.compactMapValues { $0 })
        return true
    }
    
    /// Merge existing props with updates (same pattern as DCFComponentProtocol)
    private func mergeProps(_ existing: [String: Any?], with updates: [String: Any?]) -> [String: Any?] {
        var merged = existing
        for (key, value) in updates {
            if value == nil {
                merged.removeValue(forKey: key)
            } else {
                merged[key] = value
            }
        }
        return merged
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        
        // Trigger measure callbacks after layout
        triggerMeasureCallbacks(view)
    }
    
    /// Trigger measure() and measureInWindow() callbacks
    private func triggerMeasureCallbacks(_ view: UIView) {
        guard let viewId = getViewId(from: view) else { return }
        
        // Get stored props to check for callbacks
        let props = getStoredProps(from: view).compactMapValues { $0 }
        
        // measure() callback - viewport coordinates
        if props["onMeasure"] != nil {
            let measureData = getMeasureData(view)
            propagateEvent(
                on: view,
                eventName: "onMeasure",
                data: measureData
            )
        }
        
        // measureInWindow() callback - window coordinates
        if props["onMeasureInWindow"] != nil {
            let measureInWindowData = getMeasureInWindowData(view)
            propagateEvent(
                on: view,
                eventName: "onMeasureInWindow",
                data: measureInWindowData
            )
        }
    }
    
    /// Get measure data (viewport coordinates)
    private func getMeasureData(_ view: UIView) -> [String: Any] {
        // Convert view's frame to its superview's coordinate system (viewport)
        let frame = view.frame
        let superview = view.superview
        
        // Get position relative to superview (viewport)
        let x = frame.origin.x
        let y = frame.origin.y
        
        // Get position relative to window (page coordinates)
        var pageX: CGFloat = 0
        var pageY: CGFloat = 0
        
        if let window = view.window {
            let windowPoint = view.convert(CGPoint.zero, to: window)
            pageX = windowPoint.x
            pageY = windowPoint.y
        } else if let superview = superview {
            // Fallback: use superview's position if window is not available
            let superviewPoint = superview.convert(CGPoint.zero, to: nil)
            pageX = superviewPoint.x + x
            pageY = superviewPoint.y + y
        } else {
            pageX = x
            pageY = y
        }
        
        return [
            "x": x,
            "y": y,
            "width": frame.width,
            "height": frame.height,
            "pageX": pageX,
            "pageY": pageY,
        ]
    }
    
    /// Get measureInWindow data (window coordinates)
    private func getMeasureInWindowData(_ view: UIView) -> [String: Any] {
        let frame = view.frame
        
        // Get position relative to window
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if let window = view.window {
            let windowPoint = view.convert(CGPoint.zero, to: window)
            x = windowPoint.x
            y = windowPoint.y
        } else {
            // Fallback: use frame origin if window is not available
            x = frame.origin.x
            y = frame.origin.y
        }
        
        return [
            "x": x,
            "y": y,
            "width": frame.width,
            "height": frame.height,
        ]
    }
    
    private func getViewId(from view: UIView) -> Int? {
        // Find viewId by searching ViewRegistry
        for (viewId, viewInfo) in ViewRegistry.shared.registry {
            if viewInfo.view === view {
                return viewId
            }
        }
        return nil
    }
    
    private func getStoredProps(from view: UIView) -> [String: Any?] {
        // Get props from associated object (same pattern as DCFComponentProtocol)
        return objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!) as? [String: Any?] ?? [:]
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Setup viewport detection if callbacks are registered
        let props = getStoredProps(from: view).compactMapValues { $0 }
        let hasViewportCallbacks = props["onViewportEnter"] != nil || props["onViewportLeave"] != nil
        
        if hasViewportCallbacks {
            setupViewportDetection(view, props: props)
        }
        
        // Trigger initial measurement after a brief delay to ensure layout is complete
        DispatchQueue.main.async { [weak view] in
            guard let view = view else { return }
            self.triggerMeasureCallbacks(view)
            // Check initial viewport visibility
            if hasViewportCallbacks {
                self.checkViewportVisibility(view, props: props)
            }
        }
    }
    
    /// Setup viewport detection
    /// 
    /// Viewport detection works in two modes:
    /// 1. If view is inside a ScrollView: detects visibility within scroll view's visible area
    /// 2. If view is NOT in a ScrollView: detects visibility within window/screen bounds
    private func setupViewportDetection(_ view: UIView, props: [String: Any]) {
        // Find containing scroll view (if any)
        let scrollView = findContainingScrollView(view)
        
        if let scrollView = scrollView {
            // Add observer for scroll events
            let observer = ViewportObserver(view: view, props: props, component: self)
            objc_setAssociatedObject(view,
                                     UnsafeRawPointer(bitPattern: "viewportObserver".hashValue)!,
                                     observer,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Register as scroll listener
            scrollView.addScrollListener(observer)
            
            // Check initial visibility
            DispatchQueue.main.async {
                self.checkViewportVisibility(view, props: props)
            }
        } else {
            // No scroll view found - check visibility against window
            // Also observe layout changes for non-scroll views
            let observer = ViewportLayoutObserver(view: view, props: props, component: self)
            objc_setAssociatedObject(view,
                                     UnsafeRawPointer(bitPattern: "viewportLayoutObserver".hashValue)!,
                                     observer,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            DispatchQueue.main.async {
                self.checkViewportVisibility(view, props: props)
            }
        }
    }
    
    /// Find containing scroll view by walking up the hierarchy
    private func findContainingScrollView(_ view: UIView) -> DCFScrollView? {
        var currentView: UIView? = view.superview
        while currentView != nil {
            if let scrollView = currentView as? DCFScrollView {
                return scrollView
            }
            // Also check for DCFCustomScrollView (internal scroll view)
            if let customScrollView = currentView as? DCFCustomScrollView {
                return customScrollView.superview as? DCFScrollView
            }
            currentView = currentView?.superview
        }
        return nil
    }
    
    /// Check if view is visible in viewport
    private func checkViewportVisibility(_ view: UIView, props: [String: Any]) {
        guard view.frame.width > 0 && view.frame.height > 0 else { return }
        
        let viewportConfig = props["viewport"] as? [String: Any]
        let once = viewportConfig?["once"] as? Bool ?? false
        let amount = viewportConfig?["amount"] as? Double ?? 0.0
        let margin = viewportConfig?["margin"] as? Double ?? 0.0
        
        // Check if view is in viewport
        let isVisible = isViewInViewport(view, amount: amount, margin: margin)
        
        // Get previous visibility state
        let wasVisible = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "wasInViewport".hashValue)!) as? Bool ?? false
        
        if isVisible && !wasVisible {
            // Entered viewport
            objc_setAssociatedObject(view,
                                   UnsafeRawPointer(bitPattern: "wasInViewport".hashValue)!,
                                   true,
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            if props["onViewportEnter"] != nil {
                propagateEvent(on: view, eventName: "onViewportEnter", data: [:])
            }
        } else if !isVisible && wasVisible {
            // Left viewport
            if !once {
                objc_setAssociatedObject(view,
                                       UnsafeRawPointer(bitPattern: "wasInViewport".hashValue)!,
                                       false,
                                       .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                if props["onViewportLeave"] != nil {
                    propagateEvent(on: view, eventName: "onViewportLeave", data: [:])
                }
            }
        }
    }
    
    /// Check if view is in viewport
    private func isViewInViewport(_ view: UIView, amount: Double, margin: Double) -> Bool {
        guard let window = view.window else {
            // If no window, assume visible
            return true
        }
        
        // Get view's frame in window coordinates
        let viewFrame = view.convert(view.bounds, to: window)
        
        // Get window bounds (viewport)
        let viewportFrame = window.bounds.insetBy(dx: -margin, dy: -margin)
        
        // Calculate intersection
        let intersection = viewFrame.intersection(viewportFrame)
        
        if intersection.isNull {
            return false
        }
        
        // Calculate visible area
        let visibleArea = intersection.width * intersection.height
        let totalArea = viewFrame.width * viewFrame.height
        
        if totalArea == 0 {
            return false
        }
        
        let visibleRatio = visibleArea / totalArea
        return visibleRatio >= amount
    }
    
    /// Scroll listener for viewport detection
    private class ViewportObserver: NSObject, UIScrollViewDelegate {
        weak var view: UIView?
        let props: [String: Any]
        weak var component: DCFViewportComponent?
        
        init(view: UIView, props: [String: Any], component: DCFViewportComponent) {
            self.view = view
            self.props = props
            self.component = component
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let view = view, let component = component else { return }
            component.checkViewportVisibility(view, props: props)
        }
    }
    
    /// Layout observer for viewport detection (for non-scroll views)
    private class ViewportLayoutObserver: NSObject {
        weak var view: UIView?
        let props: [String: Any]
        weak var component: DCFViewportComponent?
        
        init(view: UIView, props: [String: Any], component: DCFViewportComponent) {
            self.view = view
            self.props = props
            self.component = component
            super.init()
            
            // Observe layout changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleLayoutChange),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
        }
        
        @objc private func handleLayoutChange() {
            guard let view = view, let component = component else { return }
            DispatchQueue.main.async {
                component.checkViewportVisibility(view, props: self.props)
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

