# DCFlight Event Lifecycle and Callbacks Architecture

## 📋 **Overview**

DCFlight implements a robust, universal event system that handles all component interactions through a unified architecture. This document explains the complete event lifecycle, from native iOS interactions to Dart callback execution.

## 🔄 **Event Flow Architecture**

### **1. Event Trigger (Native iOS)**
```swift
// Any component can trigger events using the universal propagateEvent function
@objc func handleButtonPress(_ sender: UIButton) {
    propagateEvent(on: sender, eventName: "onPress", data: [
        "pressed": true,
        "timestamp": Date().timeIntervalSince1970
    ])
}
```

### **2. Event Propagation System**
```swift
public func propagateEvent(on view: UIView, eventName: String, data eventData: [String: Any] = [:]) {
    // 1. Retrieve stored event callback from the view
    guard let callback = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) 
            as? (String, String, [String: Any]) -> Void else {
        return
    }
    
    // 2. Get the view ID
    guard let viewId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String else {
        return
    }
    
    // 3. Verify event is registered
    guard let eventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] else {
        return
    }
    
    // 4. Normalize event name and propagate
    let normalizedEventName = normalizeEventNameForPropagation(eventName)
    callback(viewId, normalizedEventName, eventData)
}
```

### **3. Event Normalization**
All events are normalized to follow the "on" prefix convention:
```swift
private func normalizeEventNameForPropagation(_ name: String) -> String {
    // Examples:
    // "press" -> "onPress"
    // "scroll" -> "onScroll"
    // "onTap" -> "onTap" (already normalized)
    
    var processedName = name
    if processedName.hasPrefix("on") {
        processedName = String(processedName.dropFirst(2))
    }
    return "on\(processedName.prefix(1).uppercased())\(processedName.dropFirst())"
}
```

### **4. Method Channel Bridge**
```swift
func sendEvent(viewId: String, eventName: String, eventData: [String: Any]) {
    let normalizedEventName = normalizeEventName(eventName)
    
    if let callback = self.eventCallback {
        // Direct callback to Dart
        callback(viewId, normalizedEventName, eventData)
    } else if let channel = methodChannel {
        // Fallback to method channel
        methodChannel?.invokeMethod("onEvent", arguments: [
            "viewId": viewId,
            "eventType": normalizedEventName,
            "eventData": eventData
        ])
    }
}
```

### **5. VDOM Event Handling**
```dart
void _handleNativeEvent(String viewId, String eventType, Map<dynamic, dynamic> eventData) {
    final node = _nodesByViewId[viewId];
    if (node == null) return;
    
    if (node is DCFElement) {
        // Try multiple event handler formats for compatibility
        final eventHandlerKeys = [
            eventType,                    // exact match (e.g., 'onScroll')
            'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}',
            eventType.toLowerCase(),
            'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}'
        ];
        
        for (final key in eventHandlerKeys) {
            if (node.props.containsKey(key) && node.props[key] is Function) {
                _executeEventHandler(node.props[key], eventData);
                return;
            }
        }
    }
}
```

### **6. Dynamic Event Handler Execution**
```dart
void _executeEventHandler(Function handler, Map<dynamic, dynamic> eventData) {
    try {
        // 1st attempt: Direct Map<dynamic, dynamic> call
        if (eventData.isNotEmpty) {
            Function.apply(handler, [eventData]);
            return;
        }
        
        // 2nd attempt: No parameters for simple events
        Function.apply(handler, []);
        return;
    } catch (e) {
        // Try specific patterns for common event types
        if (eventData.containsKey('text')) {
            // Handle TextInput events that expect a string parameter
            final text = eventData['text'] as String? ?? '';
            Function.apply(handler, [text]);
            return;
        }
        
        if (eventData.containsKey('width') && eventData.containsKey('height')) {
            // Handle size change events that expect (double, double)
            final width = eventData['width'] as double? ?? 0.0;
            final height = eventData['height'] as double? ?? 0.0;
            Function.apply(handler, [width, height]);
            return;
        }
        
        // Final fallback - dynamic invocation
        (handler as dynamic)(eventData);
    }
}
```

## 🎯 **Event Registration Process**

### **1. Component Event Registration**
When a component is created in Dart with event handlers:
```dart
DCFElement(
    type: 'Button',
    props: {
        'title': 'Click Me',
        'onPress': (Map<dynamic, dynamic> eventData) {
            print('Button pressed: ${eventData['timestamp']}');
        }
    }
)
```

### **2. Native Event Listener Setup**
The VDOM automatically registers event listeners:
```dart
// Extract event types from props
final eventTypes = element.eventTypes; // ['onPress']

// Register with native bridge
await _nativeBridge.addEventListeners(viewId, eventTypes);
```

