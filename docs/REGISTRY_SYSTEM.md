# Component Registry System

## Overview

The registry system allows components to be discovered and instantiated by the framework. Components must be registered before they can be used.

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Component Registration Flow                │
└─────────────────────────────────────────────────────────┘

1. Component Class Created
   └─> DCFButtonComponent (iOS/Android)

2. Registration (App Startup)
   └─> DCFComponentRegistry.shared.registerComponent(...)

3. Framework Discovery
   └─> VDOM requests "Button" component
   └─> Registry looks up "Button"
   └─> Returns component class

4. Instantiation
   └─> Framework creates instance
   └─> Calls createView()
```

---

## iOS Registry

### Implementation

**File:** `packages/dcflight/ios/Classes/Coordination/Components/index/DCFComponentRegistry.swift`

```swift
public class DCFComponentRegistry {
    public static let shared = DCFComponentRegistry()
    
    internal var componentTypes: [String: DCFComponent.Type] = [:]
    
    /// Register a component type
    public func registerComponent(_ type: String, componentClass: DCFComponent.Type) {
        componentTypes[type] = componentClass
    }
    
    /// Get component class for a type
    func getComponentType(for type: String) -> DCFComponent.Type? {
        return componentTypes[type]
    }
}
```

### Registration Example

```swift
// In your plugin's registration file
@objc public class DcfPrimitives: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        DCFComponentRegistry.shared.registerComponent("Button", componentClass: DCFButtonComponent.self)
        DCFComponentRegistry.shared.registerComponent("Text", componentClass: DCFTextComponent.self)
        DCFComponentRegistry.shared.registerComponent("Slider", componentClass: DCFSliderComponent.self)
    }
}
```

---

## Android Registry

### Implementation

**File:** `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/components/DCFComponentRegistry.kt`

```kotlin
class DCFComponentRegistry private constructor() {
    companion object {
        @JvmField
        val shared = DCFComponentRegistry()
    }
    
    private val componentTypes = ConcurrentHashMap<String, Class<out DCFComponent>>()
    
    /// Register a component type
    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        componentTypes[type] = componentClass
        Log.d(TAG, "✅ Registered component type: $type")
    }
    
    /// Get component class for a type
    fun getComponentType(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }
}
```

### Registration Example

```kotlin
// In your plugin's registration file
object PrimitivesComponentsReg {
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared
        
        registry.registerComponent("Button", DCFButtonComponent::class.java)
        registry.registerComponent("Text", DCFTextComponent::class.java)
        registry.registerComponent("Slider", DCFSliderComponent::class.java)
    }
}

// In plugin class
class DcfPrimitivesPlugin : FlutterPlugin {
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        PrimitivesComponentsReg.registerComponents()
    }
}
```

---

## Cross-Platform Consistency

### Critical Rule: Component Names Must Match

**✅ Correct:**
```swift
// iOS
DCFComponentRegistry.shared.registerComponent("Button", componentClass: DCFButtonComponent.self)
```

```kotlin
// Android
DCFComponentRegistry.shared.registerComponent("Button", DCFButtonComponent::class.java)
```

**❌ Wrong:**
```swift
// iOS
DCFComponentRegistry.shared.registerComponent("UIButton", componentClass: DCFButtonComponent.self)  // ❌
```

```kotlin
// Android
DCFComponentRegistry.shared.registerComponent("Button", DCFButtonComponent::class.java)  // ✅
```

**Why?** Dart code uses the same component name on both platforms:
```dart
DCFButton(...)  // Must work on both iOS and Android
```

---

## Registration Flow

### 1. Plugin Initialization

**iOS:**
```swift
// Flutter calls this automatically
@objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
    registerComponents()
}
```

**Android:**
```kotlin
// Flutter calls this automatically
override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    PrimitivesComponentsReg.registerComponents()
}
```

### 2. Component Lookup

**When VDOM needs a component:**

**iOS:**
```swift
// In ViewManager
let componentClass = DCFComponentRegistry.shared.getComponentType(for: "Button")
let component = componentClass.init()
let view = component.createView(props: props)
```

**Android:**
```kotlin
// In ViewManager
val componentClass = DCFComponentRegistry.shared.getComponentType("Button")
val component = componentClass.getDeclaredConstructor().newInstance()
val view = component.createView(context, props)
```

---

## Best Practices

### 1. Register All Components at Startup

```swift
// iOS - Do this in registerComponents()
func registerComponents() {
    // Register all components at once
    DCFComponentRegistry.shared.registerComponent("Button", componentClass: DCFButtonComponent.self)
    DCFComponentRegistry.shared.registerComponent("Text", componentClass: DCFTextComponent.self)
    // ... all components
}
```

### 2. Use Consistent Naming

- ✅ Use PascalCase: `"Button"`, `"TextInput"`, `"SegmentedControl"`
- ❌ Don't use platform-specific names: `"UIButton"`, `"AndroidButton"`

### 3. Validate Registration

**Android provides validation:**
```kotlin
val results = DCFComponentRegistry.shared.validateRegistrations()
// Returns Map<String, Boolean> - checks if all components can be instantiated
```

---

## Troubleshooting

### Component Not Found

**Error:** `Component type 'Button' not found`

**Solution:**
1. Check component is registered in plugin initialization
2. Check component name matches exactly (case-sensitive)
3. Check plugin is included in app's dependencies

### Component Name Mismatch

**Error:** Component works on iOS but not Android (or vice versa)

**Solution:**
1. Ensure component names match exactly on both platforms
2. Check registration code on both platforms
3. Verify component is registered before use

---

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - How to implement components
- [Event System](./EVENT_SYSTEM.md) - How events work
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Requirements

