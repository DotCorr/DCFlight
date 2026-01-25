/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import yoga

/// Protocol that views can conform to to opt-out of layout updates during certain states.
/// 
/// This allows modules (like dcf_reanimated) to make views layout-independent
/// without modifying the framework layer.
/// 
/// Example usage:
/// ```swift
/// class MyAnimatedView: UIView, DCFLayoutIndependent {
///     var shouldSkipLayout: Bool {
///         return isAnimating // Skip layout when animating
///     }
/// }
/// ```
public protocol DCFLayoutIndependent {
    /// Returns true if layout updates should be skipped for this view.
    /// 
    /// When true, Yoga will skip applying layout to this view, making it
    /// layout-independent (allows views to opt-out of Yoga layout updates).
    /// 
    /// This is useful for:
    /// - Animated views that use transforms (prevents anchor point recalculation)
    /// - Views with custom layout logic
    /// - Performance-critical views that don't need layout updates
    var shouldSkipLayout: Bool { get }
}

/// Protocol that all DCMAUI components must implement
public protocol DCFComponent {
    /// Initialize the component
    init()
    
    /// Create a view with the given props
    func createView(props: [String: Any]) -> UIView
    
    /// Update a view with new props
    /// Note: Components can override updateViewInternal for their logic
    /// The framework provides updateViewWithMerging for automatic props merging
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool
    
    /// Apply yoga layout to the view
    func applyLayout(_ view: UIView, layout: YGNodeLayout)
    
    /// Called when a view is registered with the shadow tree
    /// Components can set intrinsicContentSize on the shadowView if needed for automatic sizing
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String)
    
    /// Prepare a view for recycling (view pooling)
    /// Called before a view is returned to the pool for reuse
    /// Components should reset view state to defaults here
    func prepareForRecycle(_ view: UIView)
    
    /// Handle tunnel method calls from Dart
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any?
    
    /// Set children for a view (optional - components can override for custom child routing)
    /// Returns true if handled, false to use default implementation
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool
}

/// Layout information from a Yoga node
public struct YGNodeLayout {
    public let left: CGFloat
    public let top: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public init(left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) {
        self.left = left
        self.top = top
        self.width = width
        self.height = height
    }
}

public extension DCFComponent {
    
    // MARK: - Children Management (Default Implementation)
    
    /// Default implementation: Return false to use normal child attachment
    /// Components can override this to route children to custom containers (e.g., ScrollView contentView)
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        return false
    }
    
    // MARK: - View Recycling (Default Implementation)
    
    /// Default implementation: Remove from superview and reset basic properties
    /// Components can override this for custom cleanup
    func prepareForRecycle(_ view: UIView) {
        // Remove from parent
        view.removeFromSuperview()
        
        // Reset visibility
        view.isHidden = false
        view.alpha = 1.0
        
        // Clear any stored props
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!,
                                nil,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Clear event callbacks
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
                                nil,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Clear view ID
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "viewId".hashValue)!,
                                nil,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Clear event types
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
                                nil,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Reset frame to zero (will be set by layout)
        view.frame = .zero
        
        // Clear subviews (components should handle this if needed)
        view.subviews.forEach { $0.removeFromSuperview() }
    }
    
    // MARK: - Props Management
    
    /// Store props in view's associated object for merging on updates
    /// This ensures properties are preserved across partial updates
    func storeProps(_ props: [String: Any?], in view: UIView) {
        objc_setAssociatedObject(view,
                                UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!,
                                props,
                                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// Get stored props from view's associated object
    func getStoredProps(from view: UIView) -> [String: Any?] {
        return objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "dcf_stored_props".hashValue)!) as? [String: Any?] ?? [:]
    }
    
    /// Merge existing props with updates
    /// - Null values remove props
    /// - Non-null values update props
    /// - Missing props are preserved
    /// - Semantic color props are removed if not in new props (StyleSheet property removal)
    func mergeProps(_ existing: [String: Any?], with updates: [String: Any?]) -> [String: Any?] {
        var merged = existing
        
        let semanticColorKeys = ["primaryColor", "secondaryColor", "tertiaryColor", "accentColor"]
        for key in semanticColorKeys {
            if let value = updates[key], value is NSNull {
                merged.removeValue(forKey: key)
            }
        }
        
        for (key, value) in updates {
            if value == nil {
                merged.removeValue(forKey: key)
            } else {
                merged[key] = value
            }
        }
        return merged
    }
    
    /// Framework-level updateView implementation with automatic props merging
    /// Components should implement updateViewInternal for their specific logic
    /// This default implementation handles props merging automatically
    func updateViewWithMerging(_ view: UIView, withProps props: [String: Any?]) -> Bool {
        let existingProps = getStoredProps(from: view)
        let mergedProps = mergeProps(existingProps, with: props)
        storeProps(mergedProps, in: view)
        
        let nonNullProps = mergedProps.compactMapValues { $0 }
        
        return updateView(view, withProps: nonNullProps)
    }
}


/// Universal event propagation function - can be used by any class (delegates, components, helpers, etc.)
/// Usage: propagateEvent(on: scrollView, eventName: "onScroll", data: ["offsetX": x, "offsetY": y]) { view, data in
///     // Optional native-side processing
/// }
public func propagateEvent(on view: UIView, eventName: String, data eventData: [String: Any] = [:], 
                          nativeAction: ((UIView, [String: Any]) -> Void)? = nil) {
    
    nativeAction?(view, eventData)
    
    guard let callback = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) 
            as? (String, String, [String: Any]) -> Void else {
        if eventName != "onContentSizeChange" && eventName != "onScroll" {
            print("⚠️ propagateEvent: No event callback found for view \(view) (event: \(eventName))")
        }
        return
    }
    
    guard let viewId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String else {
        print("⚠️ propagateEvent: No viewId found for view \(view)")
        return
    }
    
    guard let eventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] else {
        print("⚠️ propagateEvent: No event types found for view \(viewId)")
        return
    }
    
    let normalizedEventName = normalizeEventNameForPropagation(eventName)
    let eventRegistered = eventTypes.contains(eventName) || 
                         eventTypes.contains(normalizedEventName) ||
                         eventTypes.contains(eventName.lowercased()) ||
                         eventTypes.contains("on\(eventName.capitalized)")
    
    if eventRegistered {
        callback(viewId, eventName, eventData)
    } else {
    }
}

/// Helper function to normalize event names for propagation matching
private func normalizeEventNameForPropagation(_ name: String) -> String {
    if name.hasPrefix("on") && name.count > 2 {
        let thirdCharIndex = name.index(name.startIndex, offsetBy: 2)
        if name[thirdCharIndex].isUppercase {
            return name
        }
    }
    
    var processedName = name
    if processedName.hasPrefix("on") {
        processedName = String(processedName.dropFirst(2))
    }
    
    if processedName.isEmpty {
        return "onEvent"
    }
    
    return "on\(processedName.prefix(1).uppercased())\(processedName.dropFirst())"
}

/// Simplified global event propagation for common cases
/// Usage: fireEvent(on: button, "onPress", ["pressed": true])
public func fireEvent(on view: UIView, _ eventName: String, _ eventData: [String: Any] = [:]) {
    propagateEvent(on: view, eventName: eventName, data: eventData)
}

