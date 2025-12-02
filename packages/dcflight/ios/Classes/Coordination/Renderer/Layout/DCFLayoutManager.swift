/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga
import QuartzCore

/// Manages layout for DCFlight components
/// Now handles automatic layout calculations natively when layout props change
public class DCFLayoutManager {
    public static let shared = DCFLayoutManager()
    
    private var absoluteLayoutViews = Set<UIView>()
    
    internal var viewRegistry = [Int: UIView]()
    
    private var pendingLayouts = [Int: CGRect]()
    private var isLayoutUpdateScheduled = false
    
    private var needsLayoutCalculation = false
    private var layoutCalculationTimer: Timer?
    
    private let layoutQueue = DispatchQueue(label: "com.dcmaui.layoutQueue", qos: .userInitiated)
    
    private var useWebDefaults = false
    
    /// Layout animation configuration
    public var layoutAnimationEnabled = false
    public var layoutAnimationDuration: TimeInterval = 0.3
    
    private init() {}
    
    
    /// Configure web defaults for cross-platform compatibility
    /// When enabled, aligns with CSS defaults: flex-direction: row, align-content: stretch, flex-shrink: 1
    public func setUseWebDefaults(_ enabled: Bool) {
        useWebDefaults = enabled
        
        if enabled {
            YogaShadowTree.shared.applyWebDefaults()
        }
        
        print("✅ DCFLayoutManager: UseWebDefaults set to \(enabled)")
    }
    
