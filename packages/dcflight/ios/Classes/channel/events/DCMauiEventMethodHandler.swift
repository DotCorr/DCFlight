/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

@_silgen_name("dcflight_send_event")
func dcflight_send_event(_ viewId: Int32, _ eventType: UnsafePointer<CChar>, _ eventDataJson: UnsafePointer<CChar>)

class DCMauiEventMethodHandler: NSObject {
    static let shared = DCMauiEventMethodHandler()
    
    typealias EventCallback = (String, String, [String: Any]) -> Void
    
    private var eventCallback: EventCallback?
    
    private override init() {
        super.init()
    }
    
    func sendEvent(viewId: String, eventName: String, eventData: [String: Any]) {
        let normalizedEventName = normalizeEventName(eventName)
        let viewIdInt = Int32(viewId) ?? 0
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: eventData, options: []),
           let eventDataJson = String(data: jsonData, encoding: .utf8) {
            dcflight_send_event(viewIdInt, normalizedEventName, eventDataJson)
            return
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
    
    func addEventListenersForBatch(viewId: Int, eventTypes: [String]) -> Bool {
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            print("⚠️ DCMauiEventMethodHandler: View \(viewId) not found for event listener registration")
            return false
        }
        
        let success = registerEventListeners(view: foundView, viewId: String(viewId), eventTypes: eventTypes)
        if success {
            print("✅ DCMauiEventMethodHandler: Registered event listeners for view \(viewId): \(eventTypes)")
        } else {
            print("❌ DCMauiEventMethodHandler: Failed to register event listeners for view \(viewId)")
        }
        return success
    }
    
    private func registerEventListeners(view: UIView, viewId: String, eventTypes: [String]) -> Bool {
        let normalizedEventTypes = eventTypes.map { normalizeEventName($0) }
        
        var allEventTypes = Set(eventTypes)
        allEventTypes.formUnion(normalizedEventTypes)
        
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
        
        let eventCallback: (String, String, [String: Any]) -> Void = { [weak self] (viewId, eventType, eventData) in
            guard let self = self else { return }
            self.sendEvent(viewId: viewId, eventName: eventType, eventData: eventData)
        }
        
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
            eventCallback,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        return true
    }
    
    func removeEventListeners(viewId: Int, eventTypes: [String]) -> Bool {
        guard let view = ViewRegistry.shared.getView(id: viewId) ?? DCFLayoutManager.shared.getView(withId: viewId) else {
            print("⚠️ DCMauiEventMethodHandler: View \(viewId) not found for event listener removal")
            return false
        }
        
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
                
                objc_setAssociatedObject(
                    view,
                    UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
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
            
            print("✅ DCMauiEventMethodHandler: Removed event listeners for view \(viewId): \(eventTypes)")
            return true
        } else {
            print("⚠️ DCMauiEventMethodHandler: No event listeners found for view \(viewId)")
            return false
        }
    }
}
