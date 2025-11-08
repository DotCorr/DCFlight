# DCFlight Framework Overview

## What is DCFlight?

DCFlight is a cross-platform UI framework that provides:
- **Native UI Rendering** - Direct native views (no Flutter widgets)
- **VDOM Abstraction** - React-like component system in Dart
- **Unified Component API** - Same code, native iOS and Android
- **Framework-Managed Lifecycle** - Framework handles component lifecycle in abstraction layer

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Dart Application Layer                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Your Components (DCFStatefulComponent)            │  │
│  │  • useState hooks                                          │  │
│  │  • Component lifecycle                                     │  │
│  │  • render() method                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ render()
                            │
┌─────────────────────────────────────────────────────────────────┐
│              VDOM (Virtual DOM) Abstraction Layer               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              DCFEngine (Reconciliation Engine)              │  │
│  │  • Component lifecycle management                           │  │
│  │  • Reconciliation & diffing                                │  │
│  │  • Props diffing (only changed props)                      │  │
│  │  • Update scheduling                                       │  │
│  │  • Bridge communication                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ PlatformInterface
                            │ (Easily Replaceable)
                            │
        ┌───────────────────┴───────────────────┐
        │                                       │
┌───────▼────────┐                    ┌────────▼────────┐
│  Android Layer │                    │   iOS Layer    │
│                │                    │                │
│ DCFComponent   │                    │ DCFComponent   │
│ (Abstract)     │                    │ (Protocol)     │
│                │                    │                │
│ Registry       │                    │ Registry       │
│ Events         │                    │ Events         │
│ Tunnel         │                    │ Tunnel         │
└────────────────┘                    └────────────────┘
```

---

## Key Principles

### 1. Framework Manages Lifecycle

The framework (VDOM layer) manages component lifecycle:
- Mount/unmount cycles
- Update scheduling
- Reconciliation
- Props diffing

**Components focus on:** Rendering UI, handling events, managing local state

### 2. Native UI Rendering

- **No Flutter widgets** - Direct native views
- **iOS:** UIKit views (UIView, UIButton, etc.)
- **Android:** Android views (View, Button, etc.)
- **Performance:** Native performance, no widget overhead

### 3. Unified Component API

- **Same component names** on both platforms
- **Same prop names** (e.g., `primaryColor`, `selectedIndex`)
- **Same event names** (e.g., `onPress`, `onValueChange`)
- **Platform-appropriate implementations**

### 4. Easily Replaceable Communication Layer

The communication layer is abstracted:
- **Dart:** `PlatformInterface` (abstract)
- **Implementation:** `PlatformInterfaceImpl` (MethodChannel)
- **Easy to replace:** Just implement `PlatformInterface`

---

## Communication Architecture

### Current Implementation: MethodChannel

```
Dart (VDOM)                    Native (iOS/Android)
    │                                  │
    │  PlatformInterface              │
    │  (Abstract)                      │
    │                                  │
    ├──────────────────────────────────┤
    │                                  │
    │  PlatformInterfaceImpl           │
    │  (MethodChannel)                 │
    │                                  │
    │  • createView                   │
    │  • updateView                   │
    │  • deleteView                   │
    │  • tunnel                       │
    │                                  │
    └──────────────────────────────────┘
```

### Easy Replacement

To replace the communication layer:

1. **Create new implementation:**
```dart
class MyCustomBridge implements PlatformInterface {
  // Implement all methods
  Future<bool> createView(...) { ... }
  Future<bool> updateView(...) { ... }
  // etc.
}
```

2. **Update factory:**
```dart
class NativeBridgeFactory {
  static PlatformInterface create() {
    return MyCustomBridge(); // Just change this!
  }
}
```

**That's it!** The entire framework uses the new bridge automatically.

---

## Component Flow

### 1. Component Renders

```dart
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFButton(
      buttonProps: DCFButtonProps(
        title: "Click me",
        onPress: (data) => print("Pressed!")
      ),
    );
  }
}
```

### 2. VDOM Processes

- Engine calls `render()`
- Creates `DCFElement` nodes
- Diffs props (only changed props)
- Schedules updates

### 3. Bridge Communication

- `PlatformInterface.createView()` called
- MethodChannel sends to native
- Native creates view

### 4. Native Component

- Registry finds component class
- Calls `createView()`
- Returns native view
- View registered

### 5. Event Flow

- User interacts with native view
- Native calls `propagateEvent()`
- Event sent to Dart via MethodChannel
- VDOM finds component and calls handler

---

## Next Steps

See detailed documentation:
- [Component Protocol Guide](./COMPONENT_PROTOCOL.md) - How to implement components
- [Registry System](./REGISTRY_SYSTEM.md) - Component registration
- [Tunnel System](./TUNNEL_SYSTEM.md) - Direct native method calls
- [Event System](./EVENT_SYSTEM.md) - How events work
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Requirements and best practices
- [Architecture Comparison](./ARCHITECTURE_COMPARISON.md) - DCFlight vs React Native

