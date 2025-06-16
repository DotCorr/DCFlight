# DCFlight Module Development Guidelines

## 📋 **Overview**

This guide provides comprehensive instructions for developing custom components and modules for the DCFlight framework. Following these guidelines ensures consistency, performance, and compatibility with the DCFlight ecosystem.

## 🏗️ **Component Protocol Implementation**

### **1. Required Protocols**

Every DCFlight component must implement the `DCFComponent` protocol:

```swift
import UIKit
import dcflight

class YourCustomComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Component creation logic
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Component update logic
    }
}
```

### **2. Optional Protocols**

For components that handle custom methods:
```swift
class YourCustomComponent: NSObject, DCFComponent, ComponentMethodHandler {
    func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
        // Handle custom component methods
        switch methodName {
        case "customMethod":
            // Implementation
            return true
        default:
            return false
        }
    }
}
```

## 📝 **Component Registration Process**

### **1. Module Registration File**

Create a main registration file for your module (e.g., `YourModule.swift`):

```swift
import UIKit
import Flutter
import dcflight

@objc public class YourModule: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        // Register all your custom components
        DCFComponentRegistry.shared.registerComponent("CustomButton", componentClass: YourCustomButtonComponent.self)
        DCFComponentRegistry.shared.registerComponent("CustomSlider", componentClass: YourCustomSliderComponent.self)
        DCFComponentRegistry.shared.registerComponent("CustomChart", componentClass: YourCustomChartComponent.self)
        
        NSLog("✅ YourModule: All components registered successfully")
    }
}
```

### **2. Component Type Naming Convention**

- Use **PascalCase** for component type names
- Be descriptive and specific: `"CustomButton"` not `"Button"`
- Avoid conflicts with primitive components
- Include your module prefix for uniqueness

### **3. Registry Integration**

The `DCFComponentRegistry.shared.registerComponent()` method requires:
- **componentType**: String identifier used in Dart
- **componentClass**: Your component class that implements `DCFComponent`

## 🎯 **Event Handling Implementation**

### **1. Universal Event System Usage**

**✅ CORRECT - Use the Global Event System:**
```swift
class YourCustomComponent: NSObject, DCFComponent {
    @objc func handleCustomAction(_ sender: UIView) {
        // Use the universal propagateEvent function
        propagateEvent(on: sender, eventName: "onCustomAction", data: [
            "actionType": "custom",
            "timestamp": Date().timeIntervalSince1970,
            "customData": "your_data_here"
        ])
    }
}
```

**❌ INCORRECT - Don't Create Custom Event Systems:**
```swift
// DON'T DO THIS - Creates fragmented event handling
private func customEventTrigger(_ view: UIView, eventType: String, data: [String: Any]) {
    // Custom event implementation - AVOID
}
```

### **2. Event Normalization Requirements**

All events **MUST** follow the "on" prefix convention:

```swift
// ✅ CORRECT Event Names
propagateEvent(on: view, eventName: "onPress", data: [...])
propagateEvent(on: view, eventName: "onScroll", data: [...])
propagateEvent(on: view, eventName: "onCustomAction", data: [...])

// ❌ INCORRECT Event Names
propagateEvent(on: view, eventName: "press", data: [...])        // Missing "on" prefix
propagateEvent(on: view, eventName: "buttonClick", data: [...])  // Inconsistent naming
```

### **3. Event Data Structure Standards**

**Required Fields:**
```swift
let eventData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,  // Always include
    // Add your custom fields here
    "customField1": value1,
    "customField2": value2
]
```

**Common Event Data Patterns:**
```swift
// User Interaction Events
let interactionData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "x": touchLocation.x,
    "y": touchLocation.y
]

// Value Change Events
let valueChangeData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "oldValue": previousValue,
    "newValue": currentValue
]

// State Change Events
let stateChangeData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "previousState": oldState,
    "currentState": newState
]
```

## 🎨 **Adaptive Theming Implementation**

