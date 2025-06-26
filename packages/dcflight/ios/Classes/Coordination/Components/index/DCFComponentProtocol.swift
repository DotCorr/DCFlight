/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import yoga

//Hey, if u are seing this.
//Each individual componet extends this protocol and might seem to have dead code but they are not dead(currently is). These components implementing this protocol  are obliged to override these functions even if it seems like dead code or not to be doing anything. That is cause the framework is currently experimental and if all componets have this overriden although not used(you might as well remove it but be prepared to update your codebase when the need arises), it ensures your components are future proof. But meh, just yapping, you would figure it out.
/// Protocol that all DCMAUI components must implement
public protocol DCFComponent {
    /// Initialize the component
    init()
    
    /// Create a view with the given props
    func createView(props: [String: Any]) -> UIView
    
    /// Update a view with new props
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool
    
    /// Apply yoga layout to the view
    func applyLayout(_ view: UIView, layout: YGNodeLayout)
    
    /// Get intrinsic content size for a view (for text measurement, etc.)
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize
    
    /// Called when a view is registered with the shadow tree
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String)
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

// Make all the extension methods public so they can be accessed from other modules
public extension DCFComponent {
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Default implementation - position and size the view
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // Default implementation - use view's intrinsic size or zero
        return view.intrinsicContentSize != .zero ? view.intrinsicContentSize : CGSize(width: 0, height: 0)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Default implementation - store node ID on the view
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - 🚀 GLOBAL EVENT PROPAGATION SYSTEM
// Universal functions that ANY class can use to propagate events to Dart

/// Universal event propagation function - can be used by any class (delegates, components, helpers, etc.)
/// Usage: propagateEvent(on: scrollView, eventName: "onScroll", data: ["offsetX": x, "offsetY": y]) { view, data in
///     // Optional native-side processing
/// }
public func propagateEvent(on view: UIView, eventName: String, data eventData: [String: Any] = [:], 
                          nativeAction: ((UIView, [String: Any]) -> Void)? = nil) {
    
    // Execute optional native-side action first (for any native processing needed)
    nativeAction?(view, eventData)
    
    
    // Get the stored event callback for this view (set up by the framework automatically)
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
    
    
    // Check if this event type is registered - try both exact match and normalized versions
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
    // If already has "on" prefix and it's followed by uppercase letter, return as is
    if name.hasPrefix("on") && name.count > 2 {
        let thirdCharIndex = name.index(name.startIndex, offsetBy: 2)
        if name[thirdCharIndex].isUppercase {
            return name
        }
    }
    
    // Otherwise normalize: remove "on" if it exists, capitalize first letter, and add "on" prefix
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


