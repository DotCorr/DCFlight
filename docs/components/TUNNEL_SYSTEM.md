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

### Example: Canvas Texture Updates

```dart
// Update canvas texture with pixel data
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': byteData.buffer.asUint8List(),
  'width': 300,
  'height': 300,
});

// Result will be:
// - true: Success, texture was updated
// - false: View not registered yet (retry later)
// - null: Error or method not found
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
- ✅ Return `false` if view not found (indicates view not ready yet)

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
- ✅ Return `false` if view not found (indicates view not ready yet)

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

### 4. Canvas Texture Updates

```dart
// Update canvas texture with rendered pixel data
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': byteData.buffer.asUint8List(),
  'width': 300,
  'height': 300,
});
```

---

## Common Issues and Solutions

### Issue 1: Tunnel Returns `null` or `false`

**Symptom:**
```dart
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
// result is null or false
```

**Causes:**
1. **View not registered yet** - The native view hasn't been created or registered with its ID
2. **Component not found** - Component type doesn't match registered name
3. **Method not implemented** - `handleTunnelMethod` doesn't handle the method name
4. **Invalid parameters** - Required parameters are missing or wrong type

**Solutions:**

#### For View Not Ready (Most Common):
```dart
// ✅ Good: Wait for view to be ready
Future.delayed(const Duration(milliseconds: 200), () async {
  final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
  if (result != true) {
    // Retry once more
    Future.delayed(const Duration(milliseconds: 100), () {
      FrameworkTunnel.call('Canvas', 'updateTexture', {...});
    });
  }
});

// ✅ Better: Track view readiness
bool isViewReady = false;
void renderFrame() {
  if (!isViewReady) {
    FrameworkTunnel.call('Canvas', 'updateTexture', {...}).then((result) {
      if (result == true) {
        isViewReady = true;
      }
    });
  } else {
    // View is ready, render normally
    FrameworkTunnel.call('Canvas', 'updateTexture', {...});
  }
}
```

#### For Component Not Found:
```dart
// ❌ Bad: Wrong component type
await FrameworkTunnel.call('CanvasView', 'updateTexture', {...});
// Should be 'Canvas' not 'CanvasView'

// ✅ Good: Use correct component type
await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
```

#### For Method Not Implemented:
```swift
// ❌ Bad: Method not handled
static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
    // Missing case for 'updateTexture'
    return nil
}

// ✅ Good: Handle all methods
static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
    switch method {
    case "updateTexture":
        // Implementation
        return true
    default:
        return nil
    }
}
```

### Issue 2: Infinite Loop / Continuous Tunnel Calls

**Symptom:**
```
🎨 DCFCanvas: Tunnel call result: null
🎨 DCFCanvas: Tunnel call result: null
🎨 DCFCanvas: Tunnel call result: null
// ... repeating forever
```

**Cause:** Dart code keeps calling tunnel even when view isn't ready, creating an infinite retry loop.

**Solution:**
```dart
// ❌ Bad: Continuous calls without checking result
Timer.periodic(const Duration(milliseconds: 16), (_) {
  FrameworkTunnel.call('Canvas', 'updateTexture', {...});
});

// ✅ Good: Track readiness and only render when ready
Timer? frameTimer;
bool isViewReady = false;

void renderFrame() {
  if (!isViewReady) {
    FrameworkTunnel.call('Canvas', 'updateTexture', {...}).then((result) {
      if (result == true) {
        isViewReady = true;
        // Now start continuous rendering
        frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          FrameworkTunnel.call('Canvas', 'updateTexture', {...});
        });
      }
    });
  } else {
    FrameworkTunnel.call('Canvas', 'updateTexture', {...});
  }
}