    /// Get current web defaults configuration
    public func getUseWebDefaults() -> Bool {
        return useWebDefaults
    }
    
    
    /// CRASH FIX: Schedule automatic layout calculation with reconciliation awareness
    private func scheduleLayoutCalculation() {
        layoutCalculationTimer?.invalidate()
        
        layoutCalculationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performAutomaticLayoutCalculation()
        }
    }
    
    /// CRASH FIX: Perform automatic layout calculation with reconciliation coordination
    private func performAutomaticLayoutCalculation() {
        guard needsLayoutCalculation else { return }
        
        // CRITICAL: Set root view frame on main thread BEFORE layout calculation
        // This ensures root view is correctly positioned when Yoga calculates child positions
        DispatchQueue.main.async {
            let screenBounds = UIScreen.main.bounds
            
            // Set root view frame first - CRITICAL: Must be exactly (0,0) to fill window
            // This ensures all children are positioned correctly relative to window origin
            if let rootView = self.getView(withId: 0) {
                // Get actual window bounds (not safe area)
                let windowBounds: CGRect
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    windowBounds = window.bounds
                } else {
                    windowBounds = screenBounds
                }
                
                let rootFrame = CGRect(x: 0, y: 0, width: windowBounds.width, height: windowBounds.height)
                if !rootView.frame.equalTo(rootFrame) {
                    rootView.frame = rootFrame
                    rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    print("✅ DCFLayoutManager: Root view frame set to \(rootFrame) on main thread (window.bounds)")
                }
            }
            
            // Now do layout calculation on background thread
            self.layoutQueue.async {
            let success = YogaShadowTree.shared.calculateAndApplyLayout(
                width: screenBounds.width,
                height: screenBounds.height
            )
            
            DispatchQueue.main.async {
                self.needsLayoutCalculation = false
                if success {
                    print("✅ DCFLayoutManager: Layout calculation successful")
                } else {
                    print("⚠️ DCFLayoutManager: Layout calculation deferred, rescheduling")
                    self.needsLayoutCalculation = true
                    self.scheduleLayoutCalculation()
                    }
                }
            }
        }
    }
    
    
    /// Register a view with an ID
    func registerView(_ view: UIView, withId viewId: Int) {
        viewRegistry[viewId] = view
    }
    
    /// Unregister a view
    func unregisterView(withId viewId: Int) {
        viewRegistry.removeValue(forKey: viewId)
    }
    
    /// Get view by ID
    func getView(withId viewId: Int) -> UIView? {
        return viewRegistry[viewId]
    }
    
    
    /// Mark a view as using absolute layout (controlled by Dart side)
    func setViewUsingAbsoluteLayout(view: UIView) {
        absoluteLayoutViews.insert(view)
    }
    
    /// Check if a view uses absolute layout
    func isUsingAbsoluteLayout(_ view: UIView) -> Bool {
        return absoluteLayoutViews.contains(view)
    }
    
    
    /// Clean up resources for a view
    func cleanUp(viewId: Int) {
        if let view = viewRegistry[viewId] {
            absoluteLayoutViews.remove(view)
        }
        viewRegistry.removeValue(forKey: viewId)
    }
    
    
    /// Apply styles to a view (using the shared UIView extension)
    func applyStyles(to view: UIView, props: [String: Any]) {
        view.applyStyles(props: props)
    }
    
    
    /// Queue layout update to happen off the main thread
    func queueLayoutUpdate(to viewId: Int, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        guard viewRegistry[viewId] != nil else {
            return false
        }
        
        let frame = CGRect(x: left, y: top, width: max(1, width), height: max(1, height))
        
        layoutQueue.async {
            self.pendingLayouts[viewId] = frame
            
            if !self.isLayoutUpdateScheduled {
                self.isLayoutUpdateScheduled = true
                
                DispatchQueue.main.async {
                    self.applyPendingLayouts()
                }
            }
        }
        
        return true
    }
    
    /// Apply calculated layout to a view with optional animation
    @discardableResult
    func applyLayout(to viewId: Int, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
                     animationDuration: TimeInterval = 0.0) -> Bool {
        guard let view = getView(withId: viewId) else {
            return false
        }
        
        let frame = CGRect(
            x: left,
            y: top,
            width: max(1, width),
            height: max(1, height)
        )
        
        // Create YGNodeLayout for component's applyLayout method
        let layout = YGNodeLayout(
            left: left,
            top: top,
            width: width,
            height: height
        )
        
        // Use global layout animation settings if duration not specified
        let effectiveDuration = animationDuration > 0 ? animationDuration : 
            (layoutAnimationEnabled ? layoutAnimationDuration : 0.0)
        
        // Get component type and instance to call component's applyLayout
        let componentType = YogaShadowTree.shared.getComponentType(for: viewId)
        let applyLayoutBlock = {
            // Check if component has custom applyLayout implementation
            // If so, let it handle the frame entirely (e.g., ScrollContentView needs custom frame handling)
            if let componentType = componentType,
               let componentInstance = YogaShadowTree.shared.getComponentInstance(for: componentType) {
                // For components with custom applyLayout, let them handle the frame
                // This prevents race conditions where applyLayoutDirectly and component.applyLayout both set the frame
                componentInstance.applyLayout(view, layout: layout)
            } else {
                // For components without custom applyLayout, use the default direct frame application
                self.applyLayoutDirectly(to: view, frame: frame)
            }
        }
        
        if Thread.isMainThread {
            if effectiveDuration > 0 {
                UIView.animate(withDuration: effectiveDuration) {
                    applyLayoutBlock()
                }
            } else {
                applyLayoutBlock()
            }
        } else {
            DispatchQueue.main.async {
                if effectiveDuration > 0 {
                    UIView.animate(withDuration: effectiveDuration) {
                        applyLayoutBlock()
                    }
                } else {
                    applyLayoutBlock()
                }
            }
        }
        
        return true
    }
    
    private func applyLayoutDirectly(to view: UIView, frame: CGRect) {
        
        guard !view.isEqual(nil) else {
            return
        }
        
        guard view.superview != nil || view.window != nil else {
            return
        }
        
        guard view.responds(to: #selector(setter: UIView.frame)) else {
            return
        }
        
        guard frame.width.isFinite && frame.height.isFinite &&
              frame.origin.x.isFinite && frame.origin.y.isFinite &&
              !frame.width.isNaN && !frame.height.isNaN &&
              !frame.origin.x.isNaN && !frame.origin.y.isNaN else {
            return
        }
        
        guard frame.width <= 10000 && frame.height <= 10000 &&
              frame.width >= 0 && frame.height >= 0 else {
            return
        }
        
        var safeFrame = frame
        safeFrame.size.width = max(1, frame.width)
        safeFrame.size.height = max(1, frame.height)
        
        DispatchQueue.main.async { [weak view] in
            autoreleasepool {
                guard let strongView = view,
                      strongView.superview != nil || strongView.window != nil else {
                    return
                }
                
                strongView.isHidden = false
                strongView.alpha = 1.0
                
                // Check if layout animations are enabled
                // If animationDuration > 0, use UIView.animate (already handled in applyLayout)
                // Otherwise, disable implicit animations
                CATransaction.begin()
                CATransaction.setDisableActions(true) // Disable implicit animations
                
                strongView.frame = safeFrame
                
                CATransaction.commit()
                
            }
        }
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    func applyLayoutResults(_ results: [Int: CGRect], animationDuration: TimeInterval = 0.0) {
        assert(Thread.isMainThread, "applyLayoutResults must be called on the main thread")
        
        
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                for (viewId, frame) in results {
                    if let view = self.getView(withId: viewId) {
                        self.applyLayoutDirectly(to: view, frame: frame)
                    } else {
                    }
                }
            }
        } else {
            for (viewId, frame) in results {
                if let view = self.getView(withId: viewId) {
                    self.applyLayoutDirectly(to: view, frame: frame)
                } else {
                }
            }
        }
    }

    private func applyPendingLayouts(animationDuration: TimeInterval = 0.0) {
        assert(Thread.isMainThread, "applyPendingLayouts must be called on the main thread")
        
        isLayoutUpdateScheduled = false
        
        var layoutsToApply: [Int: CGRect] = [:]
        
        layoutQueue.sync {
            layoutsToApply = self.pendingLayouts
            self.pendingLayouts.removeAll()
        }
        
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                for (viewId, frame) in layoutsToApply {
                    if let view = self.getView(withId: viewId) {
                        self.applyLayoutDirectly(to: view, frame: frame)
                    }
                }
            }
        } else {
            for (viewId, frame) in layoutsToApply {
                if let view = self.getView(withId: viewId) {
                    self.applyLayoutDirectly(to: view, frame: frame)
                }
            }
        }
    }
    
}


