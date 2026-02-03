# DCFlight Styling System Documentation

## Overview

This document describes how the DCFlight styling system works, from Dart definitions to native rendering. It serves as both documentation and a reference for aligning with React Native's styling model.

## Architecture Overview

### 1. Dart Side: `DCFStyleSheet`

`DCFStyleSheet` is a Dart class that defines visual styling properties. It follows a similar pattern to React Native's `StyleSheet.create()` but is implemented in Dart.

#### Style Registration (React Native Pattern)

```dart
// React Native equivalent:
// const styles = StyleSheet.create({
//   container: { backgroundColor: '#fff' }
// });

// DCFlight:
final styles = DCFStyleSheet.create({
  'container': DCFStyleSheet(backgroundColor: Colors.white),
});
```

**How it works:**
- `DCFStyleSheet.create()` registers styles in `_DCFStyleRegistry`
- Each registered style gets a unique ID (e.g., `'dcf_style_1'`)
- The registry maps: `ID -> original style object` and `style object -> ID`
- **Current limitation:** Native side doesn't support style IDs yet, so `toMap()` resolves IDs to full objects before serialization

#### Style Properties

`DCFStyleSheet` supports all React Native-compatible style properties:

**Borders:**
- `borderRadius`, `borderTopLeftRadius`, `borderTopRightRadius`, `borderBottomLeftRadius`, `borderBottomRightRadius`
- `borderColor`, `borderTopColor`, `borderRightColor`, `borderBottomColor`, `borderLeftColor`
- `borderWidth`, `borderTopWidth`, `borderRightWidth`, `borderBottomWidth`, `borderLeftWidth`
- `borderStyle` (planned: 'solid', 'dotted', 'dashed')

**Background:**
- `backgroundColor` (Color)
- `backgroundGradient` (DCFGradient)

**Shadows & Elevation:**
- `shadowColor`, `shadowOpacity`, `shadowRadius`, `shadowOffsetX`, `shadowOffsetY`
- `elevation` (Android Material Design, converted to shadow on iOS)

**Other:**
- `opacity`
- `hitSlop` (DCFHitSlop)
- Accessibility properties (see below)
- Semantic colors (see below)

### 2. Style Serialization: `toMap()`

When a `DCFStyleSheet` is applied to a component, it's converted to a `Map<String, dynamic>` via `toMap()`:

```dart
Map<String, dynamic> toMap() {
  final map = <String, dynamic>{};
  
  // Border properties
  if (borderRadius != null) map['borderRadius'] = borderRadius;
  if (borderColor != null) map['borderColor'] = _colorToString(borderColor!);
  // ... etc
  
  return map;
}
```

**Key behaviors:**
- Only non-null properties are included
- Colors are converted to strings via `_colorToString()` (see Color Processing below)
- Gradients are serialized via `DCFGradient.toMap()`
- Registered styles (with IDs) are resolved to full objects before serialization

### 3. Color Processing

#### Dart Side: `_colorToString()`

Colors are converted to strings with a `'dcf:'` prefix to distinguish special cases:

```dart
String _colorToString(Color color) {
  final alpha = (color.a * 255.0).round() & 0xff;
  
  // Transparent - explicitly marked
  if (alpha == 0) return 'dcf:transparent';
  
  // Black - explicitly marked to distinguish from transparent
  if (color.value == 0xFF000000) return 'dcf:black';
  
  // Other colors - hex format
  if (alpha == 255) {
    return 'dcf:#${hexValue}';  // 6-digit hex
  } else {
    return 'dcf:#${argbValue}';  // 8-digit hex with alpha
  }
}
```

**Format:**
- `'dcf:transparent'` - fully transparent
- `'dcf:black'` - opaque black (0xFF000000)
- `'dcf:#RRGGBB'` - opaque color (6-digit hex)
- `'dcf:#AARRGGBB'` - color with alpha (8-digit hex, ARGB format)

#### Native Side: Color Parsing

**iOS (`ColorUtilities.color(fromHexString:)`):**
- Parses `'dcf:transparent'` → `UIColor.clear`
- Parses `'dcf:black'` → `UIColor.black`
- Parses `'dcf:#RRGGBB'` → `UIColor` with RGB
- Parses `'dcf:#AARRGGBB'` → `UIColor` with ARGB

