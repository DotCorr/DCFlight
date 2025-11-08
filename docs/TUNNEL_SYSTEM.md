# Tunnel System
## Direct Native Method Calls (Bypasses VDOM)

The tunnel system allows Dart to call methods directly on native components, bypassing the VDOM layer. This is useful for framework-specific operations that don't need to go through the component lifecycle.

---

## How It Works

### Architecture

```
Dart Code                    Native Component
    │                              │
    │  FrameworkTunnel.call()      │
    │                              │
    ├──────────────────────────────┤
    │                              │
    │  PlatformInterface.tunnel()  │
    │  (MethodChannel)              │
    │                              │
    ├──────────────────────────────┤
    │                              │
    │  Registry lookup             │
    │  └─> getComponent("Type")    │
    │                              │
    ├──────────────────────────────┤
    │                              │
    │  handleTunnelMethod()        │
    │  (Static on iOS)             │
    │  (Instance on Android)       │
    │                              │
    └──────────────────────────────┘
```

---

## Dart Side

### Usage

```dart
import 'package:dcflight/framework/renderer/interface/tunnel.dart';

// Call a method on a component
final result = await FrameworkTunnel.call(
  'ComponentType',  // Must match registered component name
  'methodName',     // Method name
  {'param1': 'value1', 'param2': 123}  // Parameters
);
```

### Example: Animation Control

```dart
// Pause an animation
await FrameworkTunnel.call('ReanimatedView', 'executeCommand', {
  'controllerId': 'box1',
  'command': {'type': 'pause'}
});

// Reset all animations
await FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
  'groupId': 'modal_animations',
  'command': {'type': 'resetAll'}
});
```

---

## iOS Implementation

### Protocol Requirement

```swift
public protocol DCFComponent {
    // ... other methods
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any?
}
```

### Implementation Example

```swift
class DCFTextInputComponent: NSObject, DCFComponent {
    // ... other methods
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        switch method {
        case "focus":
            // Focus the input field
            // Note: Static method, so we need to find the view
            if let viewId = params["viewId"] as? String,
               let view = ViewRegistry.shared.getView(id: viewId) as? UITextField {
                view.becomeFirstResponder()
                return true
            }
            return false
            
        case "blur":
            // Blur the input field
            if let viewId = params["viewId"] as? String,
               let view = ViewRegistry.shared.getView(id: viewId) as? UITextField {
                view.resignFirstResponder()
                return true
            }
            return false
            
        case "getText":
            // Get current text
            if let viewId = params["viewId"] as? String,
               let view = ViewRegistry.shared.getView(id: viewId) as? UITextField {
                return view.text
            }
            return nil
            
        default:
            return nil  // Method not supported
        }
    }
}
```

**Key Points:**
- ✅ Static method (called on class, not instance)
- ✅ Must look up view from ViewRegistry using viewId
- ✅ Return result or `nil` if method not supported

---

## Android Implementation

### Abstract Method Requirement

```kotlin
abstract class DCFComponent {
    // ... other methods
    
    abstract fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any?
}
```

### Implementation Example

```kotlin
class DCFTextInputComponent : DCFComponent() {
    // ... other methods
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "focus" -> {
                // Focus the input field
                val viewId = arguments["viewId"] as? String
                val view = ViewRegistry.shared.getView(viewId) as? EditText
                view?.requestFocus()
                view != null
            }
            
            "blur" -> {
                // Blur the input field
                val viewId = arguments["viewId"] as? String
                val view = ViewRegistry.shared.getView(viewId) as? EditText
                view?.clearFocus()
                view != null
            }
            
            "getText" -> {
                // Get current text
                val viewId = arguments["viewId"] as? String
                val view = ViewRegistry.shared.getView(viewId) as? EditText
                view?.text?.toString()
            }
            
            else -> null  // Method not supported
        }
    }
}
```

**Key Points:**
- ✅ Instance method (called on component instance)
- ✅ Must look up view from ViewRegistry using viewId
- ✅ Return result or `null` if method not supported

---

## Bridge Implementation

### iOS Bridge

**File:** `packages/dcflight/ios/Classes/channel/DCMauiBridgeChannel.swift`

