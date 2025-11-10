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
    
    internal var viewRegistry = [String: UIView]()
    
    private var pendingLayouts = [String: CGRect]()
    private var isLayoutUpdateScheduled = false
    
    private var needsLayoutCalculation = false
    private var layoutCalculationTimer: Timer?
    
    private let layoutQueue = DispatchQueue(label: "com.dcmaui.layoutQueue", qos: .userInitiated)
    
    private var useWebDefaults = false
    
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
        
        layoutQueue.async {
            let screenBounds = UIScreen.main.bounds
            
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
    
    
    /// Register a view with an ID
    func registerView(_ view: UIView, withId viewId: String) {
        viewRegistry[viewId] = view
    }
    
    /// Unregister a view
    func unregisterView(withId viewId: String) {
        viewRegistry.removeValue(forKey: viewId)
    }
    
    /// Get view by ID
    func getView(withId viewId: String) -> UIView? {
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
    func cleanUp(viewId: String) {
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
    func queueLayoutUpdate(to viewId: String, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
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
    func applyLayout(to viewId: String, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
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
        
        if Thread.isMainThread {
            if animationDuration > 0 {
                UIView.animate(withDuration: animationDuration) {
                    self.applyLayoutDirectly(to: view, frame: frame)
                }
            } else {
                self.applyLayoutDirectly(to: view, frame: frame)
            }
        } else {
            DispatchQueue.main.async {
                if animationDuration > 0 {
                    UIView.animate(withDuration: animationDuration) {
                        self.applyLayoutDirectly(to: view, frame: frame)
                    }
                } else {
                    self.applyLayoutDirectly(to: view, frame: frame)
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
                
                CATransaction.begin()
                CATransaction.setDisableActions(true) // Disable animations during hot restart
                
                strongView.frame = safeFrame
                
                CATransaction.commit()
                
            }
        }
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    func applyLayoutResults(_ results: [String: CGRect], animationDuration: TimeInterval = 0.0) {
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
        
        var layoutsToApply: [String: CGRect] = [:]
        
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
    func registerView(_ view: UIView, withNodeId nodeId: String, componentType: String, componentInstance: DCFComponent) {
        registerView(view, withId: nodeId)
        
        
        componentInstance.viewRegisteredWithShadowTree(view, nodeId: nodeId)
        
        if nodeId == "root" {
            triggerLayoutCalculation()
        }
    }
    
    func addChildNode(parentId: String, childId: String, index: Int) {
        
        YogaShadowTree.shared.addChildNode(parentId: parentId, childId: childId, index: index)
        
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    func removeNode(nodeId: String) {
        
        YogaShadowTree.shared.removeNode(nodeId: nodeId)
        
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    public func updateNodeWithLayoutProps(nodeId: String, componentType: String, props: [String: Any]) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId: nodeId, props: props)
        
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
        
        let success = YogaShadowTree.shared.calculateAndApplyLayout(
            width: windowBounds.width,
            height: windowBounds.height
        )
        
        if success {
            for (_, view) in viewRegistry {
                view.isHidden = false
                view.alpha = 1.0
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