**Android (`ColorUtilities.parseColor()`):**
- Similar parsing logic for Android `Color` ints

**React Native Comparison:**
- React Native uses `processColor.js` → `normalizeColor.js` to convert:
  - Hex strings (`'#f00'`, `'#ff0000'`, `'#ff0000ff'`)
  - RGB/RGBA strings (`'rgb(255,0,0)'`, `'rgba(255,0,0,1)'`)
  - HSL/HSLA strings
  - Named colors (`'red'`, `'transparent'`, etc.)
  - Numbers (0xRRGGBBAA format)
- Final output: 32-bit integer (0xAARRGGBB on iOS, 0xAARRGGBB signed on Android)
- **DCFlight difference:** We use string format with `'dcf:'` prefix instead of integers

### 4. Style Preprocessing

#### Dart Side: `preprocessProps()`

Before styles are sent to native, they pass through `preprocessProps()` in `interface_util.dart`:

```dart
Map<String, dynamic> preprocessProps(Map<String, dynamic> props) {
  final processedProps = <String, dynamic>{};
  
  props.forEach((key, value) {
    if (value is Color) {
      // Convert Color to string (same as _colorToString)
      processedProps[key] = _colorToString(value);
    } else if (value is DCFStyleSheet) {
      // Convert DCFStyleSheet to map
      processedProps[key] = value.toMap();
    }
    // ... other preprocessing
  });
  
  return processedProps;
}
```

**Current behavior:**
- Colors are converted to strings
- `DCFStyleSheet` objects are converted to maps
- Functions are handled separately (event handlers)
- Layout properties (width, height, margin, padding) are normalized

**React Native Comparison:**
- React Native has style processors for:
  - `processColor.js` - color conversion
  - `processTransform.js` - transform arrays to matrices
  - `processShadow.js` - shadow property normalization
  - `processAspectRatio.js` - aspect ratio calculations
- These run **before** styles are sent to native
- **DCFlight difference:** We do minimal preprocessing; most normalization happens on native side

### 5. Native Side: Style Application

#### iOS: `UIView+Styling.swift`

Styles are applied via `applyStyles(props: [String: Any])`:

```swift
public func applyStyles(props: [String: Any]) {
  // Border radius
  if let borderRadius = props["borderRadius"] as? CGFloat {
    layer.cornerRadius = borderRadius
  }
  
  // Border color/width
  if let borderColor = props["borderColor"] as? String {
    layer.borderColor = ColorUtilities.color(fromHexString: borderColor)?.cgColor
  }
  if let borderWidth = props["borderWidth"] as? CGFloat {
    layer.borderWidth = borderWidth
  }
  
  // Background color
  if let backgroundColor = props["backgroundColor"] as? String {
    self.backgroundColor = ColorUtilities.color(fromHexString: backgroundColor)
  }
  
  // ... etc
}
```

**Key behaviors:**
- Properties are read directly from the props map
- Colors are parsed from strings
- Layout properties (width, height, etc.) are handled separately by Yoga
- Transforms are applied as `CATransform3D` matrices (post-layout)

#### Android: `ViewStyleExtensions.kt`

Similar pattern for Android:

```kotlin
fun View.applyStyles(props: Map<String, Any>) {
  // Border radius
  props["borderRadius"]?.let { borderRadius ->
    drawable.cornerRadius = applyStyleDensityScaling(borderRadius.toFloat())
  }
  
  // Border color/width
  props["borderColor"]?.let { color ->
    drawable.setStroke(borderWidth, ColorUtilities.parseColor(color))
  }
  
  // Background color
  props["backgroundColor"]?.let { color ->
    drawable.setColor(ColorUtilities.parseColor(color))
  }
  
  // ... etc
}
```

**Key behaviors:**
- Density scaling applied to dimension values (DP → pixels)
- `GradientDrawable` used for backgrounds and borders
- Elevation converted to Material Design shadows

### 6. Layout vs. Style Separation

**Critical distinction:**
- **Layout properties** (flex, width, height, margin, padding, position) → Handled by **Yoga layout engine**
- **Style properties** (colors, borders, shadows, gradients, transforms) → Handled by **native view properties**

