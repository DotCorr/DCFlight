/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga

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
    
    /// Get intrinsic content size for a view (for text measurement, etc.)
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize
    
    /// Called when a view is registered with the shadow tree
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String)
    /// Handle tunnel method calls from Dart
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any?
    
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
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return view.intrinsicContentSize != .zero ? view.intrinsicContentSize : CGSize(width: 0, height: 0)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// Default implementation for tunnel method
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        print("⚠️ Component \(String(describing: self)) does not implement tunnel method: \(method)")
        return nil
    }
    
    // MARK: - Props Management (React Native Pattern)
    
    /// Store props in view's associated object for merging on updates (React Native pattern)
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
    
    /// Merge existing props with updates (React Native pattern)
    /// - Null values remove props
    /// - Non-null values update props
    /// - Missing props are preserved
    /// - CRITICAL: Semantic color props are removed if not in new props (StyleSheet property removal)
    func mergeProps(_ existing: [String: Any?], with updates: [String: Any?]) -> [String: Any?] {
        var merged = existing
        
        // CRITICAL: StyleSheet ALWAYS provides semantic colors via toMap()
        // Only remove semantic colors if explicitly set to nil in updates
        // If not in updates, preserve from existing (StyleSheet should always include them)
        let semanticColorKeys = ["primaryColor", "secondaryColor", "tertiaryColor", "accentColor"]
        for key in semanticColorKeys {
            // Only remove if explicitly nil/NSNull in updates (explicit removal)
            if let value = updates[key], value is NSNull {
                merged.removeValue(forKey: key)
            }
            // If in updates and not nil, it will be set below
            // If not in updates at all, preserve from existing (StyleSheet always provides)
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
        // React Native pattern: Store and merge props for stability
        let existingProps = getStoredProps(from: view)
        let mergedProps = mergeProps(existingProps, with: props)
        storeProps(mergedProps, in: view)
        
        // Filter out null values for processing
        let nonNullProps = mergedProps.compactMapValues { $0 }
        
        // Call component-specific update logic
        return updateViewInternal(view, withProps: nonNullProps)
    }
    
    /// Component-specific update logic (override in components)
    /// Props are already merged and null-filtered
    func updateViewInternal(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Default implementation - components should override
        return false
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
        return
    }
    
    guard let viewId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String else {
        return
    }
    
    guard let eventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] else {
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

