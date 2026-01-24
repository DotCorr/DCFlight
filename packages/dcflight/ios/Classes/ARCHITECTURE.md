# iOS Styling System Architecture

## Overview

The iOS styling system uses **direct property mapping** to match the standard model's architecture. Each style property is directly mapped to a native view property setter, ensuring consistent behavior and optimal performance.

## Architecture Components

### 1. **Views/** Folder - Native View Classes

Contains Objective-C view classes that provide direct property setters:

- **`DCFView.h` / `DCFView.m`**: Custom UIView subclass with direct property setters
  - Properties: `borderRadius`, `borderWidth`, `borderColor`, etc.
  - Implements `displayLayer:` for border rendering
  - Uses `-1` as unset value (matching standard model)
  - Handles complex border rendering (individual corners, colors, styles)

**Usage:**
```swift
let view = DCFView()
view.borderRadius = 8.0
view.borderWidth = 2.0
view.borderColor = UIColor.blue.cgColor
```

### 2. **Components/** Folder - Component Implementations

Contains Swift component classes that implement the `DCFComponent` protocol:

- **`DCFFlutterWidgetComponent.swift`**: Component for embedding Flutter widgets
- Other components (Text, ScrollView, etc.) are in `Coordination/Components/`

**Difference:**
- **Views/** = Native view classes (Objective-C UIView subclasses)
- **Components/** = Component implementations (Swift classes that create/manage views)

### 3. **Utilities/** Folder - Property Mapping

- **`DCFViewPropertyMapper.swift`**: Maps style properties directly to native view properties
  - Each property is mapped to its corresponding setter
  - Supports both `DCFView` (advanced) and regular `UIView` (simple)
  - Handles: borders, radius, colors, shadows, gradients, transforms, accessibility

- **`UIView+Styling.swift`**: Deprecated wrapper (maintained for backward compatibility)
  - `applyStyles()` now delegates to `applyProperties()`
  - Can be removed once all code migrates to `applyProperties()`

- **`DCFStyleRegistry.swift`**: Style ID caching and resolution
  - Caches styles by numeric ID
  - Resolves style IDs to full style objects

## Property Mapping Flow

```
Dart Side (DCFStyleSheet.toMap())
    ↓
JSON Props Dictionary
    ↓
Native iOS (DCFViewPropertyMapper.applyProperties())
    ↓
Direct Property Setters (view.borderRadius = 8.0)
    ↓
Native View Properties (layer.cornerRadius, etc.)
```

## Dart Side Compatibility

✅ **Fully Compatible**: The Dart side sends props via `DCFStyleSheet.toMap()`, which creates a dictionary with keys like:
- `"borderRadius"` → `CGFloat`
- `"borderColor"` → `"dcf:#0000ff"` (processed color string)
- `"backgroundColor"` → `"dcf:#ffffff"`
- `"styleId"` → `Int` (for registered styles)

The `DCFViewPropertyMapper` handles all these formats and maps them directly to native properties.

## Migration Path

1. ✅ **New Code**: Use `view.applyProperties(props:)` directly
2. ⚠️ **Legacy Code**: `view.applyStyles(props:)` still works (delegates to `applyProperties`)
3. 🔜 **Future**: Remove `applyStyles()` once all code migrates

## Key Benefits

- **Direct Property Mapping**: Matches standard model architecture
- **Better Performance**: Direct property access, no monolithic function
- **Easier Maintenance**: Each property is handled independently
- **Consistent Behavior**: Same approach as standard model
- **Backward Compatible**: Old `applyStyles()` still works
