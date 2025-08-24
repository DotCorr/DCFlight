# Layout System Documentation

## Overview

DCFlight uses Facebook's Yoga layout engine with enhancements for cross-platform compatibility.

## Core Features

### Layout Properties
- **Flexbox-based**: CSS flexbox-compatible layout system
- **Cross-platform**: Consistent behavior across iOS, Android, and Web
- **Performance optimized**: Native layout calculations with shadow tree optimization

### Layout Managers
- **DCFLayoutManager**: Core layout coordination and view registry
- **YogaShadowTree**: Shadow tree management for layout calculations  
- **Layout Channel**: Dedicated method channel for layout operations

## Configuration Options

### UseWebDefaults
Enable CSS-compatible layout behavior for cross-platform consistency.

```dart
import 'package:dcflight/framework/constants/layout/layout_config.dart';

// Enable web defaults
await LayoutConfig.enableWebDefaults();
```

**Changes when enabled:**
- flex-direction: `column` → `row`
- align-content: `flex-start` → `stretch`  
- flex-shrink: `0.0` → `1.0`

[📖 Detailed UseWebDefaults Documentation](./web_defaults.md)

### Position Types
- **relative**: Default positioned according to normal flow
- **absolute**: Positioned relative to nearest positioned ancestor
- **static**: Positioned according to normal flow, ignores insets (web defaults feature)

### Layout Properties
- **Flexbox properties**: flex-direction, justify-content, align-items, flex-wrap
- **Sizing**: width, height, min/max constraints  
- **Spacing**: margin, padding, border
- **Positioning**: top, left, right, bottom insets

## API Reference

### LayoutConfig
```dart
class LayoutConfig {
  static Future<void> enableWebDefaults()
  static Future<void> disableWebDefaults()  
  static bool isWebDefaultsEnabled()
}
```

### LayoutDefaults
```dart
class LayoutDefaults {
  // Yoga native defaults
  static const yogaFlexDirection = 'column';
  static const yogaAlignContent = 'flex-start';
  static const yogaFlexShrink = 0.0;
  
  // Web defaults  
  static const webFlexDirection = 'row';
  static const webAlignContent = 'stretch';
  static const webFlexShrink = 1.0;
}
```

## Related Documentation

- [📖 Complete Properties Reference](./properties_reference.md) - All layout properties with visual illustrations
- [🎯 Layout Patterns Guide](./layout_patterns.md) - Common layout patterns and quick reference
- [🌐 UseWebDefaults Guide](./web_defaults.md) - Cross-platform layout compatibility
- [📚 API Reference](../../primitives_docs/API_REFERENCE.md) - Complete API documentation
- [⚡ Performance Optimization](../performance/state_preservation.md) - Layout performance tips

## Architecture

```
Dart Layer (LayoutConfig)
    ↓ layoutChannel
Swift Layer (DCFLayoutManager)  
    ↓ coordination
YogaShadowTree (Layout Calculations)
    ↓ native calls
Yoga Engine (Facebook's Layout)
```

The layout system is designed for:
- **Performance**: Native calculations with minimal bridge overhead
- **Flexibility**: Configurable behavior for different use cases
- **Consistency**: Cross-platform layout compatibility
- **Extensibility**: Easy to add new layout features and properties
