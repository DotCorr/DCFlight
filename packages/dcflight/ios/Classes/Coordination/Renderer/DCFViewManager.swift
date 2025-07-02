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

// Internal class definition for supported layout properties
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

// For ambiguous init issue:
typealias ViewTypeInfo = (view: UIView, type: String)

/// Registry for storing and managing view references
class ViewRegistry {
    // Singleton instance
    static let shared = ViewRegistry()
    
    // Maps view IDs to views and their types
    public var registry = [String: ViewTypeInfo]()
    
    private init() {}
    
    // Register a view with ID and type
    func registerView(_ view: UIView, id: String, type: String) {
        registry[id] = (view, type)
        
        // Also register with layout manager for direct access
        DCFLayoutManager.shared.registerView(view, withId: id)
    }
    
    // Get view info by ID
    func getViewInfo(id: String) -> ViewTypeInfo? {
        return registry[id]
    }
    
    // Get view by ID
    func getView(id: String) -> UIView? {
        return registry[id]?.view
    }
    
    // Remove a view by ID
    func removeView(id: String) {
        registry.removeValue(forKey: id)
        DCFLayoutManager.shared.unregisterView(withId: id)
    }
    
    // Get all view IDs
    var allViewIds: [String] {
        return Array(registry.keys)
    }
    
    // Clean up views
    func cleanup() {
        registry.removeAll()
    }
}

/// Main view manager that coordinates between all view-related systems
class DCFViewManager {
    // Singleton instance
    static let shared = DCFViewManager()
    
    private init() {}
    
    /// Create a view with automatic layout handling
    func createView(viewId: String, viewType: String, props: [String: Any]) -> Bool {
        
        // Get component type
        guard let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) else {
            print("❌ DCFViewManager: Component type '\(viewType)' not found")
            return false
        }
        
        // Create component instance and view
        let componentInstance = componentType.init()
        let view = componentInstance.createView(props: props)
        
        // Tag the view with its component type for event registration
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "componentType".hashValue)!,
            viewType,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Register the view
        ViewRegistry.shared.registerView(view, id: viewId, type: viewType)
        
        // CRITICAL FIX: Detect if this is a screen component
        let isScreen = (viewType == "Screen" || props["presentationStyle"] != nil)
        
        if isScreen {
            print("🖼️ DCFViewManager: Creating screen '\(viewId)' with presentation style: \(props["presentationStyle"] ?? "unknown")")
            
            // CRITICAL FIX: Create screen as its own Yoga root
            YogaShadowTree.shared.createScreenRoot(id: viewId, componentType: viewType)
            
            // Apply layout props to the screen root
            let layoutProps = extractLayoutProps(from: props)
            if !layoutProps.isEmpty {
                YogaShadowTree.shared.updateNodeLayoutProps(nodeId: viewId, props: layoutProps)
                print("📐 DCFViewManager: Applied layout props to screen root '\(viewId)'")
            }
            
        } else {
            print("🧩 DCFViewManager: Creating regular component '\(viewId)' of type '\(viewType)'")
            
            // Regular components get added to the main Yoga tree
            YogaShadowTree.shared.createNode(id: viewId, componentType: viewType)
            
            // Apply layout props to regular component
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
        
        // Register with layout manager (for view registry and style application)
        DCFLayoutManager.shared.registerView(view, withNodeId: viewId, componentType: viewType, componentInstance: componentInstance)
        
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
        
        // Separate layout props from other props
        let layoutProps = extractLayoutProps(from: props)
        let nonLayoutProps = props.filter { !layoutProps.keys.contains($0.key) }
        
        // Update layout props if any
        if !layoutProps.isEmpty {
            // CRITICAL FIX: Use appropriate layout update method based on whether this is a screen
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
        
        // Update non-layout props
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
        
        print("✅ DCFViewManager: Successfully updated view '\(viewId)'")
        return true
    }
    
    /// Delete a view with automatic cleanup
    func deleteView(viewId: String) -> Bool {
        print("🗑️ DCFViewManager: Deleting view '\(viewId)'")
        
        // Remove from registries
        ViewRegistry.shared.removeView(id: viewId)
        DCFLayoutManager.shared.removeNode(nodeId: viewId)
        
        print("✅ DCFViewManager: Successfully deleted view '\(viewId)'")
        return true
    }
    
    /// CRITICAL FIX: Modified attachView to handle screen attachment properly
    func attachView(childId: String, parentId: String, index: Int) -> Bool {
        guard let childView = ViewRegistry.shared.getView(id: childId),
              let parentView = ViewRegistry.shared.getView(id: parentId) else {
            print("❌ DCFViewManager: Cannot attach - child '\(childId)' or parent '\(parentId)' not found")
            return false
        }
        
        // Add to view hierarchy (this always happens regardless of Yoga tree structure)
        if index >= 0 && index < parentView.subviews.count {
            parentView.insertSubview(childView, at: index)
        } else {
            parentView.addSubview(childView)
        }
        print("🔗 DCFViewManager: Attached view '\(childId)' to parent '\(parentId)' at index \(index)")
        
        // CRITICAL FIX: Only update Yoga layout tree for non-screen components
        let childIsScreen = YogaShadowTree.shared.isScreenRoot(childId)
        let parentIsScreen = YogaShadowTree.shared.isScreenRoot(parentId)
        
        if !childIsScreen {
            // Regular component can be added to Yoga tree
            // If parent is a screen, add to that screen's Yoga root
            // If parent is regular component, add to main tree
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