// Initial render with delay
Future.delayed(const Duration(milliseconds: 200), () {
  renderFrame();
});
```

### Issue 3: Race Condition - View Registration

**Symptom:** Tunnel calls succeed sometimes but fail other times, especially on first render.

**Cause:** Dart tries to call tunnel before native view has registered itself with its ID.

**Solution:**
```dart
// ✅ Good: Use proper delay and retry logic
useEffect(() {
  Timer? frameTimer;
  bool isViewReady = false;
  
  void renderFrame() {
    if (!isViewReady) {
      _renderToNative(canvasId).then((success) {
        if (success == true) {
          isViewReady = true;
        }
      });
    } else {
      _renderToNative(canvasId);
    }
  }
  
  // Wait for view registration before starting
  Future.delayed(const Duration(milliseconds: 200), () {
    renderFrame();
    frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      renderFrame();
    });
  });
  
  return () => frameTimer?.cancel();
}, dependencies: [canvasId]);
```

### Issue 4: Wrong Return Values

**Symptom:** Dart code can't distinguish between "view not ready" and "error".

**Solution:**
```swift
// ✅ Good: Return meaningful values
static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
    if method == "updateTexture" {
        guard let canvasId = params["canvasId"] as? String,
              let view = DCFCanvasView.canvasViews[canvasId] else {
            // View not registered yet
            return false  // Not nil - indicates "not ready"
        }
        view.updateTexture(...)
        return true  // Success
    }
    return nil  // Method not supported
}
```

```dart
// ✅ Good: Handle all return values
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {...});

if (result == true) {
  // Success - texture updated
} else if (result == false) {
  // View not ready - retry later
} else {
  // null - error or method not found
}
```

---

## Best Practices

### 1. Always Include viewId or canvasId

```dart
// ✅ Good
await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': pixels,
  'width': width,
  'height': height,
});

// ❌ Bad - How do we know which view?
await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'pixels': pixels,
});
```

### 2. Handle All Return Values

```dart
// ✅ Good
try {
  final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
  if (result == true) {
    // Success
  } else if (result == false) {
    // View not ready - retry later
    Future.delayed(const Duration(milliseconds: 100), () {
      FrameworkTunnel.call('Canvas', 'updateTexture', {...});
    });
  } else {
    // Error
    print('Tunnel call failed');
  }
} catch (e) {
  print('Tunnel call exception: $e');
}
```

### 3. Return Meaningful Results from Native

**iOS:**
```swift
case "updateTexture":
    if let view = getView(from: params) {
        view.updateTexture(...)
        return true  // Success
    }
    return false  // View not ready
```

**Android:**
```kotlin
"updateTexture" -> {
    val view = getView(from: arguments)
    if (view != null) {
        view.updateTexture(...)
        return true  // Success
    }
    return false  // View not ready
}
```

### 4. Use Delays for Initial Calls

```dart
// ✅ Good: Wait for view registration
Future.delayed(const Duration(milliseconds: 200), () {
  await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
});

// ❌ Bad: Immediate call (view might not be ready)
await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
```

### 5. Track View Readiness

```dart
// ✅ Good: Track state to avoid unnecessary calls
bool isViewReady = false;

void renderFrame() {
  if (!isViewReady) {
    FrameworkTunnel.call('Canvas', 'updateTexture', {...}).then((result) {
      if (result == true) {
        isViewReady = true;
      }
    });
  } else {
    // View is ready, render normally
    FrameworkTunnel.call('Canvas', 'updateTexture', {...});
  }
}
```

---

## When to Use Tunnel vs Props vs Commands

DCFlight provides three ways to interact with native components. Understanding when to use each is crucial for building efficient applications.

### 1. Props-Based Configuration (VDOM)

**Use for:** Initial setup, declarative configuration, state that should trigger reconciliation

**How it works:** Props are passed during `createView` and `updateView`, going through the VDOM reconciliation process.

**Example:**
```dart
// ✅ Good: Use props for initial animation configuration
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(duration: 500),
  autoStart: true,
  children: [/* ... */],
)

// ✅ Good: Use props for layout and styling
DCFCanvas(
  size: const Size(300, 300),
  backgroundColor: Colors.blue,
  layout: layouts['canvasBox'],
  onPaint: (canvas, size) { /* ... */ },
)
```

**When to use:**
- ✅ Initial component configuration
- ✅ Declarative state (what the component should be)
- ✅ Layout and styling properties
- ✅ Configuration that should trigger reconciliation
- ✅ Properties that need to be preserved across hot reloads

**When NOT to use:**
- ❌ Frequent updates (causes reconciliation overhead)
- ❌ Imperative operations (pause, resume, focus)
- ❌ Real-time data (60fps updates)
- ❌ Operations that bypass VDOM

---

### 2. Tunnel (Direct Method Calls)

**Use for:** Imperative operations, real-time updates, operations that bypass VDOM

**How it works:** Direct method calls to native components, bypassing VDOM entirely.

**Example:**
```dart
// ✅ Good: Imperative animation control
await FrameworkTunnel.call('ReanimatedView', 'executeCommand', {
  'controllerId': 'box1',
  'command': {'type': 'pause'}
});

