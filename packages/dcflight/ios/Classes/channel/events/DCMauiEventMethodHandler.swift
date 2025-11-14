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
    static let shared = DCMauiEventMethodHandler()
    
    internal var methodChannel: FlutterMethodChannel?
    
    typealias EventCallback = (String, String, [String: Any]) -> Void
    
    private var eventCallback: EventCallback?
    
    private override init() {
        super.init()
    }
    
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.events",
            binaryMessenger: binaryMessenger
        )
        
        setupMethodCallHandler()
        
        print("✅ DCMauiEventMethodHandler: Initialized with method channel")
    }
    
    private func setupMethodCallHandler() {
        guard let channel = methodChannel else {
            print("❌ DCMauiEventMethodHandler: Cannot setup method call handler - method channel is nil")
            return
        }
        
        channel.setMethodCallHandler { [weak self] (call, result) in
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
        
        print("✅ DCMauiEventMethodHandler: Method call handler set up successfully")
    }
    
    func setEventCallback(_ callback: @escaping EventCallback) {
        self.eventCallback = callback
    }
    
    func sendEvent(viewId: String, eventName: String, eventData: [String: Any]) {
        let normalizedEventName = normalizeEventName(eventName)
        
        // Always use method channel for reliability (eventCallback is legacy)
        guard let channel = methodChannel else {
            print("❌ DCMauiEventMethodHandler: Method channel is nil, cannot send event")
            return
        }
        
        let arguments: [String: Any] = [
            "viewId": viewId,
            "eventType": normalizedEventName,
            "eventData": eventData
        ]
        
        if Thread.isMainThread {
            channel.invokeMethod("onEvent", arguments: arguments, result: { result in
                if let error = result as? FlutterError {
                    print("❌ DCMauiEventMethodHandler: Error sending event: \(error.message ?? "Unknown error")")
                }
            })
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let channel = self.methodChannel else { return }
                channel.invokeMethod("onEvent", arguments: arguments, result: { result in
                    if let error = result as? FlutterError {
                        print("❌ DCMauiEventMethodHandler: Error sending event: \(error.message ?? "Unknown error")")
                    }
                })
            }
        }
    }
    
    private func normalizeEventName(_ name: String) -> String {
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
    
    
    private func handleAddEventListeners(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let eventTypes = args["eventTypes"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid arguments for addEventListeners", 
                               details: nil))
            return
        }
        
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid viewId for addEventListeners", 
                               details: nil))
            return
        }
        
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            
            result(true)
            return
        }
        
        DispatchQueue.main.async {
            let success = self.registerEventListeners(view: foundView, viewId: String(viewId), eventTypes: eventTypes)
            result(success)
        }
    }
    
    private func handleRemoveEventListeners(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let eventTypes = args["eventTypes"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid arguments for removeEventListeners", 
                               details: nil))
            return
        }
        
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId else {
            result(FlutterError(code: "INVALID_ARGS", 
                               message: "Invalid viewId for removeEventListeners", 
                               details: nil))
            return
        }
        
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            
            result(true)
            return
        }
        
        DispatchQueue.main.async {
            let success = self.unregisterEventListeners(view: foundView, viewId: String(viewId), eventTypes: eventTypes)
            result(success)
        }
    }
    
    func addEventListenersForBatch(viewId: Int, eventTypes: [String]) {
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            print("⚠️ DCMauiEventMethodHandler: View \(viewId) not found for event listener registration")
            return
        }
        
        let success = registerEventListeners(view: foundView, viewId: String(viewId), eventTypes: eventTypes)
        if success {
            print("✅ DCMauiEventMethodHandler: Registered event listeners for view \(viewId): \(eventTypes)")
        } else {
            print("❌ DCMauiEventMethodHandler: Failed to register event listeners for view \(viewId)")
        }
    }
    
    private func registerEventListeners(view: UIView, viewId: String, eventTypes: [String]) -> Bool {
        let viewType = String(describing: type(of: view))
        
        let normalizedEventTypes = eventTypes.map { normalizeEventName($0) }
        
        var allEventTypes = Set(eventTypes)
        allEventTypes.formUnion(normalizedEventTypes)
        
        // CRITICAL: Ensure viewId is set (might already be set in createView, but ensure it's correct)
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
        
        // CRITICAL: Create a strong reference to self in the closure to ensure it's not deallocated
        // The closure will be stored in the associated object, so it needs to capture self strongly
        let eventCallback: (String, String, [String: Any]) -> Void = { [weak self] (viewId, eventType, eventData) in
            guard let self = self else {
                print("⚠️ DCMauiEventMethodHandler: Event handler deallocated, cannot send event")
                return
            }
            self.sendEvent(viewId: viewId, eventName: eventType, eventData: eventData)
        }
        
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
            eventCallback,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Verify the associated objects were set correctly
        let verifyViewId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String
        let verifyEventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String]
        let verifyCallback = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) as? (String, String, [String: Any]) -> Void
        
        if verifyViewId == nil || verifyEventTypes == nil || verifyCallback == nil {
            print("❌ DCMauiEventMethodHandler: Failed to set associated objects for view \(viewId)")
            return false
        }
        
        return true
    }
    
    private func unregisterEventListeners(view: UIView, viewId: String, eventTypes: [String]) -> Bool {
        if let storedEventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] {
            var remainingTypes = storedEventTypes
            
            for eventType in eventTypes {
                let normalizedType = normalizeEventName(eventType)
                if let index = remainingTypes.firstIndex(of: normalizedType) {
                    remainingTypes.remove(at: index)
                }
            }
            
            if remainingTypes.isEmpty {
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
                objc_setAssociatedObject(
                    view,
                    UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
                    remainingTypes,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
        
        return true
    }
}
