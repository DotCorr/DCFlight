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

public typealias ViewTypeInfo = (view: UIView, type: String)

/// Registry for storing and managing view references.
public class ViewRegistry {
    public static let shared = ViewRegistry()
    
    public var registry = [Int: ViewTypeInfo]()
    
    private init() {}
    
    /// Registers a view with the registry and layout manager.
    /// 
    /// - Parameters:
    ///   - view: The view to register
    ///   - id: Unique identifier for the view
    ///   - type: Component type (e.g., "View", "Text")
    public func registerView(_ view: UIView, id: Int, type: String) {
        registry[id] = (view, type)
        
        DCFLayoutManager.shared.registerView(view, withId: id)
    }
    
    /// Gets view information (view and type) by ID.
    /// 
    /// - Parameter id: Unique identifier for the view
    /// - Returns: Tuple containing the view and type, or `nil` if not found
    public func getViewInfo(id: Int) -> ViewTypeInfo? {
        return registry[id]
    }
    
    /// Gets a view by ID.
    /// 
    /// - Parameter id: Unique identifier for the view
    /// - Returns: The view, or `nil` if not found
    public func getView(id: Int) -> UIView? {
        return registry[id]?.view
    }
    
    /// Removes a view from the registry and layout manager.
    /// 
    /// - Parameter id: Unique identifier for the view to remove
    func removeView(id: Int) {
        registry.removeValue(forKey: id)
        DCFLayoutManager.shared.unregisterView(withId: id)
    }
    
    /// Returns all registered view IDs.
    var allViewIds: [Int] {
        return Array(registry.keys)
    }
    
    /// Cleans up all registered views.
    func cleanup() {
        registry.removeAll()
    }
}

/// Main view manager that coordinates between all view-related systems
class DCFViewManager {
    static let shared = DCFViewManager()
    
    private init() {}
    
    /// Creates a view with automatic layout handling.
    /// 
    /// Handles both regular components and screen components, setting up the appropriate
    /// layout nodes in YogaShadowTree and registering the view with the layout manager.
    /// 
    /// - Parameters:
    ///   - viewId: Unique identifier for the view
    ///   - viewType: Component type (e.g., "View", "Text", "Screen")
    ///   - props: Properties dictionary for the view
    /// - Returns: `true` if the view was created successfully, `false` otherwise
    func createView(viewId: Int, viewType: String, props: [String: Any]) -> Bool {
        guard let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) else {
            print("⚠️ DCFViewManager: Component type '\(viewType)' not found. Registered types: \(DCFComponentRegistry.shared.registeredTypes)")
            return false
        }
        
        if viewType == "GPU" || viewType == "Canvas" {
            print("✅ DCFViewManager: Creating \(viewType) component - viewId: \(viewId)")
        }
        
