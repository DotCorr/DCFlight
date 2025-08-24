# UseWebDefaults - Cross-Platform Layout Compatibility

## Overview

The UseWebDefaults feature enables CSS-compatible layout behavior in DCFlight applications, making it easier to create layouts that work consistently across mobile and web platforms.

## What it Changes

When UseWebDefaults is enabled, the layout system switches from Yoga's native defaults to web-compatible defaults:

### Yoga Native Defaults (Default Behavior)
```yaml
flex-direction: column
align-content: flex-start
flex-shrink: 0.0
position: relative
```

### Web Defaults (When Enabled)
```yaml
flex-direction: row
align-content: stretch
flex-shrink: 1.0
position: relative  # Still relative for compatibility
```

## Usage

### Dart API

```dart
import 'package:dcflight/framework/constants/layout/layout_config.dart';

// Enable web defaults globally
await LayoutConfig.enableWebDefaults();

// Disable web defaults (return to Yoga native)
await LayoutConfig.disableWebDefaults();

// Check current state
bool isEnabled = LayoutConfig.isWebDefaultsEnabled();
```

### Configuration Constants

```dart
import 'package:dcflight/framework/constants/layout/layout_config.dart';

// Access default values
String yogaFlex = LayoutDefaults.yogaFlexDirection; // 'column'
String webFlex = LayoutDefaults.webFlexDirection;   // 'row'

double yogaShrink = LayoutDefaults.yogaFlexShrink;  // 0.0
double webShrink = LayoutDefaults.webFlexShrink;    // 1.0
```

## Static Position Support

The UseWebDefaults feature also includes enhanced static position support:

```dart
// Static positioned elements ignore insets and don't form containing blocks
YogaPositionType.static  // New position type added
```

## Implementation Details

### Architecture

The feature works across three layers:

1. **Dart Layer**: `LayoutConfig` class manages state and communicates with native
2. **Method Channel**: Uses dedicated `com.dcmaui.layout` channel for layout operations  
3. **Swift Layer**: `DCFLayoutManager` and `YogaShadowTree` apply the defaults

### Communication Flow

```
LayoutConfig.enableWebDefaults()
    ↓
layoutChannel.invokeMethod('setUseWebDefaults', {'enabled': true})
    ↓  
DCMauiLayoutMethodHandler.handleSetUseWebDefaults()
    ↓
DCFLayoutManager.shared.setUseWebDefaults(true)
    ↓
YogaShadowTree.shared.applyWebDefaults()
    ↓
Layout system uses web-compatible defaults
```

### Swift Implementation

```swift
// DCFLayoutManager.swift
public func setUseWebDefaults(_ enabled: Bool) {
    useWebDefaults = enabled
    
    if enabled {
        YogaShadowTree.shared.applyWebDefaults()
    }
    
    print("✅ DCFLayoutManager: UseWebDefaults set to \(enabled)")
}

// YogaShadowTree.swift  
func applyWebDefaults() {
    useWebDefaults = true
    // Changes flex-direction, align-content, flex-shrink globally
    // Adds static position support with inset ignoring
}
```

## Use Cases

### Cross-Platform Development
- Building layouts that work identically on mobile and web
- Porting existing CSS layouts to DCFlight
- Creating responsive designs with CSS-like behavior

### Migration Scenarios
- Moving from web frameworks to DCFlight
- Maintaining layout consistency across platform teams
- Reducing layout debugging between platforms

## Best Practices

### When to Enable
- ✅ Cross-platform applications targeting web and mobile
- ✅ Teams familiar with CSS flexbox behavior  
- ✅ Migrating from web-based layout systems

### When to Keep Disabled
- ✅ Pure mobile applications with no web target
- ✅ Existing applications with established Yoga-based layouts
- ✅ Performance-critical applications (native defaults are slightly faster)

### Migration Tips

1. **Test thoroughly**: Layout behavior changes can be subtle
2. **Enable early**: Best enabled at app initialization before creating views
3. **Document choice**: Make the decision explicit in your app documentation
4. **Consider gradual adoption**: Can be enabled per-feature if needed

## Performance Considerations

- **Minimal overhead**: Flag check only occurs during layout calculation setup
- **No runtime cost**: Once applied, layout performance is identical
- **Memory impact**: Negligible (single boolean flag per manager)

## Debugging

The feature includes comprehensive logging:

```
✅ LayoutConfig: Web defaults enabled successfully
✅ DCFLayoutManager: UseWebDefaults set to true  
❌ LayoutConfig: Failed to enable web defaults - [error details]
```

Enable DCFlight debug logging to see detailed layout behavior changes.

## Compatibility

- **Minimum DCFlight Version**: 1.0.0+
- **Platform Support**: iOS, Android (when available)
- **Dart Version**: 2.17+
- **Flutter Version**: 3.0+

## Related Documentation

- [Layout Properties](../constants/layout_properties.md)
- [Yoga Integration](./yoga_integration.md) 
- [Cross-Platform Development](../../guides/cross_platform.md)
