# DCFlight Module Development Guidelines

This guide explains how to create native components for your DCFlight module, register them with the framework, and bind them to Dart interfaces.

## Table of Contents

1. [Android Component Creation](#android-component-creation)
2. [iOS Component Creation](#ios-component-creation)
3. [Component Registration](#component-registration)
4. [Dart Interface Component Binding](#dart-interface-component-binding)

---

## Android Component Creation

### 1. Create the Component Class

Create a new Kotlin file in `android/src/main/kotlin/com/dotcorr/{module_name}/components/`:

```kotlin
package com.dotcorr.{module_name}.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.{module_name}.R

/**
 * Your custom component description
 */
class YourComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Create and return your Android View
        val view = YourCustomView(context)
        
        // Set component type tag
        view.setTag(R.id.dcf_component_type, "YourComponent")
        
        // Apply initial props
        updateView(view, props)
        
        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val yourView = view as? YourCustomView ?: return false
        
        // Framework automatically merges props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update view properties based on merged props
        mergedProps["yourProp"]?.let { value ->
            yourView.setYourProperty(value.toString())
        }
        
        // Apply styles
        yourView.applyStyles(nonNullProps)
        
        return true
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Optional: Called when view is registered with the shadow tree
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        // Optional: Handle custom methods called from Dart
        return null
    }
}
```

### 2. Key Points for Android Components

- **Extend `DCFComponent`**: All components must extend `DCFComponent`
- **Package Structure**: Place components in `com.dotcorr.{module_name}.components`
- **R Import**: Use `com.dotcorr.{module_name}.R` for resource IDs
- **Props Handling**: Framework automatically merges props - use `mergedProps` from `mergeProps()`
- **View Updates**: Always check view type with `as?` before casting
- **Touch Handling**: Framework automatically enables touch handling when event listeners are registered
- **Event Data**: Include `timestamp` (milliseconds) and `fromUser` in event data for type-safe callbacks
- **Intrinsic Size**: Removed from protocol - components set `intrinsicContentSize` on shadow view if needed

---

## iOS Component Creation

### 1. Create the Component Class

Create a new Swift file in `ios/Classes/Components/`:

```swift
import UIKit
import dcflight

class YourComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = YourCustomView()
        
        // Apply initial styles
        view.applyStyles(props: props)
        
        // Update with props
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let yourView = view as? YourCustomView else { 
            return false 
        }
        
        // Get existing props for comparison
        let existingProps = getStoredProps(from: yourView)
        let mergedProps = mergeProps(existingProps, with: props.mapValues { $0 as Any? })
        storeProps(mergedProps, in: yourView)
        
        let nonNullProps = mergedProps.compactMapValues { $0 }
        
        // Update view properties
        if let yourProp = nonNullProps["yourProp"] as? String {
            yourView.setYourProperty(yourProp)
        }
        
        // Apply styles
        yourView.applyStyles(props: nonNullProps)
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(
            x: layout.left, 
            y: layout.top, 
            width: layout.width, 
            height: layout.height
        )
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        // Store node ID with the view
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
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        // Optional: Handle custom methods called from Dart
        return nil
    }
}
```

### 2. Key Points for iOS Components

- **Implement `DCFComponent` Protocol**: All components must implement `DCFComponent`
- **Props Storage**: Use `storeProps()` and `getStoredProps()` to manage props
- **Props Merging**: Use `mergeProps()` to merge existing and new props - framework handles this automatically
- **Style Application**: Always call `applyStyles()` to apply layout and style props
- **View Type Checking**: Always use `guard let` to safely cast views
- **Component References**: For touchable components with children, use **strong** component references (not weak) and store in `NSMapTable` to prevent deallocation
- **Intrinsic Size**: Set `intrinsicContentSize` on shadow view in `viewRegisteredWithShadowTree` if component has known size (only if node has no children)

---

## Component Registration

### Android Registration

Register your component in `android/src/main/kotlin/com/dotcorr/{module_name}/ModuleComponentsReg.kt`:

```kotlin
object ModuleComponentsReg {
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        // Register your components here
        registry.registerComponent("YourComponent", YourComponent::class.java)
        registry.registerComponent("AnotherComponent", AnotherComponent::class.java)
    }
}
```

**Important**: Component names must match exactly between Android and iOS for cross-platform consistency.

### iOS Registration

Register your component in `ios/Classes/{module_name}.swift`:

```swift
@objc public static func registerComponents() {
    // Register all module components with the DCFlight component registry
    DCFComponentRegistry.shared.registerComponent("YourComponent", componentClass: YourComponent.self)
    DCFComponentRegistry.shared.registerComponent("AnotherComponent", componentClass: AnotherComponent.self)
}
```

**Important**: 
- Component names must match Android exactly
- Use the same string name in both platforms
- Registration happens automatically when the plugin loads

---

## Dart Interface Component Binding

### 1. Create the Dart Component Class

Create a new Dart file in `lib/src/components/`:

```dart
import 'package:dcflight/dcflight.dart';

/// Your component description
class YourComponent extends StatelessComponent {
  /// Your component properties
  final String yourProp;
  final LayoutProps layout;
  final StyleSheet style;
  final List<DCFComponentNode> children;

  /// Create your component
  YourComponent({
    required this.yourProp,
    this.layout = const LayoutProps(),
    this.style = const StyleSheet(),
    this.children = const [],
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'YourComponent', // Must match registered name exactly
      props: {
        'yourProp': yourProp,
        ...layout.toMap(),
        ...style.toMap(),
      },
      children: children,
    );
  }
}
```

### 2. Export the Component

Add to `lib/{module_name}.dart`:

```dart
// Export module components
export 'src/components/your_component.dart';
export 'src/components/another_component.dart';
```

### 3. Key Points for Dart Components

- **Extend `StatelessComponent`**: For stateless components
- **Component Type**: The `type` in `DCFElement` must match the registered name exactly
- **Props Mapping**: Map Dart properties to native props in the `props` map
- **Layout & Style**: Include `layout.toMap()` and `style.toMap()` for styling
- **Children**: Pass children array if your component supports children

### 4. Using Your Component

```dart
import 'package:your_module/your_module.dart';

YourComponent(
  yourProp: 'value',
  layout: const LayoutProps(
    width: 100,
    height: 50,
  ),
  style: const StyleSheet(
    backgroundColor: DCFColors.blue,
  ),
  children: [
    // Child components
  ],
)
```

---

## Component Naming Conventions

### Cross-Platform Consistency

1. **Component Name**: Use PascalCase (e.g., `YourComponent`)
2. **Registration Name**: Use the exact same string on both platforms
3. **File Names**: 
   - Android: `YourComponent.kt`
   - iOS: `YourComponent.swift`
   - Dart: `your_component.dart` (snake_case)

### Example

| Platform | File Name | Class Name | Registration Name |
|----------|-----------|------------|-------------------|
| Android | `YourComponent.kt` | `YourComponent` | `"YourComponent"` |
| iOS | `YourComponent.swift` | `YourComponent` | `"YourComponent"` |
| Dart | `your_component.dart` | `YourComponent` | `"YourComponent"` |

---

## Best Practices

1. **Props Validation**: Always validate props in native code
2. **Error Handling**: Handle missing or invalid props gracefully
3. **Performance**: Use `hasPropChanged()` to avoid unnecessary updates
4. **Memory**: Clean up resources in `viewRegisteredWithShadowTree` if needed
5. **Testing**: Test components on both platforms
6. **Documentation**: Document all props and their types

---

## Troubleshooting

### Component Not Rendering

- Check that component is registered in both Android and iOS
- Verify component name matches exactly in all three places
- Check console logs for registration errors

### Props Not Updating

- Ensure `updateView` is implemented correctly
- Check that props are being passed correctly from Dart
- Verify that `mergeProps()` is being used to preserve existing props (Android)

### Layout Issues

- Ensure `applyStyles()` is called (iOS)
- Check that layout props are included in Dart component
- Verify `intrinsicContentSize` is set on shadow view if component has known size

---

## Next Steps

1. Create your component following the patterns above
2. Register it in both Android and iOS
3. Create the Dart interface
4. Export and use in your app
5. Test on both platforms

Happy coding! 🚀