// ✅ Good: Real-time canvas updates (60fps)
await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': byteData.buffer.asUint8List(),
  'width': 300,
  'height': 300,
});

// ✅ Good: Focus management
await FrameworkTunnel.call('TextInput', 'focus', {'viewId': 'input1'});
```

**When to use:**
- ✅ **Imperative operations** - Pause, resume, focus, blur, scroll
- ✅ **Real-time updates** - 60fps canvas rendering, live data streams
- ✅ **Component queries** - Get current value, get state
- ✅ **Operations that bypass VDOM** - Direct native calls without reconciliation
- ✅ **Frequent updates** - Updates that would cause too much reconciliation overhead

**When NOT to use:**
- ❌ Initial component setup (use props)
- ❌ Declarative configuration (use props)
- ❌ Layout changes (use props via VDOM)
- ❌ Event handling (use propagateEvent)

---

### 3. Command-Based Component Commands (via Tunnel)

**Use for:** Complex imperative operations with structured command patterns

**How it works:** Tunnel calls that use a command object pattern for complex operations.

**Example:**
```dart
// ✅ Good: Command-based animation control
await FrameworkTunnel.call('ReanimatedView', 'executeCommand', {
  'controllerId': 'box1',
  'command': {
    'type': 'pause',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  }
});

// ✅ Good: Command-based group operations
await FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
  'groupId': 'modal_animations',
  'command': {
    'type': 'resetAll',
    'options': {'immediate': true}
  }
});

// ✅ Good: Command-based canvas operations
await FrameworkTunnel.call('Canvas', 'executeCommand', {
  'canvasId': canvasId,
  'command': {
    'type': 'clear',
    'color': 0xFF000000,
  }
});
```

**When to use:**
- ✅ **Complex operations** - Operations that need multiple parameters or options
- ✅ **Batch operations** - Multiple related operations in one call
- ✅ **Stateful commands** - Commands that need to track state or history
- ✅ **Undo/Redo support** - Commands that can be reversed
- ✅ **Command queues** - Operations that need to be queued or sequenced

**When NOT to use:**
- ❌ Simple operations (use direct tunnel methods)
- ❌ One-off operations (use direct tunnel methods)
- ❌ Stateless operations (use direct tunnel methods)

---

## Decision Tree

```
Need to configure component?
│
├─ Yes → Is it initial setup or declarative?
│   │
│   ├─ Yes → Use Props (VDOM)
│   │   └─ Example: ReanimatedView(animatedStyle: ...)
│   │
│   └─ No → Is it a simple imperative operation?
│       │
│       ├─ Yes → Use Tunnel (direct method)
│       │   └─ Example: FrameworkTunnel.call('TextInput', 'focus', {...})
│       │
│       └─ No → Is it a complex operation with options?
│           │
│           └─ Yes → Use Command Pattern (via Tunnel)
│               └─ Example: FrameworkTunnel.call('ReanimatedView', 'executeCommand', {...})
│
└─ No → Is it a real-time update (60fps)?
    │
    ├─ Yes → Use Tunnel (bypasses VDOM)
    │   └─ Example: Canvas texture updates
    │
    └─ No → Is it an event?
        │
        └─ Yes → Use propagateEvent (event system)
```

---

## Comparison Table

| Pattern | Use Case | Performance | Reconciliation | Example |
|---------|----------|------------|----------------|---------|
| **Props (VDOM)** | Initial setup, declarative config | Medium (reconciliation overhead) | ✅ Yes | `ReanimatedView(animatedStyle: ...)` |
| **Tunnel (Direct)** | Imperative ops, real-time updates | ⚡ Fast (bypasses VDOM) | ❌ No | `FrameworkTunnel.call('TextInput', 'focus', {...})` |
| **Commands (via Tunnel)** | Complex operations, batch ops | ⚡ Fast (bypasses VDOM) | ❌ No | `FrameworkTunnel.call('ReanimatedView', 'executeCommand', {...})` |

---

## Real-World Examples

### Example 1: Animation Component

```dart
// ✅ Initial configuration via Props
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(duration: 500),
  autoStart: true,  // Props-based control
  children: [/* ... */],
)

