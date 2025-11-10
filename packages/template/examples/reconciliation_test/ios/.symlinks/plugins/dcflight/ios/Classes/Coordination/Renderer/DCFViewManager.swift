/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Flutter
import UIKit
import yoga
import Foundation

class SupportedLayoutsProps {
    static let supportedLayoutProps = [
        "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
        "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
        "marginHorizontal", "marginVertical",
        "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
        "paddingHorizontal", "paddingVertical",
        "left", "top", "right", "bottom", "position",
        "translateX", "translateY",
        "rotateInDegrees",
        "scale", "scaleX", "scaleY",
        "flexDirection", "justifyContent", "alignItems", "alignSelf", "alignContent",
        "flexWrap", "flex", "flexGrow", "flexShrink", "flexBasis",
        "display", "overflow", "direction", "borderWidth",
        "aspectRatio", "gap", "rowGap", "columnGap"
    ]
}

typealias ViewTypeInfo = (view: UIView, type: String)

/// Registry for storing and managing view references
class ViewRegistry {
    static let shared = ViewRegistry()
    
    public var registry = [String: ViewTypeInfo]()
    
    private init() {}
    
    func registerView(_ view: UIView, id: String, type: String) {
        registry[id] = (view, type)
        
        DCFLayoutManager.shared.registerView(view, withId: id)
    }
    
    func getViewInfo(id: String) -> ViewTypeInfo? {
        return registry[id]
    }
    
    func getView(id: String) -> UIView? {
        return registry[id]?.view
    }
    
    func removeView(id: String) {
        registry.removeValue(forKey: id)
        DCFLayoutManager.shared.unregisterView(withId: id)
    }
    
    var allViewIds: [String] {
        return Array(registry.keys)
    }
    
    func cleanup() {
        registry.removeAll()
    }
}

/// Main view manager that coordinates between all view-related systems
class DCFViewManager {
    static let shared = DCFViewManager()
    
    private init() {}
    
    /// Create a view with automatic layout handling
    func createView(viewId: String, viewType: String, props: [String: Any]) -> Bool {
        
        guard let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) else {
            print("❌ DCFViewManager: Component type '\(viewType)' not found")
            return false
        }
        
        // Create component instance (needed for both pooled and new views)
        let componentInstance: DCFComponent = componentType.init()
        
        // Try to acquire a view from the pool first
        var finalView: UIView
        if let pooledView = ViewPoolManager.shared.acquireView(
            viewType: viewType,
            componentType: componentType,
            props: props
        ) {
            // Reuse pooled view
            finalView = pooledView
            print("♻️ DCFViewManager: Reused pooled view for type '\(viewType)' (viewId: \(viewId))")
            
            // Update the view with new props
            _ = componentInstance.updateView(finalView, withProps: props)
        } else {
            // Create a new view
            finalView = componentInstance.createView(props: props)
            print("✨ DCFViewManager: Created new view for type '\(viewType)' (viewId: \(viewId))")
        }
        
        // Ensure view is visible
        finalView.isHidden = false
        finalView.alpha = 1.0
        
        objc_setAssociatedObject(
            finalView,
            UnsafeRawPointer(bitPattern: "componentType".hashValue)!,
            viewType,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        ViewRegistry.shared.registerView(finalView, id: viewId, type: viewType)
        
        let isScreen = (viewType == "Screen" || props["presentationStyle"] != nil)
        
        if isScreen {
            print("🖼️ DCFViewManager: Creating screen '\(viewId)' with presentation style: \(props["presentationStyle"] ?? "unknown")")
            
            YogaShadowTree.shared.createScreenRoot(id: viewId, componentType: viewType)
            
            let layoutProps = extractLayoutProps(from: props)
            if !layoutProps.isEmpty {
                YogaShadowTree.shared.updateNodeLayoutProps(nodeId: viewId, props: layoutProps)
                print("📐 DCFViewManager: Applied layout props to screen root '\(viewId)'")
            }
            
        } else {
            print("🧩 DCFViewManager: Creating regular component '\(viewId)' of type '\(viewType)'")
            
            YogaShadowTree.shared.createNode(id: viewId, componentType: viewType)
            
            let layoutProps = extractLayoutProps(from: props)
            if !layoutProps.isEmpty {
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    nodeId: viewId,
                    componentType: viewType,
                    props: layoutProps
                )
                print("📐 DCFViewManager: Applied layout props to component '\(viewId)'")
            }
        }
        
        DCFLayoutManager.shared.registerView(finalView, withNodeId: viewId, componentType: viewType, componentInstance: componentInstance)
        
