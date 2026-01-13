# StyleSheet Examples

This folder contains comprehensive examples demonstrating all StyleSheet properties and best practices.

## Structure

- `examples_registry.dart` - Registry of all examples
- `border_examples.dart` - Border properties (borderWidth, borderColor, borderRadius, etc.)
- `shadow_examples.dart` - Shadow properties (shadowColor, shadowOpacity, shadowRadius, etc.)
- `gradient_examples.dart` - Background gradient examples
- `transform_examples.dart` - Transform properties (NOTE: Transforms are in DCFLayout, not StyleSheet)
- `corner_radius_examples.dart` - Corner radius variations
- `opacity_examples.dart` - Opacity property
- `accessibility_examples.dart` - Accessibility properties
- `comprehensive_examples.dart` - Combining multiple properties
- `style_sheet_examples_screen.dart` - Main screen displaying all examples

## Important Notes

### Property Separation

**DCFStyleSheet** contains:
- `backgroundColor`, `backgroundGradient`
- `borderWidth`, `borderColor`, `borderRadius` (all variants)
- `shadowColor`, `shadowOpacity`, `shadowRadius`, `shadowOffsetX`, `shadowOffsetY`, `elevation`
- `opacity`
- Accessibility properties (`accessible`, `accessibilityLabel`, etc.)
- `testID`, `pointerEvents`

**DCFLayout** contains:
- `padding`, `margin`, `width`, `height`
- `flexDirection`, `justifyContent`, `alignItems`
- `gap`, `flex`, `flexGrow`, `flexShrink`
- **Transforms**: `rotateInDegrees`, `translateX`, `translateY`, `scale`, `scaleX`, `scaleY`

**DCFTextProps** contains:
- `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`
- `numberOfLines`, `textAlign`

### Usage Pattern

```dart
DCFView(
  layout: DCFLayout(
    padding: 20,           // Layout property
    marginBottom: 16,      // Layout property
    width: 200,            // Layout property
    flexDirection: DCFFlexDirection.column, // Layout property
  ),
  styleSheet: DCFStyleSheet(
    backgroundColor: DCFColors.white,  // StyleSheet property
    borderRadius: 8,                   // StyleSheet property
    shadowOpacity: 0.1,                // StyleSheet property
  ),
  children: [
    DCFText(
      content: "Hello",
      textProps: DCFTextProps(
        fontSize: 16,      // TextProps property
        fontWeight: DCFFontWeight.bold, // TextProps property
      ),
      styleSheet: DCFStyleSheet(
        primaryColor: DCFColors.black, // StyleSheet property
      ),
    ),
  ],
)
```

## Current Status

⚠️ **Note**: The example files currently have compilation errors because they mix properties incorrectly. They need to be updated to:
1. Move layout properties (padding, margin, width, height) to `DCFLayout`
2. Move text properties (fontSize, fontWeight) to `DCFTextProps`
3. Keep only StyleSheet properties in `DCFStyleSheet`
4. Move transforms to `DCFLayout` (they're not StyleSheet properties)

## Accessing Examples

Click the "StyleSheet Examples →" button in the top-right corner of the app to view all examples.