### **1. Adaptive Flag Requirement**

**CRITICAL**: All components must implement adaptive theming support:

```swift
func createView(props: [String: Any]) -> UIView {
    let view = YourCustomView()
    
    // ✅ REQUIRED: Check adaptive flag
    let isAdaptive = props["adaptive"] as? Bool ?? true
    
    if isAdaptive {
        // Use system colors that automatically adapt to light/dark mode
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
            view.tintColor = UIColor.label
        } else {
            // Fallback for older iOS versions
            view.backgroundColor = UIColor.white
            view.tintColor = UIColor.black
        }
    } else {
        // Use explicit colors when adaptive is disabled
        view.backgroundColor = UIColor.clear
    }
    
    // Apply StyleSheet properties AFTER adaptive setup
    view.applyStyles(props: props)
    
    return view
}
```

### **2. System Color Usage**

**✅ REQUIRED System Colors for Adaptive Components:**
```swift
// Text Colors
UIColor.label           // Primary text
UIColor.secondaryLabel  // Secondary text
UIColor.tertiaryLabel   // Tertiary text

// Background Colors
UIColor.systemBackground           // Primary background
UIColor.secondarySystemBackground  // Secondary background
UIColor.tertiarySystemBackground   // Tertiary background

// UI Element Colors
UIColor.systemBlue     // Primary actions
UIColor.systemGreen    // Success states
UIColor.systemRed      // Error states
UIColor.systemOrange   // Warning states
```

### **3. Adaptive Theming Pattern**

```swift
private func applyAdaptiveColors(_ view: UIView, isAdaptive: Bool) {
    if isAdaptive {
        if #available(iOS 13.0, *) {
            // Modern adaptive colors
            view.backgroundColor = UIColor.systemBackground
        } else {
            // Legacy fallback
            view.backgroundColor = UIColor.white
        }
    } else {
        // Non-adaptive explicit colors
        view.backgroundColor = UIColor.clear
    }
}
```

## 📊 **Props and StyleSheet Integration**

### **1. Component-Specific Props Handling**

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let customView = view as? YourCustomView else { return false }
    
    // Handle component-specific props FIRST
    if let customTitle = props["customTitle"] as? String {
        customView.setCustomTitle(customTitle)
    }
    
    if let customValue = props["customValue"] as? Double {
        customView.setValue(customValue)
    }
    
    if let isEnabled = props["enabled"] as? Bool {
        customView.isUserInteractionEnabled = isEnabled
    }
    
    // ✅ CRITICAL: Apply StyleSheet properties LAST
    // This ensures StyleSheet overrides component defaults
    view.applyStyles(props: props)
    
    return true
}
```

### **2. Props Processing Order**

**REQUIRED Order:**
1. **Adaptive theming setup** (in `createView`)
2. **Component-specific props** (custom functionality)
3. **StyleSheet application** (visual styling)

```swift
func createView(props: [String: Any]) -> UIView {
    let view = YourCustomView()
    
    // 1. Adaptive theming setup
    let isAdaptive = props["adaptive"] as? Bool ?? true
    applyAdaptiveColors(view, isAdaptive: isAdaptive)
    
    // 2. Component-specific props
    updateView(view, withProps: props)
    
    // 3. StyleSheet application (called within updateView)
    
    return view
}
```

### **3. StyleSheet Property Support**

Ensure your component supports standard StyleSheet properties:

```swift
// The view.applyStyles(props: props) call automatically handles:
// - backgroundColor, borderRadius, borderWidth, borderColor
// - opacity, margin, padding
// - width, height, flex properties
// - shadows, gradients, transforms

// You only need to handle component-specific properties manually
```

## 🚀 **Performance and Memory Management**

### **1. Singleton Pattern for Event Handlers**

```swift
class YourCustomComponent: NSObject, DCFComponent {
    // ✅ Use singleton for event target to prevent deallocation
    private static let sharedInstance = YourCustomComponent()
    
