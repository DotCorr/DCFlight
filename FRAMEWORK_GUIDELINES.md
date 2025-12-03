# DCFlight Framework Development Guidelines

This comprehensive guide covers how to develop components, modules, and contribute to the DCFlight framework.

## Table of Contents

1. [Framework Architecture Overview](#framework-architecture-overview)
2. [Component Development](#component-development)
3. [Module Development](#module-development)
4. [Framework Core Development](#framework-core-development)
5. [Testing Guidelines](#testing-guidelines)
6. [Code Style & Conventions](#code-style--conventions)

---

## Framework Architecture Overview

### Core Packages

- **`packages/dcflight`**: Core framework engine, renderer, and bridge
- **`packages/dcf_primitives`**: Built-in UI primitive components
- **`packages/dcf_screens`**: Screen management and navigation
- **`packages/dcf_reanimated`**: Animation system
- **`cli`**: Command-line tools for project and module creation

### Architecture Layers

```
┌─────────────────────────────────────┐
│         Dart Layer (Components)      │
│  StatelessComponent / StatefulComponent │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      Renderer Engine (VDOM)          │
│  Component Reconciliation & Diffing  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      Native Bridge Interface         │
│  Method Channel Communication        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│    Native Layer (iOS/Android)        │
│  DCFComponent Implementation         │
└─────────────────────────────────────┘
```

---

## Component Development

### Creating Components for dcf_primitives

#### Android Component

**Location**: `packages/dcf_primitives/android/src/main/kotlin/com/dotcorr/dcf_primitives/components/`

```kotlin
package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcf_primitives.R

class YourComponent : DCFComponent() {
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = YourCustomView(context)
        view.setTag(R.id.dcf_component_type, "YourComponent")
        updateView(view, props)
        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val yourView = view as? YourCustomView ?: return false
        
        // Framework automatically merges props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update logic with mergedProps
        mergedProps["yourProp"]?.let { yourView.setYourProperty(it.toString()) }
        
        // Apply styles
        yourView.applyStyles(nonNullProps)
        
        return true
    }
}
```

#### iOS Component

**Location**: `packages/dcf_primitives/ios/Classes/Components/`

```swift
import UIKit
import dcflight

class YourComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = YourCustomView()
        view.applyStyles(props: props)
        updateView(view, withProps: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let yourView = view as? YourCustomView else { return false }
        let existingProps = getStoredProps(from: yourView)
        let mergedProps = mergeProps(existingProps, with: props.mapValues { $0 as Any? })
        storeProps(mergedProps, in: yourView)
        // Update logic
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        // Store nodeId if needed
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
            nodeId,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Set intrinsic content size if component has known size
        // Only set if node has no children (Yoga rule)
        if YGNodeGetChildCount(shadowView.yogaNode) == 0 {
            if let imageView = view as? UIImageView, let image = imageView.image {
                shadowView.intrinsicContentSize = image.size
            }
        }
    }
}
```

#### Dart Component

**Location**: `packages/dcf_primitives/lib/src/components/`

```dart
import 'package:dcflight/dcflight.dart';

class YourComponent extends StatelessComponent {
  final String yourProp;
  final LayoutProps layout;
  final StyleSheet style;

  const YourComponent({
    required this.yourProp,
    this.layout = const LayoutProps(),
    this.style = const StyleSheet(),
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'YourComponent',
      props: {
        'yourProp': yourProp,
        ...layout.toMap(),
        ...style.toMap(),
      },
    );
  }
}
```

#### Registration

**Android**: `packages/dcf_primitives/android/src/main/kotlin/com/dotcorr/dcf_primitives/PrimitivesComponentsReg.kt`

```kotlin
registry.registerComponent("YourComponent", YourComponent::class.java)
```

**iOS**: `packages/dcf_primitives/ios/Classes/PrimitivesComponentsReg.swift`

```swift
DCFComponentRegistry.shared.registerComponent("YourComponent", componentClass: YourComponent.self)
```

---

## Module Development

### Creating a New Module

Use the CLI to create a module:

```bash
dcf create module
```

This creates a module template with:
- Android component structure
- iOS component structure
- Dart component bindings
- Registration files
- Proper package naming

See `packages/template/dcf_module/GUIDELINES.md` for detailed module development instructions.

### Module Structure

```
your_module/
├── android/
│   └── src/main/kotlin/com/dotcorr/your_module/
│       ├── components/
│       ├── YourModulePlugin.kt
│       └── ModuleComponentsReg.kt
├── ios/Classes/
│   ├── Components/
│   └── your_module.swift
└── lib/
    ├── your_module.dart
    └── src/
        ├── components/
        └── your_module_plugin.dart
```

---

## Framework Core Development

### Renderer Engine

**Location**: `packages/dcflight/lib/framework/renderer/engine/`

The renderer engine handles:
- VDOM reconciliation
- Component diffing
- Update batching
- Lifecycle management

### Native Bridge

**Location**: 
- Android: `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/bridge/`
- iOS: `packages/dcflight/ios/Classes/channel/`

The bridge handles:
- Method channel communication
- View operations (create, update, delete, attach)
- Event propagation
- Batch updates

### Component Registry

**Location**: 
- Android: `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/components/DCFComponentRegistry.kt`
- iOS: `packages/dcflight/ios/Classes/Coordination/ComponentRegistry/`

Manages component registration and lookup across platforms.

---

## Testing Guidelines

### Unit Tests

- Test component props handling
- Test layout calculations
- Test event propagation
- Test state management

### Integration Tests

- Test cross-platform consistency
- Test component lifecycle
- Test bridge communication
- Test hot reload/restart

### Platform-Specific Tests

- Android: Test on multiple API levels
- iOS: Test on multiple iOS versions
- Test on both phones and tablets

---

## Code Style & Conventions

### Dart

- Use `dart format` for formatting
- Follow Dart style guide
- Use doc comments (`///`) for public APIs
- Prefer `final` over `var`
- Use meaningful variable names

### Kotlin

- Follow Kotlin style guide
- Use KDoc for documentation
- Prefer `val` over `var`
- Use data classes where appropriate
- Handle nullability explicitly

### Swift

- Follow Swift style guide
- Use doc comments (`///`) for documentation
- Prefer `let` over `var`
- Use guard statements for early returns
- Follow Swift naming conventions

### Naming Conventions

- **Components**: PascalCase (e.g., `DCFButton`, `YourComponent`)
- **Files**: Match class name (e.g., `DCFButton.kt`, `DCFButton.swift`)
- **Dart Files**: snake_case (e.g., `button_component.dart`)
- **Registration Names**: Must match exactly across platforms

### Documentation

- Document all public APIs
- Include parameter descriptions
- Include return value descriptions
- Add usage examples where helpful
- Document platform-specific behavior

### Error Handling

- Use appropriate error types
- Provide meaningful error messages
- Log errors appropriately
- Handle edge cases gracefully

---

## Best Practices

### Component Development

1. **Cross-Platform Consistency**: Ensure Android and iOS components behave identically
2. **Props Validation**: Validate all props in native code
3. **Performance**: Use `hasPropChanged()` to avoid unnecessary updates
4. **Memory Management**: Clean up resources properly
5. **Testing**: Test on both platforms before submitting

### Framework Development

1. **Backward Compatibility**: Maintain API compatibility when possible
2. **Performance**: Profile and optimize critical paths
3. **Documentation**: Keep documentation up to date
4. **Testing**: Add tests for new features
5. **Code Review**: All changes require code review

### Module Development

1. **Isolation**: Modules should be self-contained
2. **Dependencies**: Minimize external dependencies
3. **Documentation**: Document module APIs
4. **Examples**: Provide usage examples
5. **Testing**: Test module independently

---

## Common Patterns

### Event Handling

```dart
// Dart
DCFButton(
  onPress: () {
    // Handle press
  },
)
```

```kotlin
// Android
propagateEvent(view, "onPress", mapOf("data" to value))
```

```swift
// iOS
propagateEvent(on: view, eventName: "onPress", data: ["data": value])
```

### Style Application

```dart
// Dart
style: const StyleSheet(
  backgroundColor: DCFColors.blue,
  borderRadius: 8,
)
```

```kotlin
// Android
view.applyStyles(props)
```

```swift
// iOS
view.applyStyles(props: props)
```

### Layout Props

```dart
// Dart
layout: const LayoutProps(
  width: 100,
  height: 50,
  flex: 1,
)
```

All layout props are automatically handled by the Yoga layout engine.

---

## Troubleshooting

### Component Not Rendering

1. Check component registration
2. Verify component name matches across platforms
3. Check console logs for errors
4. Verify props are being passed correctly

### Performance Issues

1. Profile with platform-specific tools
2. Check for unnecessary re-renders
3. Optimize prop diffing
4. Use batch updates where possible

### Cross-Platform Inconsistencies

1. Test on both platforms
2. Compare behavior side-by-side
3. Check platform-specific implementations
4. Review component registration

---

## Resources

- [Component Protocol Documentation](docs/COMPONENT_PROTOCOL.md)
- [Event System Documentation](docs/EVENT_SYSTEM.md)
- [Tunnel System Documentation](docs/TUNNEL_SYSTEM.md)
- [Registry System Documentation](docs/REGISTRY_SYSTEM.md)
- [Module Development Guidelines](packages/template/dcf_module/GUIDELINES.md)

---

## Getting Help

- Check existing documentation in `docs/`
- Review component examples in `packages/dcf_primitives/`
- Check module template in `packages/template/dcf_module/`
- Open an issue on GitHub for bugs or questions

---

Happy coding with DCFlight! 🚀