**Yoga Layout:**
- Calculates view positions and sizes
- Runs on native side (C/C++ Flexbox engine)
- Sets `frame`/`bounds` on iOS, `layoutParams` on Android

**Native Styling:**
- Applied **after** layout is calculated
- Uses native view/layer properties
- Does **not** affect layout calculations

**React Native Model:**
- Same separation: Yoga for layout, native properties for styling
- Styles are preprocessed on JS side, then sent to native
- Native side applies styles directly to view properties

### 7. Semantic Colors

DCFlight supports semantic colors for theme-aware styling:

```dart
DCFStyleSheet(
  primaryColor: DCFTheme.textColor,      // Main text color
  secondaryColor: DCFTheme.secondaryTextColor,  // Secondary text
  tertiaryColor: DCFTheme.tertiaryTextColor,
  accentColor: DCFTheme.accentColor,
  backgroundColor: DCFTheme.backgroundColor,
)
```

**How it works:**
- Semantic colors are **always** included in `toMap()` (with theme fallbacks)
- Components use semantic colors instead of explicit color props
- Example: `DCFText` uses `primaryColor` for text color, `secondaryColor` for placeholder

**React Native Comparison:**
- React Native doesn't have built-in semantic colors
- Apps typically use theme objects or context
- **DCFlight advantage:** Built-in semantic color system

### 8. Style Property Precedence

When multiple styles are merged (e.g., via `merge()` or style arrays):

1. **Later styles override earlier ones** (standard merge behavior)
2. **Specific properties override general ones:**
   - `borderTopWidth` overrides `borderWidth`
   - `borderTopLeftRadius` overrides `borderRadius`
3. **Gradient overrides background color:**
   - If both `backgroundColor` and `backgroundGradient` are set, gradient takes precedence
   - Native side sets `backgroundColor = .clear` when gradient exists

**React Native Comparison:**
- React Native uses `flattenStyle()` to merge style arrays
- Same precedence rules apply
- **DCFlight difference:** We use `merge()` method instead of array flattening

### 9. Style Validation

`DCFStyleSheet.validateStyles()` checks for conflicts:

```dart
List<String> validateStyles() {
  final warnings = <String>[];
  
  if (backgroundColor != null && backgroundGradient != null) {
    warnings.add('Both backgroundColor and backgroundGradient are set. backgroundGradient will take precedence.');
  }
  
  // ... other validations
  
  return warnings;
}
```

**React Native Comparison:**
- React Native has `StyleSheetValidation.validateStyle()` in dev mode
- Validates property names and types
- **DCFlight difference:** We validate conflicts, not property names (Dart type system handles that)

### 10. Current Limitations & Future Improvements

#### Style ID Support
- **Current:** Style IDs are generated but not used on native side
- **Future:** Native side should support style IDs to reduce bridge traffic
- **React Native:** Uses numeric IDs, sends only ID + diff on updates

#### Style Processors
- **Current:** Minimal preprocessing on Dart side
- **Future:** Add processors for:
  - Transform normalization (array → matrix)
  - Shadow property validation
  - Aspect ratio calculations
- **React Native:** Has dedicated processors for each property type

#### Border Style Support
- **Current:** `borderStyle` property exists but not implemented on native
- **Future:** Support 'solid', 'dotted', 'dashed' on both iOS and Android
- **React Native:** Supports all three styles

#### Color Format Support
- **Current:** Only supports Flutter `Color` objects and hex strings
- **Future:** Support RGB/RGBA strings, HSL/HSLA, named colors
- **React Native:** Supports all CSS color formats

## React Native Styling Model Reference

### How React Native Works

1. **StyleSheet.create()** - Registers styles, returns numeric IDs
2. **Style Processors** - Preprocess colors, transforms, shadows on JS side
3. **Yoga Layout** - Calculates layout on native side (C/C++ Flexbox)
4. **Native Properties** - Styles applied directly to native view properties
5. **Bridge Communication** - Sends style IDs + diffs (not full objects)

### Key Differences from DCFlight

| Feature | React Native | DCFlight |
|---------|-------------|----------|
| Style IDs | Numeric (int) | String (`'dcf_style_1'`) |
| Color Format | 32-bit integer | String with `'dcf:'` prefix |
| Style Processors | Multiple (color, transform, shadow) | Minimal (color only) |
| Native ID Support | Yes (optimized) | No (sends full objects) |
| Border Style | Full support | Planned |
| Semantic Colors | No (app-level) | Yes (built-in) |