    @objc func handleEvent(_ sender: UIView) {
        propagateEvent(on: sender, eventName: "onEvent", data: [:])
    }
    
    func setupEventHandlers(_ view: UIView) {
        // Use shared instance as target
        if let button = view as? UIButton {
            button.addTarget(YourCustomComponent.sharedInstance, 
                           action: #selector(handleEvent(_:)), 
                           for: .touchUpInside)
        }
    }
}
```

### **2. Memory Cleanup**

```swift
// Implement cleanup if your component holds references
func cleanupComponent(_ view: UIView) {
    // Remove gesture recognizers
    view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
    
    // Clear delegates
    if let scrollView = view as? UIScrollView {
        scrollView.delegate = nil
    }
    
    // Remove observers
    NotificationCenter.default.removeObserver(view)
}
```

## 🛡️ **Error Handling and Validation**

### **1. Props Validation**

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let customView = view as? YourCustomView else { 
        NSLog("❌ YourCustomComponent: Invalid view type")
        return false 
    }
    
    // Validate required props
    guard let requiredProp = props["requiredProp"] as? String else {
        NSLog("⚠️ YourCustomComponent: Missing required prop 'requiredProp'")
        return false
    }
    
    // Validate prop values
    if let numericProp = props["numericProp"] as? Double {
        guard numericProp >= 0 && numericProp <= 100 else {
            NSLog("⚠️ YourCustomComponent: numericProp out of range (0-100)")
            return false
        }
    }
    
    // Apply validated props...
    view.applyStyles(props: props)
    return true
}
```

### **2. Graceful Degradation**

```swift
func createView(props: [String: Any]) -> UIView {
    let view = YourCustomView()
    
    // Set sensible defaults
    view.backgroundColor = UIColor.clear
    view.isUserInteractionEnabled = true
    
    // Apply props with fallbacks
    let isAdaptive = props["adaptive"] as? Bool ?? true  // Default to adaptive
    let customTitle = props["title"] as? String ?? "Default Title"
    
    // Configure view...
    return view
}
```

## 🧪 **Testing and Debugging**

### **1. Debug Logging**

```swift
func createView(props: [String: Any]) -> UIView {
    #if DEBUG
    NSLog("🆕 YourCustomComponent createView with props: \(props.keys.sorted())")
    #endif
    
    // Component creation logic...
}

func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    #if DEBUG
    NSLog("🔄 YourCustomComponent updateView with props: \(props.keys.sorted())")
    #endif
    
    // Component update logic...
    return true
}
```

### **2. Event Testing**

```swift
@objc func handleTestEvent(_ sender: UIView) {
    #if DEBUG
    NSLog("🎯 YourCustomComponent: Test event triggered")
    #endif
    
    propagateEvent(on: sender, eventName: "onTestEvent", data: [
        "testData": "success",
        "timestamp": Date().timeIntervalSince1970
    ])
}
```

## ⚡ **VDOM Smart Diffing and Prop Handling**

### **Critical Understanding: How VDOM Prop Diffing Works**

DCFlight's VDOM implements intelligent prop diffing to optimize performance by only sending changed properties to the native side. **This behavior is crucial to understand for proper component development.**

### **The Smart Diffing Algorithm**

```dart
// VDOM only sends props that have changed
Map<String, dynamic> _diffProps(oldProps, newProps) {
  Map<String, dynamic> changedProps = {};
  
  for (String key in newProps.keys) {
    if (!oldProps.containsKey(key) || oldProps[key] != newProps[key]) {
      changedProps[key] = newProps[key];  // Only changed props
    }
  }
  
  return changedProps;
}
```

### **Prop Handling Patterns**

#### **❌ Individual Props (Get Filtered)**
```dart
// These individual props get optimized by VDOM
Map<String, dynamic> props = {
  'title': 'My Title',      // ⚠️ Only sent when title changes
  'message': 'My Message',  // ⚠️ Only sent when message changes
  'visible': true,          // ✅ Sent when visible state changes
};
```