extension DCFLayoutManager {
    func registerView(_ view: UIView, withNodeId nodeId: Int, componentType: String, componentInstance: DCFComponent) {
        registerView(view, withId: nodeId)
        
        
        componentInstance.viewRegisteredWithShadowTree(view, nodeId: String(nodeId))
        
        if nodeId == 0 {
            triggerLayoutCalculation()
        }
    }
    
    func addChildNode(parentId: Int, childId: Int, index: Int) {
        
        YogaShadowTree.shared.addChildNode(parentId: String(parentId), childId: String(childId), index: index)
        
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    func removeNode(nodeId: Int) {
        
        YogaShadowTree.shared.removeNode(nodeId: String(nodeId))
        
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    public func updateNodeWithLayoutProps(nodeId: Int, componentType: String, props: [String: Any]) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId: String(nodeId), props: props)
        
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    public func triggerLayoutCalculation() {
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
    }
    
    func calculateLayoutNow() {
        assert(Thread.isMainThread, "calculateLayoutNow must be called on the main thread")
        
        let windowBounds: CGRect
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            windowBounds = window.bounds
        } else {
            windowBounds = UIScreen.main.bounds
        }
        
        print("🎯 DCFLayoutManager: calculateLayoutNow called - \(viewRegistry.count) views registered, window size: \(windowBounds.width)x\(windowBounds.height)")
        
        let success = YogaShadowTree.shared.calculateAndApplyLayout(
            width: windowBounds.width,
            height: windowBounds.height
        )
        
        if success {
            // Make all views visible, including root view
            if let rootView = viewRegistry[0] {
                rootView.isHidden = false
                rootView.alpha = 1.0
                print("✅ DCFLayoutManager: Root view (0) made visible")
            } else {
                print("⚠️ DCFLayoutManager: Root view (0) not found in registry")
            }
            
            var visibleCount = 0
            for (viewId, view) in viewRegistry {
                if viewId != 0 { // Root view already handled above
                    view.isHidden = false
                    view.alpha = 1.0
                    visibleCount += 1
                }
            }
            
            print("✅ DCFLayoutManager: Made \(visibleCount) child views visible after layout calculation (total: \(viewRegistry.count))")
        } else {
            print("⚠️ DCFLayoutManager: Layout calculation returned false - retrying in 100ms")
            // Retry layout calculation if it failed (might be due to reconciliation in progress)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let retrySuccess = YogaShadowTree.shared.calculateAndApplyLayout(
                    width: windowBounds.width,
                    height: windowBounds.height
                )
                if retrySuccess {
                    if let rootView = self.viewRegistry[0] {
                        rootView.isHidden = false
                        rootView.alpha = 1.0
                    }
                    for (viewId, view) in self.viewRegistry {
                        if viewId != 0 {
                            view.isHidden = false
                            view.alpha = 1.0
                        }
                    }
                    print("✅ DCFLayoutManager: Retry successful - all views made visible")
                } else {
                    print("❌ DCFLayoutManager: Retry also failed - layout calculation may be blocked")
                }
            }
        }
    }
    
    /// Cancel all pending layout calculations (for hot restart)
    /// This prevents stale layout calculations from firing after cleanup
    func cancelAllPendingLayoutWork() {
        print("🧹 DCFLayoutManager: Cancelling all pending layout work")
        layoutCalculationTimer?.invalidate()
        layoutCalculationTimer = nil
        needsLayoutCalculation = false
        isLayoutUpdateScheduled = false
        pendingLayouts.removeAll()
        print("✅ DCFLayoutManager: All pending layout work cancelled")
    }
}