## Native Side Expectations

### iOS (`UIView+Styling.swift`)

**Expected prop types:**
- `borderRadius`, `borderTopLeftRadius`, etc. → `CGFloat`
- `borderColor`, `borderTopColor`, etc. → `String` (hex format)
- `borderWidth`, `borderTopWidth`, etc. → `CGFloat`
- `backgroundColor` → `String` (hex format)
- `backgroundGradient` → `[String: Any]` (gradient data)
- `shadowColor` → `String` (hex format)
- `shadowOpacity` → `Float`
- `shadowRadius` → `CGFloat`
- `shadowOffsetX`, `shadowOffsetY` → `CGFloat`
- `elevation` → `CGFloat` (converted to shadow)

**Color parsing:**
- `'dcf:transparent'` → `UIColor.clear`
- `'dcf:black'` → `UIColor.black`
- `'dcf:#RRGGBB'` → `UIColor` (RGB)
- `'dcf:#AARRGGBB'` → `UIColor` (ARGB)

**Layout properties:**
- Handled by Yoga, not in `applyStyles()`
- Yoga sets `frame`/`bounds`, we apply styles to those bounds

### Android (`ViewStyleExtensions.kt`)

**Expected prop types:**
- Same as iOS, but with density scaling for dimensions
- `borderRadius`, `borderWidth`, etc. → Scaled from DP to pixels

**Color parsing:**
- Same format as iOS
- Returns Android `Color` int (0xAARRGGBB)

**Layout properties:**
- Handled by Yoga
- Sets `layoutParams`, we apply styles to those bounds

## Best Practices

### 1. Use StyleSheet.create() for Performance

```dart
// ✅ Good: Registered styles (future optimization)
final styles = DCFStyleSheet.create({
  'container': DCFStyleSheet(backgroundColor: Colors.blue),
});

// ❌ Avoid: Inline styles (no caching)
DCFView(style: DCFStyleSheet(backgroundColor: Colors.blue))
```

### 2. Use Semantic Colors for Theming

```dart
// ✅ Good: Theme-aware
DCFText(
  style: DCFStyleSheet(primaryColor: DCFTheme.textColor),
)

// ❌ Avoid: Hard-coded colors
DCFText(
  style: DCFStyleSheet(primaryColor: Colors.black),
)
```

### 3. Merge Styles Correctly

```dart
// ✅ Good: Later styles override earlier
final baseStyle = DCFStyleSheet(backgroundColor: Colors.white);
final overrideStyle = DCFStyleSheet(backgroundColor: Colors.blue);
final merged = baseStyle.merge(overrideStyle);  // Result: blue background

// ❌ Avoid: Manual property copying
```

### 4. Validate Styles in Development

```dart
final style = DCFStyleSheet(
  backgroundColor: Colors.blue,
  backgroundGradient: DCFGradient(...),
);

final warnings = style.validateStyles();
if (warnings.isNotEmpty) {
  print('Style warnings: $warnings');
}
```

## Migration Path to React Native Model

### Phase 1: Native Style ID Support
- [ ] Add style ID registry on native side (iOS & Android)
- [ ] Send style IDs instead of full objects
- [ ] Cache styles on native side

### Phase 2: Style Processors
- [ ] Add `processTransform()` for transform arrays
- [ ] Add `processShadow()` for shadow validation
- [ ] Add `processAspectRatio()` for aspect ratio calculations

### Phase 3: Enhanced Color Support
- [ ] Support RGB/RGBA strings
- [ ] Support HSL/HSLA strings
- [ ] Support named colors (CSS color names)

### Phase 4: Border Style Support
- [ ] Implement 'dotted' border style
- [ ] Implement 'dashed' border style
- [ ] Test on both iOS and Android

## Conclusion

The DCFlight styling system is designed to match React Native's model while adding Dart-specific features (semantic colors, type safety). The current implementation is functional but can be optimized by:

1. Adding native style ID support
2. Implementing style processors
3. Expanding color format support
4. Completing border style support

This document serves as both documentation and a roadmap for future improvements.
