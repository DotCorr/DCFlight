# DCFlight Event Normalization and Naming Conventions

## 📋 **Overview**

DCFlight implements a comprehensive event normalization system that ensures consistent event naming across all components and modules. This document details the normalization process and naming conventions that all components must follow.

## 🎯 **Event Naming Convention**

### **Universal "on" Prefix Rule**

**CRITICAL REQUIREMENT**: All events in DCFlight **MUST** follow the "on" prefix convention:

```swift
// ✅ CORRECT Event Names
"onPress"         // Button press
"onScroll"        // Scroll view scrolling
"onTextChange"    // Text input change
"onFocus"         // Input focus
"onBlur"          // Input blur
"onCustomAction"  // Custom component action

// ❌ INCORRECT Event Names
"press"           // Missing "on" prefix
"buttonClick"     // Inconsistent naming
"textChanged"     // Wrong tense
"customAction"    // Missing "on" prefix
```

### **Naming Pattern Structure**

```
Event Name Format: on + [Action] + [Optional Qualifier]

Examples:
- onPress (simple action)
- onPressIn (action with qualifier)
- onPressOut (action with qualifier)
- onScrollBeginDrag (complex action with qualifier)
- onScrollEndDrag (complex action with qualifier)
```

## 🔄 **Normalization Process**

### **1. Native Side Normalization**

When components trigger events, the normalization happens automatically:

```swift
// Component triggers event (any format)
propagateEvent(on: view, eventName: "press", data: [...])  // Input: "press"

// Automatic normalization occurs
private func normalizeEventNameForPropagation(_ name: String) -> String {
    var processedName = name
    
    // Remove "on" prefix if it exists
    if processedName.hasPrefix("on") {
        processedName = String(processedName.dropFirst(2))
    }
    
    if processedName.isEmpty {
        return "onEvent"
    }
    
    // Add "on" prefix with proper capitalization
    return "on\(processedName.prefix(1).uppercased())\(processedName.dropFirst())"
}

// Result: "press" → "onPress"
```

### **2. Method Channel Normalization**

Additional normalization occurs when events are sent to Dart:

```swift
private func normalizeEventName(_ name: String) -> String {
    // If already has "on" prefix and is properly formatted, return as is
    if name.hasPrefix("on") && name.count > 2 {
        let thirdCharIndex = name.index(name.startIndex, offsetBy: 2)
        if name[thirdCharIndex].isUppercase {
            return name  // "onPress" → "onPress"
        }
    }
    
    // Otherwise normalize
    var processedName = name
    if processedName.hasPrefix("on") {
        processedName = String(processedName.dropFirst(2))
    }
    
    return "on\(processedName.prefix(1).uppercased())\(processedName.dropFirst())"
}
```

### **3. Dart Side Event Matching**

The Dart VDOM handles multiple event name formats for maximum compatibility:

```dart
void _handleNativeEvent(String viewId, String eventType, Map<dynamic, dynamic> eventData) {
    // Try multiple event handler formats to ensure compatibility
    final eventHandlerKeys = [
        eventType,                    // exact match (e.g., 'onScroll')
        'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}', // onEventName format
        eventType.toLowerCase(),      // lowercase
        'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}' // normalized
    ];
    
    for (final key in eventHandlerKeys) {
        if (node.props.containsKey(key) && node.props[key] is Function) {
            _executeEventHandler(node.props[key], eventData);
            return;
        }
    }
}
```

## 📊 **Event Name Examples by Component Type**

### **Button Components**
```swift
// Primary actions
"onPress"      // Main button press
"onPressIn"    // Touch down
"onPressOut"   // Touch up/cancel
"onLongPress"  // Long press gesture
```

### **Input Components**
```swift
// Text manipulation
"onTextChange"     // Text content changed
"onFocus"          // Input gained focus
"onBlur"           // Input lost focus
"onSubmitEditing"  // Return key pressed
"onKeyPress"       // Individual key press
```

### **Scroll Components**
```swift
// Scroll actions
"onScroll"              // Continuous scrolling
"onScrollBeginDrag"     // User starts dragging
"onScrollEndDrag"       // User stops dragging
"onScrollEnd"           // Scrolling animation ends
"onContentSizeChange"   // Content size changes
```

### **Gesture Components**
```swift
// Touch gestures
"onTap"        // Single tap
"onDoubleTap"  // Double tap
"onLongPress"  // Long press
"onPanStart"   // Pan gesture begins
"onPanUpdate"  // Pan gesture updates
"onPanEnd"     // Pan gesture ends
"onSwipeLeft"  // Swipe left
"onSwipeRight" // Swipe right
"onSwipeUp"    // Swipe up
"onSwipeDown"  // Swipe down
```

### **Media Components**
```swift
// Loading states
"onLoad"       // Resource loaded successfully
"onError"      // Loading error occurred
"onProgress"   // Loading progress update

// Playback states (for video/audio)
"onPlay"       // Playback started
"onPause"      // Playback paused
"onEnd"        // Playback finished
```

### **Animation Components**
```swift
// Animation lifecycle
"onAnimationStart"   // Animation began
"onAnimationEnd"     // Animation completed
"onAnimationCancel"  // Animation cancelled
"onAnimationRepeat"  // Animation repeated
```

## 🔧 **Implementation Guidelines for Component Developers**

### **1. Use Descriptive Action Names**