        print("✅ DCFViewManager: Successfully created \(isScreen ? "screen" : "component") '\(viewId)'")
        return true
    }
    
    /// Update a view with automatic layout handling
    func updateView(viewId: String, props: [String: Any]) -> Bool {
        guard let viewInfo = ViewRegistry.shared.getViewInfo(id: viewId) else {
            print("❌ DCFViewManager: View '\(viewId)' not found for update")
            return false
        }
        
        let view = viewInfo.view
        let viewType = viewInfo.type
        
        print("🔄 DCFViewManager: Updating view '\(viewId)' of type '\(viewType)'")
        
        let layoutProps = extractLayoutProps(from: props)
        let nonLayoutProps = props.filter { !layoutProps.keys.contains($0.key) }
        
        if !layoutProps.isEmpty {
            let isScreen = YogaShadowTree.shared.isScreenRoot(viewId)
            
            if isScreen {
                print("📐 DCFViewManager: Updating layout props for screen root '\(viewId)'")
                YogaShadowTree.shared.updateNodeLayoutProps(nodeId: viewId, props: layoutProps)
            } else {
                print("📐 DCFViewManager: Updating layout props for regular component '\(viewId)'")
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    nodeId: viewId,
                    componentType: viewType,
                    props: layoutProps
                )
            }
        }
        
        if !nonLayoutProps.isEmpty {
            guard let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) else {
                print("❌ DCFViewManager: Component type '\(viewType)' not found for update")
                return false
            }
            
            let componentInstance = componentType.init()
            let success = componentInstance.updateView(view, withProps: nonLayoutProps)
            
            if !success {
                print("❌ DCFViewManager: Failed to update non-layout props for view '\(viewId)'")
                return false
            }
        }
        
        // Ensure view is visible and invalidated after update
        view.isHidden = false
        view.alpha = 1.0
        view.setNeedsLayout()
        view.setNeedsDisplay()
        
        print("✅ DCFViewManager: Successfully updated view '\(viewId)'")
        return true
    }
    
    /// Delete a view with automatic cleanup
    func deleteView(viewId: String) -> Bool {
        print("🗑️ DCFViewManager: Deleting view '\(viewId)'")
        
        guard let viewInfo = ViewRegistry.shared.getViewInfo(id: viewId) else {
            print("⚠️ DCFViewManager: View '\(viewId)' not found for deletion")
            return false
        }
        
        let view = viewInfo.view
        let viewType = viewInfo.type
        
        // Remove from registry and layout manager
        ViewRegistry.shared.removeView(id: viewId)
        DCFLayoutManager.shared.removeNode(nodeId: viewId)
        
        // Release to pool instead of destroying
        if let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) {
            ViewPoolManager.shared.releaseView(
                view: view,
                viewType: viewType,
                componentType: componentType
            )
        }
        
        print("✅ DCFViewManager: Successfully deleted view '\(viewId)' (released to pool)")
        return true
    }
    
    /// CRITICAL FIX: Modified attachView to handle screen attachment properly
    func attachView(childId: String, parentId: String, index: Int) -> Bool {
        guard let childView = ViewRegistry.shared.getView(id: childId),
              let parentView = ViewRegistry.shared.getView(id: parentId) else {
            print("❌ DCFViewManager: Cannot attach - child '\(childId)' or parent '\(parentId)' not found")
            return false
        }
        
        // 🎯 CRITICAL FIX: Check if this is a screen component
        let childIsScreen = YogaShadowTree.shared.isScreenRoot(childId)
        
        // Screens should be managed by their respective navigation components, not the general view manager
        if childIsScreen {
            print("🚫 DCFViewManager: Skipping attachment for screen '\(childId)' - screens are managed by navigation controllers")
            return true
        }
        
        // 🎯 CRITICAL FIX: Check if this is a view controller hierarchy issue
        if let childViewController = childView.next as? UIViewController,
           let parentViewController = parentView.next as? UIViewController {
            
            // If child is already in a navigation controller, don't reattach
            if childViewController.navigationController != nil && parentViewController.navigationController != nil {
                print("🔧 DCFViewManager: Skipping attachment - child '\(childId)' already in navigation hierarchy")
                return true
            }
            
            // If child has a parent view controller, remove it properly
            if childViewController.parent != nil {
                print("🔧 DCFViewManager: Removing child '\(childId)' from existing view controller hierarchy")
                childViewController.willMove(toParent: nil)
                childViewController.view.removeFromSuperview()
                childViewController.removeFromParent()
            }
        }
        
        // 🎯 CRITICAL FIX: Remove from existing parent before attaching to new parent
        if childView.superview != nil {
            print("🔧 DCFViewManager: Removing child '\(childId)' from existing parent before reattaching")
            childView.removeFromSuperview()
        }
        
        // 🎯 CRITICAL FIX: Check if parent is already the superview
        if childView.superview == parentView {
            print("🔧 DCFViewManager: Child '\(childId)' already attached to parent '\(parentId)' - skipping")
            return true
        }
        
        if index >= 0 && index < parentView.subviews.count {
            parentView.insertSubview(childView, at: index)
        } else {
            parentView.addSubview(childView)
        }
        print("🔗 DCFViewManager: Attached view '\(childId)' to parent '\(parentId)' at index \(index)")
        
        if !childIsScreen {
            DCFLayoutManager.shared.addChildNode(parentId: parentId, childId: childId, index: index)
            print("📊 DCFViewManager: Added '\(childId)' to Yoga tree under parent '\(parentId)'")
        } else {
            print("🚫 DCFViewManager: Skipped Yoga tree update for screen '\(childId)' - screens are independent roots")
        }
        
        return true
    }
    
    /// CRITICAL FIX: Add method to handle screen dimension updates
    func updateScreenDimensions(width: CGFloat, height: CGFloat) {
        print("📐 DCFViewManager: Updating all screen dimensions to \(width)x\(height)")
        YogaShadowTree.shared.updateScreenRootDimensions(width: width, height: height)
    }
    
    /// Extract layout properties from props dictionary
    private func extractLayoutProps(from props: [String: Any]) -> [String: Any] {
        return props.filter { SupportedLayoutsProps.supportedLayoutProps.contains($0.key) }
    }
}