// ✅ Runtime control via Tunnel Commands
await FrameworkTunnel.call('ReanimatedView', 'executeCommand', {
  'controllerId': 'box1',
  'command': {'type': 'pause'}  // Command-based control
});

// ❌ Don't use props for runtime control (causes reconciliation)
// ReanimatedView(animatedStyle: ..., isPaused: true)  // BAD
```

### Example 2: Canvas Component

```dart
// ✅ Initial configuration via Props
DCFCanvas(
  size: const Size(300, 300),
  backgroundColor: Colors.blue,
  repaintOnFrame: true,  // Props-based configuration
  onPaint: (canvas, size) { /* ... */ },
)

// ✅ Real-time updates via Tunnel (60fps)
await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': byteData,
  'width': 300,
  'height': 300,
});

// ❌ Don't use props for 60fps updates (too much reconciliation)
// DCFCanvas(pixels: newPixels, ...)  // BAD - would cause 60 reconciliations per second
```

### Example 3: Text Input Component

```dart
// ✅ Initial configuration via Props
DCFTextInput(
  placeholder: 'Enter text',
  keyboardType: 'text',
  // Props-based configuration
)

// ✅ Runtime control via Tunnel
await FrameworkTunnel.call('TextInput', 'focus', {'viewId': 'input1'});
await FrameworkTunnel.call('TextInput', 'blur', {'viewId': 'input1'});

// ✅ Query state via Tunnel
final text = await FrameworkTunnel.call('TextInput', 'getText', {'viewId': 'input1'});
```

---

## Best Practices Summary

### ✅ DO

1. **Use Props for:** Initial setup, declarative configuration, layout, styling
2. **Use Tunnel for:** Imperative operations, real-time updates, queries
3. **Use Commands for:** Complex operations, batch operations, stateful operations
4. **Combine patterns:** Use props for setup, tunnel for runtime control

### ❌ DON'T

1. **Don't use Props for:** Frequent updates, real-time data, imperative operations
2. **Don't use Tunnel for:** Initial setup, declarative configuration
3. **Don't use Commands for:** Simple one-off operations (use direct tunnel methods)

---

## When to Use Tunnel

### ✅ Use Tunnel For:

- **Framework operations** - Focus, blur, scroll
- **Animation control** - Pause, resume, reset (via commands)
- **Component queries** - Get current value, get state
- **Operations that bypass VDOM** - Direct native calls
- **Canvas texture updates** - Send pixel data directly to native views
- **Real-time updates** - Frequent updates that don't need VDOM reconciliation

### ❌ Don't Use Tunnel For:

- **Regular prop updates** - Use VDOM (updateView)
- **Event handling** - Use propagateEvent
- **Layout changes** - Use VDOM (props)
- **Initial component setup** - Use props during createView

---

## Return Value Conventions

When implementing `handleTunnelMethod`, follow these conventions:

| Return Value | Meaning | Dart Behavior |
|--------------|---------|---------------|
| `true` | Success | Operation completed successfully |
| `false` | View not ready | View exists but not registered yet, retry later |
| `null` / `nil` | Error or not found | Method not supported, component not found, or error occurred |
| Other values | Custom result | Returned as-is (e.g., string, number, object) |

**Example:**
```swift
static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
    switch method {
    case "updateTexture":
        if let view = findView(from: params) {
            view.updateTexture(...)
            return true  // ✅ Success
        }
        return false  // ✅ View not ready
    case "getText":
        if let view = findView(from: params) {
            return view.text  // ✅ Return actual value
        }
        return nil  // ✅ Error
    default:
        return nil  // ✅ Method not supported
    }
}
```

---

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - How to implement handleTunnelMethod
- [Event System](./EVENT_SYSTEM.md) - When to use events vs tunnel
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Best practices
- [Canvas API Documentation](./CANVAS_API.md) - Canvas rendering with Flutter textures