```swift
// ✅ GOOD - Clear and descriptive
"onPress"           // Button pressed
"onTextChange"      // Text content changed
"onScrollEnd"       // Scrolling ended
"onImageLoad"       // Image loaded

// ❌ BAD - Vague or unclear
"onChange"          // Change of what?
"onEvent"           // What kind of event?
"onAction"          // What action?
"onUpdate"          // Update of what?
```

### **2. Use Consistent State Qualifiers**

```swift
// ✅ GOOD - Consistent state naming
"onStart" / "onEnd"           // For processes
"onBegin" / "onComplete"      // For operations
"onShow" / "onHide"           // For visibility
"onOpen" / "onClose"          // For state changes
"onExpand" / "onCollapse"     // For size changes

// ❌ BAD - Inconsistent qualifiers
"onStart" / "onFinish"        // Mixed terminology
"onBegin" / "onStop"          // Mismatched pairs
"onShow" / "onDisappear"      // Different word styles
```

### **3. Follow Component-Specific Patterns**

```swift
// For interactive components
class YourInteractiveComponent {
    @objc func handleUserAction(_ sender: UIView) {
        propagateEvent(on: sender, eventName: "onPress", data: [...])
    }
}

// For input components
class YourInputComponent {
    @objc func handleTextChange(_ textField: UITextField) {
        propagateEvent(on: textField, eventName: "onTextChange", data: [
            "text": textField.text ?? ""
        ])
    }
}

// For animated components
class YourAnimatedComponent {
    func animationDidStart(_ anim: CAAnimation) {
        propagateEvent(on: self.view, eventName: "onAnimationStart", data: [:])
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        let eventName = flag ? "onAnimationEnd" : "onAnimationCancel"
        propagateEvent(on: self.view, eventName: eventName, data: [:])
    }
}
```

## 🛡️ **Event Name Validation**

### **Runtime Validation (Debug Mode)**

```swift
#if DEBUG
private func validateEventName(_ eventName: String) -> Bool {
    // Check for "on" prefix
    guard eventName.hasPrefix("on") else {
        NSLog("⚠️ Event Validation: Event name '\(eventName)' should start with 'on'")
        return false
    }
    
    // Check for proper capitalization
    guard eventName.count > 2 else {
        NSLog("⚠️ Event Validation: Event name '\(eventName)' is too short")
        return false
    }
    
    let thirdChar = eventName[eventName.index(eventName.startIndex, offsetBy: 2)]
    guard thirdChar.isUppercase else {
        NSLog("⚠️ Event Validation: Event name '\(eventName)' should use camelCase after 'on'")
        return false
    }
    
    return true
}
#endif
```

### **Component Self-Validation**

```swift
func propagateEvent(on view: UIView, eventName: String, data eventData: [String: Any] = [:]) {
    #if DEBUG
    validateEventName(eventName)
    #endif
    
    // Normal event propagation...
}
```

## 📈 **Performance Considerations**

### **1. Normalization Caching**

The normalization process is optimized to avoid repeated string operations:

```swift
// Cached normalization results
private static var normalizationCache: [String: String] = [:]

private func normalizeEventNameCached(_ name: String) -> String {
    if let cached = Self.normalizationCache[name] {
        return cached
    }
    
    let normalized = normalizeEventName(name)
    Self.normalizationCache[name] = normalized
    return normalized
}
```

### **2. Early Event Filtering**

Events are validated early in the pipeline to avoid unnecessary processing:

```swift
func propagateEvent(on view: UIView, eventName: String, data eventData: [String: Any] = [:]) {
    // Quick validation before processing
    guard !eventName.isEmpty else { return }
    
    // Check if event is registered on the view
    guard let eventTypes = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!) as? [String] else {
        return // No events registered, skip processing
    }
    
    // Continue with normalization and propagation...
}
```

## 🎯 **Migration Guide for Existing Components**

### **Updating Non-Conforming Events**

```swift
// OLD - Non-conforming event names
propagateEvent(on: view, eventName: "press", data: [...])
propagateEvent(on: view, eventName: "textChanged", data: [...])
propagateEvent(on: view, eventName: "scrolling", data: [...])

// NEW - Conforming event names
propagateEvent(on: view, eventName: "onPress", data: [...])
propagateEvent(on: view, eventName: "onTextChange", data: [...])
propagateEvent(on: view, eventName: "onScroll", data: [...])
```

### **Updating Dart Event Handlers**

```dart
// OLD - Various naming styles
DCFElement(
    type: 'Button',
    props: {
        'press': () => print('Pressed'),           // Non-conforming
        'onClick': () => print('Clicked'),         // Web-style
        'buttonTapped': () => print('Tapped'),     // iOS-style
    }
)

// NEW - Consistent DCFlight style
DCFElement(
    type: 'Button',
    props: {
        'onPress': () => print('Pressed'),         // DCFlight standard
        'onLongPress': () => print('Long pressed'), // Extended interaction
    }
)
```

## 🚀 **Benefits of Event Normalization**

### **1. Framework Consistency**
- All components use the same event naming convention
- Predictable event names across the entire ecosystem
- Reduced learning curve for developers

### **2. Enhanced Developer Experience**
- IDE autocomplete works reliably
- Event discovery is intuitive
- Documentation is consistent

### **3. Improved Maintainability**
- Single normalization system to maintain
- Easy to add new event types
- Backwards compatibility when needed

### **4. Better Tooling Support**
- Static analysis tools can validate event names
- Build-time warnings for non-conforming events
- Automated refactoring support

This normalization system ensures that DCFlight maintains a consistent, professional, and developer-friendly event handling experience across all components and modules.