### **3. Native Storage of Event Info**
```swift
// Store event registration info on the view
objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "viewId".hashValue)!, viewId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!, eventTypes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!, eventCallback, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
```

## 🔄 **Event Lifecycle States**

### **1. Registration Phase**
- Component created in Dart with event handlers
- VDOM extracts event types from props
- Native bridge registers event listeners
- Event callback stored on native view

### **2. Active Phase**
- User interacts with component (tap, scroll, etc.)
- Native component triggers `propagateEvent()`
- Event data normalized and validated
- Event propagated to Dart via callback

### **3. Reconciliation Phase**
- Component state changes trigger VDOM reconciliation
- Event listeners preserved through view ID reuse
- Only changed event types updated (add/remove)
- No event connection loss during updates

### **4. Cleanup Phase**
- Component unmounted or view deleted
- Event listeners removed from native view
- Associated objects cleared
- Memory properly released

## 🛡️ **Event Connection Preservation**

### **Critical Fix: View ID Reuse**
```dart
// CRITICAL EVENT FIX: Instead of deleting and recreating the view,
// reuse the same view ID to preserve native event listener connections
newNode.nativeViewId = oldViewId;

// Update the mapping to point to the new node IMMEDIATELY
_nodesByViewId[oldViewId] = newNode;

// Only update event listeners if they changed
final oldEventSet = Set<String>.from(oldEventTypes);
final newEventSet = Set<String>.from(newEventTypes);

if (oldEventSet.length != newEventSet.length || !oldEventSet.containsAll(newEventSet)) {
    // Remove obsolete event listeners
    final eventsToRemove = oldEventSet.difference(newEventSet);
    if (eventsToRemove.isNotEmpty) {
        await _nativeBridge.removeEventListeners(oldViewId, eventsToRemove.toList());
    }
    
    // Add new event listeners
    final eventsToAdd = newEventSet.difference(oldEventSet);
    if (eventsToAdd.isNotEmpty) {
        await _nativeBridge.addEventListeners(oldViewId, eventsToAdd.toList());
    }
}
```

## 📊 **Event Data Standardization**

### **Common Event Data Fields**
```swift
let standardEventData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,  // Always include
    "componentType": "DCFButtonComponent",      // Component identifier
    "viewId": viewId                           // View identifier
]
```

### **Component-Specific Event Data**
```swift
// Button Events
propagateEvent(on: button, eventName: "onPress", data: [
    "pressed": true,
    "buttonTitle": button.title(for: .normal) ?? ""
])

// Scroll Events
propagateEvent(on: scrollView, eventName: "onScroll", data: [
    "contentOffset": ["x": scrollView.contentOffset.x, "y": scrollView.contentOffset.y],
    "contentSize": ["width": scrollView.contentSize.width, "height": scrollView.contentSize.height]
])

// Gesture Events
propagateEvent(on: view, eventName: "onTap", data: [
    "x": location.x,
    "y": location.y
])
```

## 🎯 **Performance Optimizations**

### **1. Event Handler Caching**
- Event callbacks stored as associated objects on views
- No repeated lookups during frequent events
- Direct function pointer execution

### **2. Batch Event Processing**
- Multiple events batched during VDOM updates
- Reduced bridge calls and improved performance
- Atomic event listener updates

### **3. Smart Event Filtering**
- Only registered event types processed
- Unregistered events ignored early in the pipeline
- Minimal performance impact for unused events

## 🔧 **Debugging and Monitoring**

### **Event Debug Information**
```swift
print("🔍 DEBUG: Attempting to propagate \(eventName) on view \(view)")
print("🔍 DEBUG: Found viewId: \(viewId), eventTypes: \(eventTypes)")
print("🚀 Propagating \(eventName) event to Dart for view \(viewId)")
```

### **Event Validation**
```dart
if (kDebugMode) {
    developer.log('🎯 Handling event: $eventType for viewId: $viewId, node type: ${node.runtimeType}', name: 'VDom');
    developer.log('🔍 Trying event handler keys: $eventHandlerKeys', name: 'VDom');
    developer.log('✅ Found event handler for key: $key', name: 'VDom');
}
```

## 🚀 **Future-Proof Architecture**

The DCFlight event system is designed to be:

- **Universal**: Works with any component type
- **Flexible**: Handles any function signature dynamically
- **Robust**: Preserves connections during reconciliation
- **Performant**: Minimal overhead and smart caching
- **Developer-Friendly**: Simple `propagateEvent()` API for component developers

This architecture ensures that event handling remains consistent, reliable, and maintainable as the framework evolves.
