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
    // Singleton instance
    public static let shared = DCFLayoutManager()
    
    // Set of views using absolute layout (controlled by Dart)
    private var absoluteLayoutViews = Set<UIView>()
    
    // Map view IDs to actual UIViews for direct access
    internal var viewRegistry = [String: UIView]()
    
    // ADDED: For optimizing layout updates
    private var pendingLayouts = [String: CGRect]()
    private var isLayoutUpdateScheduled = false
    
    // ADDED: Track when layout calculation is needed
    private var needsLayoutCalculation = false
    private var layoutCalculationTimer: Timer?
    
    // ADDED: Dedicated queue for layout operations
    private let layoutQueue = DispatchQueue(label: "com.dcmaui.layoutQueue", qos: .userInitiated)
    
    // ENHANCEMENT: Web defaults configuration for cross-platform compatibility
    private var useWebDefaults = false
    
    private init() {}
    
    // MARK: - Web Defaults Configuration
    
    /// Configure web defaults for cross-platform compatibility
    /// When enabled, aligns with CSS defaults: flex-direction: row, align-content: stretch, flex-shrink: 1
    public func setUseWebDefaults(_ enabled: Bool) {
        useWebDefaults = enabled
        
        // Apply web defaults to the root node if it exists
        if enabled {
            YogaShadowTree.shared.applyWebDefaults()
        }
        
        print("✅ DCFLayoutManager: UseWebDefaults set to \(enabled)")
    }
    
    /// Get current web defaults configuration
    public func getUseWebDefaults() -> Bool {
        return useWebDefaults
    }
    
    // MARK: - Automatic Layout Calculation
    
    /// CRASH FIX: Schedule automatic layout calculation with reconciliation awareness
    private func scheduleLayoutCalculation() {
        // Cancel existing timer
        layoutCalculationTimer?.invalidate()
        
        // Schedule new calculation with debouncing (100ms delay)
        layoutCalculationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performAutomaticLayoutCalculation()
        }
    }
    
    /// CRASH FIX: Perform automatic layout calculation with reconciliation coordination
    private func performAutomaticLayoutCalculation() {
        guard needsLayoutCalculation else { return }
        
        // Use layout queue for calculation
        layoutQueue.async {
            // Get screen dimensions
            let screenBounds = UIScreen.main.bounds
            
            // CRASH FIX: Use the synchronized calculateAndApplyLayout method
            // This will automatically defer if reconciliation is in progress
            let success = YogaShadowTree.shared.calculateAndApplyLayout(
                width: screenBounds.width,
                height: screenBounds.height
            )
            
            // Update flag on main thread
            DispatchQueue.main.async {
                self.needsLayoutCalculation = false
                if success {
                    print("✅ DCFLayoutManager: Layout calculation successful")
                } else {
                    print("⚠️ DCFLayoutManager: Layout calculation deferred, rescheduling")
                    // Reschedule if deferred due to reconciliation
                    self.needsLayoutCalculation = true
                    self.scheduleLayoutCalculation()
                }
            }
        }
    }
    
    // MARK: - View Registry Management
    
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
    
    // MARK: - Absolute Layout Management
    
    /// Mark a view as using absolute layout (controlled by Dart side)
    func setViewUsingAbsoluteLayout(view: UIView) {
        absoluteLayoutViews.insert(view)
    }
    
    /// Check if a view uses absolute layout
    func isUsingAbsoluteLayout(_ view: UIView) -> Bool {
        return absoluteLayoutViews.contains(view)
    }
    
    // MARK: - Cleanup
    
    /// Clean up resources for a view
    func cleanUp(viewId: String) {
        if let view = viewRegistry[viewId] {
            absoluteLayoutViews.remove(view)
        }
        viewRegistry.removeValue(forKey: viewId)
    }
    
    // MARK: - Style Application
    
    /// Apply styles to a view (using the shared UIView extension)
    func applyStyles(to view: UIView, props: [String: Any]) {
        view.applyStyles(props: props)
    }
    
    // MARK: - Layout Management
    
    /// Queue layout update to happen off the main thread
    func queueLayoutUpdate(to viewId: String, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        guard viewRegistry[viewId] != nil else {
            return false
        }
        
        // Store layout in pending queue
        let frame = CGRect(x: left, y: top, width: max(1, width), height: max(1, height))
        
        // Use layout queue to modify shared data
        layoutQueue.async {
            self.pendingLayouts[viewId] = frame
            
            if !self.isLayoutUpdateScheduled {
                self.isLayoutUpdateScheduled = true
                
                // Schedule layout application on main thread
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
        
        // Create valid frame with minimum dimensions to ensure visibility
        let frame = CGRect(
            x: left,
            y: top,
            width: max(1, width),
            height: max(1, height)
        )
        
        // Apply on main thread
        if Thread.isMainThread {
            if animationDuration > 0 {
                UIView.animate(withDuration: animationDuration) {
                    self.applyLayoutDirectly(to: view, frame: frame)
                }
            } else {
                self.applyLayoutDirectly(to: view, frame: frame)
            }
        } else {
            // Schedule on main thread
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
    
    // Direct layout application helper
    private func applyLayoutDirectly(to view: UIView, frame: CGRect) {
        // 🔥 HOT RESTART COMPREHENSIVE SAFETY: Multiple validation layers
        
        // Level 1: Check if view is nil or in invalid state
        guard !view.isEqual(nil) else {
            return
        }
        
        // Level 2: Check view hierarchy state
        guard view.superview != nil || view.window != nil else {
            return
        }
        
        // Level 4: Check if view responds to frame setter (defensive programming)
        guard view.responds(to: #selector(setter: UIView.frame)) else {
            return
        }
        
        // Level 5: Validate frame values are reasonable
        guard frame.width.isFinite && frame.height.isFinite &&
              frame.origin.x.isFinite && frame.origin.y.isFinite &&
              !frame.width.isNaN && !frame.height.isNaN &&
              !frame.origin.x.isNaN && !frame.origin.y.isNaN else {
            return
        }
        
        // Level 6: Check for reasonable bounds
        guard frame.width <= 10000 && frame.height <= 10000 &&
              frame.width >= 0 && frame.height >= 0 else {
            return
        }
        
        // Ensure minimum dimensions
        var safeFrame = frame
        safeFrame.size.width = max(1, frame.width)
        safeFrame.size.height = max(1, frame.height)
        
        // Level 7: Final safety - set frame on main thread with autoreleasepool
        DispatchQueue.main.async { [weak view] in
            autoreleasepool {
                guard let strongView = view,
                      strongView.superview != nil || strongView.window != nil else {
                    return
                }
                
                // Make sure view is visible first
                strongView.isHidden = false
                strongView.alpha = 1.0
                
                // Final frame setting with careful exception handling via CATransaction
                CATransaction.begin()
                CATransaction.setDisableActions(true) // Disable animations during hot restart
                
                // Set frame - this is the line that was crashing
                strongView.frame = safeFrame
                
                CATransaction.commit()
                
            }
        }
        
        // Force layout
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // New method to apply a dictionary of calculated layout frames
    func applyLayoutResults(_ results: [String: CGRect], animationDuration: TimeInterval = 0.0) {
        // Must be called on main thread
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

    // New method to batch process layout updates
    private func applyPendingLayouts(animationDuration: TimeInterval = 0.0) {
        // Must be called on main thread
        assert(Thread.isMainThread, "applyPendingLayouts must be called on the main thread")
        
        // Reset flag first
        isLayoutUpdateScheduled = false
        
        // Make local copy to prevent concurrency issues
        var layoutsToApply: [String: CGRect] = [:]
        
        // Use layoutQueue to safely get pending layouts
        layoutQueue.sync {
            layoutsToApply = self.pendingLayouts
            self.pendingLayouts.removeAll()
        }
        
        // Apply all pending layouts
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

// MARK: - Extensions

extension DCFLayoutManager {
    // Register view with layout system
    func registerView(_ view: UIView, withNodeId nodeId: String, componentType: String, componentInstance: DCFComponent) {
        // First, register the view for direct access
        registerView(view, withId: nodeId)
        
        // Associate the view with its Yoga node
        
        // Let the component know it's registered - this allows each component
        // to handle its own specialized registration logic
        componentInstance.viewRegisteredWithShadowTree(view, nodeId: nodeId)
        
        // ADDED: If this is a root view, trigger initial layout calculation
        if nodeId == "root" {
            triggerLayoutCalculation()
        }
    }
    
    // CRASH FIX: Add a child node to a parent in the layout tree with safe coordination
    func addChildNode(parentId: String, childId: String, index: Int) {
        
        // Call the synchronized YogaShadowTree addition
        YogaShadowTree.shared.addChildNode(parentId: parentId, childId: childId, index: index)
        
        // ADDED: Trigger layout calculation when tree structure changes
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    // CRASH FIX: Remove a node from the layout tree with safe coordination
    func removeNode(nodeId: String) {
        
        // Call the synchronized YogaShadowTree removal
        YogaShadowTree.shared.removeNode(nodeId: nodeId)
        
        // ADDED: Trigger layout calculation when tree structure changes
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    // Update a node's layout properties
    public func updateNodeWithLayoutProps(nodeId: String, componentType: String, props: [String: Any]) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId: nodeId, props: props)
        
        // ADDED: Trigger automatic layout calculation when layout props change
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
        
    }
    
    // Manually trigger layout calculation (useful for initial layout or when needed)
    public func triggerLayoutCalculation() {
        needsLayoutCalculation = true
        scheduleLayoutCalculation()
    }
    
    /// CRASH FIX: Force immediate layout calculation (synchronous) with reconciliation awareness
    func calculateLayoutNow() {
        layoutQueue.async {
            let screenBounds = UIScreen.main.bounds
            
            // CRASH FIX: Use the synchronized calculateAndApplyLayout method
            let success = YogaShadowTree.shared.calculateAndApplyLayout(
                width: screenBounds.width,
                height: screenBounds.height
            )
            
            DispatchQueue.main.async {
                if success {
                } else {
                }
            }
        }
    }
}