**Problem**: When only `visible` changes from `false` to `true`, VDOM won't send `title` and `message` because they "haven't changed."

#### **✅ Structured Objects (Always Complete)**
```dart
// These structured objects are always sent completely
Map<String, dynamic> props = {
  'visible': true,
  
  // ✅ Always sent as complete object
  'alertContent': {
    'title': 'My Title',
    'message': 'My Message',
  },
  
  // ✅ Always sent as complete array
  'actions': [
    {'title': 'OK', 'style': 'default'},
    {'title': 'Cancel', 'style': 'cancel'}
  ],
};
```

**Solution**: Group related props into structured objects that VDOM treats as atomic units.

### **Component Development Rule**

> **For props that must ALWAYS be available to the native side (even when they haven't "changed"), wrap them in a structured object rather than sending as individual props.**

### **Real-World Example: Alert Component**

**❌ Problematic Pattern:**
```dart
// Dart Component
DCFAlert(
  visible: visible,
  title: "Important Alert",     // Gets filtered out
  message: "Please confirm",    // Gets filtered out
  actions: [...],              // Always sent (array)
)

// iOS receives when visible becomes true:
{
  'visible': true,
  'actions': [...],
  // title and message MISSING!
}
```

**✅ Correct Pattern:**
```dart
// Dart Component  
DCFAlert(
  visible: visible,
  alertContent: {              // Always sent completely
    'title': "Important Alert",
    'message': "Please confirm",
  },
  actions: [...],
)

// iOS receives when visible becomes true:
{
  'visible': true,
  'alertContent': {
    'title': "Important Alert",
    'message': "Please confirm"
  },
  'actions': [...],
}
```

**iOS Implementation:**
```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    if let visible = props["visible"] as? Bool, visible {
        // Extract from structured object (like actions)
        var title: String?
        var message: String?
        
        if let alertContent = props["alertContent"] as? [String: Any] {
            title = alertContent["title"] as? String
            message = alertContent["message"] as? String
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        // ... rest of implementation
    }
}
```

### **When to Use Each Pattern**

#### **Individual Props** (Get Optimized)
- ✅ State flags: `visible`, `enabled`, `selected`
- ✅ Simple configuration: `style`, `dismissible`
- ✅ Single values that change independently

#### **Structured Objects** (Always Complete)
- ✅ Related data that native side needs together
- ✅ Complex configurations
- ✅ Collections/arrays
- ✅ Content that must be available when component becomes active

## 📺 **Screen API - Content Teleportation System**

### **Overview**

The Screen API provides a general-purpose content teleportation system that allows wrapper components (modals, alerts, popovers, etc.) to own and manage their content without component-specific hacks in the VDOM or bridge.

### **Core Components**

#### **DCFScreen** - Content Teleporter
```dart
DCFScreen(
  hostName: 'modal_overlay',     // Target host name
  screenId: 'unique_id',         // Optional: for content replacement
  children: [                    // Content to teleport
    DCFText(props: DCFTextProps(text: 'Modal content')),
  ],
)
```

#### **DCFScreenHost** - Content Receiver
```dart
DCFScreenHost(
  hostName: 'modal_overlay',     // Host identifier
  fallbackChildren: [            // Content when no screens
    DCFText(props: DCFTextProps(text: 'No content')),
  ],
)
```

### **Usage Patterns**

#### **1. Modal/Overlay Pattern**
```dart
class ModalComponent extends StatelessComponent {
  final bool visible;
  final List<DCFComponentNode> children;

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'View',
      children: [
        // Overlay host positioned absolutely
        DCFElement(
          type: 'View',
          props: {
            'style': {
              'position': 'absolute',
              'top': 0, 'left': 0, 'right': 0, 'bottom': 0,
              'zIndex': 1000,
              'pointerEvents': visible ? 'auto' : 'none',
            }
          },
          children: [
            DCFScreenHost(hostName: 'modal_${key ?? hashCode}'),
          ],
        ),

        // Content teleported when visible
        if (visible)
          DCFScreen(
            hostName: 'modal_${key ?? hashCode}',
            children: children,
          ),
      ],
    );
  }
}
```

#### **2. Multiple Host Pattern**
```dart
// Different content targets different hosts
DCFScreen(hostName: 'alerts', children: [alertContent]),
DCFScreen(hostName: 'toasts', children: [toastContent]),
DCFScreen(hostName: 'modals', children: [modalContent]),

// Each host renders its specific content
DCFScreenHost(hostName: 'alerts'),   // Top-level alerts
DCFScreenHost(hostName: 'toasts'),   // Toast notifications  
DCFScreenHost(hostName: 'modals'),   // Modal dialogs
```

### **Benefits Over Component-Specific Hacks**

#### **❌ Before (Modal Hacks - Now Removed)**
```swift
// REMOVED: Component-specific protocol and hacks
// DCFPresentComponentProtocol, child hiding, associated objects, etc.
// These modal-specific hacks have been completely removed from the codebase
```

#### **✅ After (Screen API)**
```dart
// General-purpose components
DCFScreen(hostName: 'modal', children: [content])
DCFScreenHost(hostName: 'modal')

// No bridge hacks, no hidden views, no component-specific protocols
```

### **Advantages**

- **✅ General Purpose**: Works for any wrapper component type
- **✅ Clean Architecture**: No VDOM or bridge hacks
- **✅ Flexible**: Multiple named hosts, dynamic content
- **✅ Performant**: Standard VDOM reconciliation
- **✅ Debuggable**: Easy to trace content flow

### **When to Use Screen API**

#### **Perfect For:**
- Modal dialogs and sheets
- Alert overlays
- Toast notifications  
- Popovers and tooltips
- Drawer/sidebar content
- Any content that needs to escape its container

#### **Not Needed For:**
- Standard layout components (View, Stack, etc.)
- Simple prop-based components
- Components that don't need content teleportation

## 📋 **Compliance Checklist**

Before submitting your component module, ensure:

- [ ] ✅ Implements `DCFComponent` protocol correctly
- [ ] ✅ Uses `propagateEvent()` for all events
- [ ] ✅ All event names start with "on" prefix
- [ ] ✅ Implements adaptive theming with `adaptive` flag support
- [ ] ✅ Uses system colors for adaptive components
- [ ] ✅ Calls `view.applyStyles(props: props)` for StyleSheet integration
- [ ] ✅ Handles component-specific props before StyleSheet application
- [ ] ✅ Includes proper error handling and validation
- [ ] ✅ Follows naming conventions for component types
- [ ] ✅ Registers components correctly with `DCFComponentRegistry`
- [ ] ✅ Uses singleton pattern for event handlers
- [ ] ✅ Includes debug logging for development

## ⚠️ **Non-Compliance Consequences**

**Failure to follow these guidelines will result in:**
- ❌ Module merge request rejection
- ❌ Framework inconsistencies
- ❌ Poor user experience with theming
- ❌ Event handling bugs
- ❌ Performance issues

## 🚀 **Success Benefits**

**Following these guidelines ensures:**
- ✅ Seamless integration with DCFlight ecosystem
- ✅ Consistent theming across light/dark modes
- ✅ Reliable event handling
- ✅ Optimal performance
- ✅ Easy maintenance and updates
- ✅ Community adoption and support

## 📞 **Support and Resources**

- **Event System**: See `/docs/architecture/EVENT_LIFECYCLE_AND_CALLBACKS.md`
- **Styling System**: See `/docs/styling/` folder
- **Component Examples**: See `/packages/dcf_primitives/ios/Classes/Components/`
- **Testing Guidelines**: See `/docs/testing/`

Following these guidelines ensures your module integrates perfectly with the DCFlight framework and provides a consistent, high-quality experience for developers and users.