        let componentInstance = componentType.init()
        let view = componentInstance.createView(props: props)
        
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "componentType".hashValue)!,
            viewType,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // CRITICAL: Set viewId on view immediately so propagateEvent can find it
        // This must happen before event listeners are registered
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "viewId".hashValue)!,
            String(viewId),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Store component instance on view for setChildren and other component methods
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "componentInstance".hashValue)!,
            componentInstance,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        ViewRegistry.shared.registerView(view, id: viewId, type: viewType)
        
        let isScreen = (viewType == "Screen" || props["presentationStyle"] != nil)
        
        if isScreen {
            YogaShadowTree.shared.createScreenRoot(id: String(viewId), componentType: viewType)
            
            let layoutProps = extractLayoutProps(from: props)
            if !layoutProps.isEmpty {
                YogaShadowTree.shared.updateNodeLayoutProps(nodeId: String(viewId), props: layoutProps)
            }
        } else {
            YogaShadowTree.shared.createNode(id: String(viewId), componentType: viewType)
            
            let layoutProps = extractLayoutProps(from: props)
            if !layoutProps.isEmpty {
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    nodeId: viewId,
                    componentType: viewType,
                    props: layoutProps
                )
            }
        }
        
        DCFLayoutManager.shared.registerView(view, withNodeId: viewId, componentType: viewType, componentInstance: componentInstance)
        
        return true
    }
    
    /// Updates a view with automatic layout handling.
    /// 
    /// Separates layout properties from non-layout properties and applies them through
    /// the appropriate systems (YogaShadowTree for screens, DCFLayoutManager for regular components).
    /// 
    /// - Parameters:
    ///   - viewId: Unique identifier for the view to update
    ///   - props: Properties dictionary containing updates
    /// - Returns: `true` if the view was updated successfully, `false` otherwise
    func updateView(viewId: Int, props: [String: Any]) -> Bool {
        guard let viewInfo = ViewRegistry.shared.getViewInfo(id: viewId) else {
            return false
        }
        
        let view = viewInfo.view
        let viewType = viewInfo.type
        
        let layoutProps = extractLayoutProps(from: props)
        let nonLayoutProps = props.filter { !layoutProps.keys.contains($0.key) }
        
        if !layoutProps.isEmpty {
            let viewIdStr = String(viewId)
            let isScreen = YogaShadowTree.shared.isScreenRoot(viewIdStr)
            
            if isScreen {
                YogaShadowTree.shared.updateNodeLayoutProps(nodeId: viewIdStr, props: layoutProps)
            } else {
                DCFLayoutManager.shared.updateNodeWithLayoutProps(
                    nodeId: viewId,
                    componentType: viewType,
                    props: layoutProps
                )
            }
        }
        
        if !nonLayoutProps.isEmpty {
            guard let componentType = DCFComponentRegistry.shared.getComponentType(for: viewType) else {
                return false
            }
            
            let componentInstance = componentType.init()
            let success = componentInstance.updateView(view, withProps: nonLayoutProps)
            
            if !success {
                return false
            }
        }
        
        return true
    }
    
    /// Deletes a view with automatic cleanup.
    /// 
    /// Removes the view from the registry and layout manager, cleaning up all associated resources.
    /// 
    /// - Parameter viewId: Unique identifier for the view to delete
    /// - Returns: `true` if the view was deleted successfully
    func deleteView(viewId: Int) -> Bool {
        ViewRegistry.shared.removeView(id: viewId)
        DCFLayoutManager.shared.removeNode(nodeId: viewId)
        return true
    }
    
    /// Attaches a child view to a parent view at the specified index.
    /// 
    /// Handles special cases for screen components and view controller hierarchies.
    /// Screens are managed by navigation controllers and are not attached through this method.
    /// 
    /// - Parameters:
    ///   - childId: Unique identifier for the child view
    ///   - parentId: Unique identifier for the parent view
    ///   - index: Position in the parent's child list
    /// - Returns: `true` if the view was attached successfully, `false` otherwise
    func attachView(childId: Int, parentId: Int, index: Int) -> Bool {
        guard let childView = ViewRegistry.shared.getView(id: childId),
              let parentView = ViewRegistry.shared.getView(id: parentId) else {
            return false
        }
        
        // Check if this is a screen component - screens are managed by navigation controllers
        let childIsScreen = YogaShadowTree.shared.isScreenRoot(String(childId))
        if childIsScreen {
            return true
        }
        
        // Handle view controller hierarchy issues
        if let childViewController = childView.next as? UIViewController,
           let parentViewController = parentView.next as? UIViewController {
            
            // If child is already in a navigation controller, don't reattach
            if childViewController.navigationController != nil && parentViewController.navigationController != nil {
                return true
            }
            
            // If child has a parent view controller, remove it properly
            if childViewController.parent != nil {
                childViewController.willMove(toParent: nil)
                childViewController.view.removeFromSuperview()
                childViewController.removeFromParent()
            }
        }
        
        // Remove from existing parent before attaching to new parent
        if childView.superview != nil {
            childView.removeFromSuperview()
        }
        
        // CRITICAL: Check if parent component has custom child routing (e.g., ScrollView contentView)
        var targetView = parentView
        
        if let viewInfo = ViewRegistry.shared.getViewInfo(id: parentId),
           let componentType = DCFComponentRegistry.shared.getComponentType(for: viewInfo.type) {
            
            // Get component instance from view (stored during createView)
            if let componentInstance = objc_getAssociatedObject(parentView,
                                                               UnsafeRawPointer(bitPattern: "componentInstance".hashValue)!) as? DCFComponent {
                
                // For ScrollView, route to contentView instead of scroll view directly
                // Check by component type name (works without importing dcf_primitives)
                if viewInfo.type == "ScrollView" {
                    // Try to get contentView from associated object (set by DCFScrollViewComponent)
                    if let contentView = objc_getAssociatedObject(parentView,
                                                                UnsafeRawPointer(bitPattern: "contentView".hashValue)!) as? UIView {
                        targetView = contentView
                        print("✅ attachView: Routing child \(childId) to ScrollView contentView for parent \(parentId)")
                    } else {
                        // Fallback: Try to access contentView property via runtime
                        let contentViewSelector = NSSelectorFromString("contentView")
                        if parentView.responds(to: contentViewSelector) {
                            if let contentView = parentView.perform(contentViewSelector)?.takeUnretainedValue() as? UIView {
                                targetView = contentView
                                print("✅ attachView: Routing child \(childId) to ScrollView contentView (via selector) for parent \(parentId)")
                            }
                        }
                    }
                }
            }
        }
        
        // Check if child is already attached to target view
        if childView.superview == targetView {
            return true
        }
        
        // Attach to target view (either parentView or custom container like contentView)
        if index >= 0 && index < targetView.subviews.count {
            targetView.insertSubview(childView, at: index)
        } else {
            targetView.addSubview(childView)
        }
        
        if !childIsScreen {
            DCFLayoutManager.shared.addChildNode(parentId: parentId, childId: childId, index: index)
        }
        
        return true
    }
    
    /// Updates dimensions for all screen roots.
    /// 
    /// Called when the device orientation changes or screen size updates.
    /// 
    /// - Parameters:
    ///   - width: New screen width
    ///   - height: New screen height
    func updateScreenDimensions(width: CGFloat, height: CGFloat) {
        YogaShadowTree.shared.updateScreenRootDimensions(width: width, height: height)
    }
    
    /// Extracts layout properties from a props dictionary.
    /// 
    /// Filters the props dictionary to only include properties that are supported
    /// by the layout system (e.g., width, height, margin, padding, flex properties).
    /// 
    /// - Parameter props: Full properties dictionary
    /// - Returns: Dictionary containing only layout-related properties
    private func extractLayoutProps(from props: [String: Any]) -> [String: Any] {
        return props.filter { SupportedLayoutsProps.supportedLayoutProps.contains($0.key) }
    }
}

