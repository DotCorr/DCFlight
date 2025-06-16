/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Flutter

/// Method channel handler for all event-related operations
class DCMauiEventMethodHandler: NSObject {
    // Singleton instance
    static let shared = DCMauiEventMethodHandler()
    
    // Method channel for event operations
    internal var methodChannel: FlutterMethodChannel?
    
    // Event callback closure type
    typealias EventCallback = (String, String, [String: Any]) -> Void
    
    // Store the event callback
    private var eventCallback: EventCallback?
    
    // Private initializer for singleton
    private override init() {
        super.init()
    }
    
    // Initialize with Flutter binary messenger
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.events",
            binaryMessenger: binaryMessenger
        )
        
        setupMethodCallHandler()
        print("📣 Event method channel initialized")
    }
    
    // Register method call handler
    private func setupMethodCallHandler() {
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", 
                                   message: "Event handler not available", 
                                   details: nil))
                return
            }
            
            switch call.method {
                case "addEventListeners":
                    self.handleAddEventListeners(call, result)
                    
                case "removeEventListeners":
                    self.handleRemoveEventListeners(call, result)
                    
                default:
                    result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // Set event callback function
    func setEventCallback(_ callback: @escaping EventCallback) {
        self.eventCallback = callback
    }
    
    // Send event to Dart
    func sendEvent(viewId: String, eventName: String, eventData: [String: Any]) {
        print("📣 Sending event to Dart - viewId: \(viewId), eventName: \(eventName)")
        
        // Ensure event name follows "on" convention
        let normalizedEventName = normalizeEventName(eventName)
        
        if let callback = self.eventCallback {
            // Use the stored callback if available
            print("🎯 Using direct callback for event dispatch")
            callback(viewId, normalizedEventName, eventData)
        } else if let channel = methodChannel {
            // Fall back to method channel
            print("📤 Using method channel for event dispatch")
            DispatchQueue.main.async {
                self.methodChannel?.invokeMethod("onEvent", arguments: [
                    "viewId": viewId,
                    "eventType": normalizedEventName,
                    "eventData": eventData
                ])
            }
        } else {
            print("❌ No method to send events available")
        }
    }
    
    // Normalize event name to follow React-style convention
    private func normalizeEventName(_ name: String) -> String {
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
    
    // MARK: - Method handlers
    
    // Handle addEventListeners calls
    private func handleAddEventListeners(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let viewId = args["viewId"] as? String,
              let eventTypes = args["eventTypes"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid arguments for addEventListeners", 
                               details: nil))
            return
        }
        
        print("🎯 Native: Received addEventListeners call for view \(viewId): \(eventTypes)")
        
        // Get view from the registry
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        // If still not found, try the LayoutManager
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            print("❌ Cannot register events: View not found with ID \(viewId)")
            
            // Return success anyway to prevent Flutter errors - we'll handle missing views gracefully
            result(true)
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            // Now register event listeners with the found view
            let success = self.registerEventListeners(view: foundView, viewId: viewId, eventTypes: eventTypes)
            result(success)
        }
    }
    
    // Handle removeEventListeners calls
    private func handleRemoveEventListeners(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let viewId = args["viewId"] as? String,
              let eventTypes = args["eventTypes"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid arguments for removeEventListeners", 
                               details: nil))
            return
        }
        
        print("🎯 Native: Received removeEventListeners call for view \(viewId): \(eventTypes)")
        
        // Get view from the registry
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        // If still not found, try the LayoutManager
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            print("❌ Cannot unregister events: View not found with ID \(viewId)")
            
            // Return success anyway to prevent Flutter errors - we'll handle missing views gracefully
            result(true)
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            // Now unregister event listeners with the found view
            let success = self.unregisterEventListeners(view: foundView, viewId: viewId, eventTypes: eventTypes)
            result(success)
        }
    }
    
    // Helper method to register event listeners
    private func registerEventListeners(view: UIView, viewId: String, eventTypes: [String]) -> Bool {
        let viewType = String(describing: type(of: view))
        
        // Normalize event types for consistency - ensure both directions work
        let normalizedEventTypes = eventTypes.map { normalizeEventName($0) }
        
        // Store both original and normalized event types to ensure matching works
        var allEventTypes = Set(eventTypes)
        allEventTypes.formUnion(normalizedEventTypes)
        
        print("🔄 Event types registration: original: \(eventTypes) -> normalized: \(normalizedEventTypes) -> combined: \(Array(allEventTypes))")
        
        // 🚀 NEW GLOBAL EVENT SYSTEM: No need for component-specific event registration!
        // The global propagateEvent() system handles all events automatically.
        // We just need to store the event registration info on the view.
        
        // Store event registration info directly on the view for the global event system
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "viewId".hashValue)!,
            viewId,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
            Array(allEventTypes),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Store the event callback for the global system to use
        let eventCallback: (String, String, [String: Any]) -> Void = { [weak self] (viewId, eventType, eventData) in
            print("🔔 Event triggered: \(eventType) for view \(viewId)")
            self?.sendEvent(viewId: viewId, eventName: eventType, eventData: eventData)
        }
        
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
            eventCallback,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        print("✅ Successfully registered events for view \(viewId): \(Array(allEventTypes)) using global event system")
        print("🔍 DEBUG: Stored event types: \(Array(allEventTypes))")
        print("🔍 DEBUG: View type: \(String(describing: type(of: view)))")
        return true
    }
    
    // Helper method to unregister event listeners
    private func unregisterEventListeners(view: UIView, viewId: String, eventTypes: [String]) -> Bool {
        // Remove event data from the view
        if let storedEventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] {
            var remainingTypes = storedEventTypes
            
            for eventType in eventTypes {
                let normalizedType = normalizeEventName(eventType)
                if let index = remainingTypes.firstIndex(of: normalizedType) {
                    remainingTypes.remove(at: index)
                }
            }
            
            if remainingTypes.isEmpty {
                // Clear all event data if no events remain
                objc_setAssociatedObject(
                    view,
                    UnsafeRawPointer(bitPattern: "viewId".hashValue)!,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                
                objc_setAssociatedObject(
                    view,
                    UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            } else {
                // Update remaining event types
                objc_setAssociatedObject(
                    view,
                    UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
                    remainingTypes,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
        
        print("✅ Successfully unregistered events for view \(viewId): \(eventTypes)")
        return true
    }
}