```swift
case "tunnel":
    if let args = args {
        handleTunnel(args, result: result)
    }

func handleTunnel(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let componentType = args["componentType"] as? String,
          let method = args["method"] as? String,
          let params = args["params"] as? [String: Any] else {
        result(FlutterError(code: "TUNNEL_ERROR", message: "Invalid tunnel parameters", details: nil))
        return
    }
    
    guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
        result(FlutterError(code: "COMPONENT_NOT_FOUND", message: "Component \(componentType) not registered", details: nil))
        return
    }
    
    // Call static method
    if let response = componentClass.handleTunnelMethod(method, params: params) {
        result(response)
    } else {
        result(FlutterError(code: "METHOD_NOT_FOUND", message: "Method \(method) not found on \(componentType)", details: nil))
    }
}
```

### Android Bridge

**File:** `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/bridge/DCMauiBridgeMethodChannel.kt`

```kotlin
"tunnel" -> {
    if (args != null) {
        handleTunnel(args, result)
    }
}

private fun handleTunnel(args: Map<String, Any>, result: Result) {
    val componentType = args["componentType"] as? String
    val method = args["method"] as? String
    val params = args["params"] as? Map<String, Any>
    
    if (componentType == null || method == null || params == null) {
        result.error("TUNNEL_ERROR", "Invalid tunnel parameters", null)
        return
    }
    
    val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
    if (componentClass == null) {
        result.error("COMPONENT_NOT_FOUND", "Component $componentType not registered", null)
        return
    }
    
    // Create instance and call method
    val component = componentClass.getDeclaredConstructor().newInstance()
    val response = component.handleTunnelMethod(method, params)
    
    if (response != null) {
        result.success(response)
    } else {
        result.error("METHOD_NOT_FOUND", "Method $method not found on $componentType", null)
    }
}
```

---

## Use Cases

### 1. Focus Management

```dart
// Focus an input field
await FrameworkTunnel.call('TextInput', 'focus', {'viewId': 'input1'});

// Blur an input field
await FrameworkTunnel.call('TextInput', 'blur', {'viewId': 'input1'});
```

### 2. Animation Control

```dart
// Pause animation
await FrameworkTunnel.call('ReanimatedView', 'executeCommand', {
  'controllerId': 'box1',
  'command': {'type': 'pause'}
});
```

### 3. Component-Specific Operations

```dart
// Get current text from input
final text = await FrameworkTunnel.call('TextInput', 'getText', {'viewId': 'input1'});

// Scroll to position
await FrameworkTunnel.call('ScrollView', 'scrollTo', {
  'viewId': 'scroll1',
  'x': 0,
  'y': 100
});
```

---

## Best Practices

### 1. Always Include viewId

```dart
// ✅ Good
await FrameworkTunnel.call('TextInput', 'focus', {'viewId': 'input1'});

// ❌ Bad - How do we know which view?
await FrameworkTunnel.call('TextInput', 'focus', {});
```

### 2. Handle Errors

```dart
try {
    final result = await FrameworkTunnel.call('TextInput', 'focus', {'viewId': 'input1'});
    if (result == null) {
        print('Method not supported or view not found');
    }
} catch (e) {
    print('Tunnel call failed: $e');
}
```

### 3. Return Meaningful Results

**iOS:**
```swift
case "getText":
    if let view = getView(from: params) as? UITextField {
        return view.text  // Return actual value
    }
    return nil  // Return nil if failed
```

**Android:**
```kotlin
"getText" -> {
    val view = getView(from: arguments) as? EditText
    return view?.text?.toString()  // Return actual value or null
}
```

---

## When to Use Tunnel

### ✅ Use Tunnel For:

- **Framework operations** - Focus, blur, scroll
- **Animation control** - Pause, resume, reset
- **Component queries** - Get current value, get state
- **Operations that bypass VDOM** - Direct native calls

### ❌ Don't Use Tunnel For:

- **Regular prop updates** - Use VDOM (updateView)
- **Event handling** - Use propagateEvent
- **Layout changes** - Use VDOM (props)

---

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - How to implement handleTunnelMethod
- [Event System](./EVENT_SYSTEM.md) - When to use events vs tunnel
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Best practices

