# Explicit Color Overrides System

## Overview

The explicit color override system allows components to override semantic colors for specific aspects while maintaining the semantic color system as the default. This provides fine-grained control for edge cases without breaking theme consistency.

---

## How It Works

### Priority System

**Priority Order:**
1. **Explicit Color Prop** (if provided) → Use it
2. **Semantic Color** (if explicit not provided) → Use semantic color
3. **No Color** → Don't set color (graceful degradation)

### Example

```dart
// Default: Uses StyleSheet.primaryColor for button text
DCFButton(
  buttonProps: DCFButtonProps(title: "Click me"),
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)

// Override: Uses explicit textColor instead of primaryColor
DCFButton(
  buttonProps: DCFButtonProps(title: "Click me"),
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
  textColor: DCFColors.red,  // ✅ Overrides primaryColor for text only
)
```

---

## iOS Implementation

### Helper Function

**File:** `packages/dcflight/ios/Classes/Utilities/ColorUtilities.swift`

```swift
/// Get color with explicit override fallback to semantic color
/// Priority: explicitColor > semanticColor
public static func getColor(
    explicitColor: String?,
    semanticColor: String?,
    from props: [String: Any]
) -> UIColor? {
    // Priority 1: Check explicit color prop
    if let explicitColorKey = explicitColor,
       let explicitColorStr = props[explicitColorKey] as? String {
        if let color = color(fromHexString: explicitColorStr) {
            return color
        }
    }
    
    // Priority 2: Fall back to semantic color
    if let semanticColorKey = semanticColor,
       let semanticColorStr = props[semanticColorKey] as? String {
        if let color = color(fromHexString: semanticColorStr) {
            return color
        }
    }
    
    return nil
}
```

### Component Usage

**Example: Button Component**

```swift
// COLOR SYSTEM: Explicit color override > Semantic color
// textColor (explicit) > primaryColor (semantic)
if let textColor = ColorUtilities.getColor(
    explicitColor: "textColor",
    semanticColor: "primaryColor",
    from: props
) {
    button.setTitleColor(textColor, for: .normal)
}
```

---

## Dart Implementation

### Component Props

**Example: Button Component**

```dart
class DCFButton extends DCFStatelessComponent {
  /// Explicit color override: textColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for button text
  final DCFColor? textColor;

  DCFButton({
    this.buttonProps = const DCFButtonProps(title: "Button"),
    this.textColor,  // ✅ Optional explicit color override
    // ...
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      ...styleSheet.toMap(),
      if (textColor != null) 'textColor': textColor!.toHexString(),  // ✅ Pass to native
      // ...
    };
  }
}
```

---

## Supported Components & Overrides

### Button
- **`textColor`** → Overrides `primaryColor` for button text

### Text
- **`textColor`** → Overrides `primaryColor` for text color

### TextInput
- **`textColor`** → Overrides `primaryColor` for text color
- **`placeholderColor`** → Overrides `secondaryColor` for placeholder text
- **`selectionColor`** → Overrides `accentColor` for text selection

### SegmentedControl
- **`selectedBackgroundColor`** → Overrides `primaryColor` for selected segment background
- **`tintColor`** → Overrides `secondaryColor` for tint/text

### Slider
- **`minimumTrackColor`** → Overrides `primaryColor` for minimum track
- **`maximumTrackColor`** → Overrides `secondaryColor` for maximum track
- **`thumbColor`** → Overrides `primaryColor` for thumb

### Toggle
- **`activeColor`** → Overrides `primaryColor` for active track/thumb
- **`inactiveColor`** → Overrides `secondaryColor` for inactive track

### Checkbox
- **`checkedColor`** → Overrides `primaryColor` for checked state
- **`uncheckedColor`** → Overrides `secondaryColor` for unchecked state
- **`checkmarkColor`** → Overrides `primaryColor` for checkmark

### Dropdown
- **`placeholderColor`** → Overrides `secondaryColor` for placeholder text

### Spinner
- **`spinnerColor`** → Overrides `primaryColor` for spinner color

---

## Usage Examples

### Example 1: Button with Custom Text Color

```dart
DCFButton(
  buttonProps: DCFButtonProps(title: "Custom Color"),
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,  // Default for other components
    backgroundColor: DCFColors.white,
  ),
  textColor: DCFColors.red,  // ✅ Overrides primaryColor for this button's text only
)
```

**Result:**
- Button text: Red (from `textColor`)
- Other components: Blue (from `primaryColor`)

### Example 2: TextInput with Custom Placeholder

```dart
DCFTextInput(
  placeholder: "Enter text...",
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.black,      // Text color
    secondaryColor: DCFColors.gray,    // Default placeholder color
    accentColor: DCFColors.blue,       // Selection color
  ),
  placeholderColor: DCFColors.lightGray,  // ✅ Overrides secondaryColor for placeholder only
)
```

**Result:**
- Text color: Black (from `primaryColor`)
- Placeholder: Light Gray (from `placeholderColor` override)
- Selection: Blue (from `accentColor`)

### Example 3: Slider with Custom Track Colors

```dart
DCFSlider(
  value: 0.5,
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,    // Default for other components
    secondaryColor: DCFColors.gray, // Default for other components
  ),
  minimumTrackColor: DCFColors.green,  // ✅ Overrides primaryColor for min track
  maximumTrackColor: DCFColors.lightGray,  // ✅ Overrides secondaryColor for max track
  thumbColor: DCFColors.orange,  // ✅ Overrides primaryColor for thumb
)
```

**Result:**
- Minimum track: Green (from `minimumTrackColor`)
- Maximum track: Light Gray (from `maximumTrackColor`)
- Thumb: Orange (from `thumbColor`)
- Other components: Blue/Gray (from semantic colors)

---

## Benefits

### 1. Theme Consistency (Default)

Semantic colors remain the default:
```dart
// All components use semantic colors from StyleSheet
DCFStyleSheet(
  primaryColor: DCFColors.blue,
  secondaryColor: DCFColors.gray,
)
```

### 2. Fine-Grained Control (When Needed)

Override specific aspects without affecting others:
```dart
// Override only placeholder color, keep text color semantic
DCFTextInput(
  placeholderColor: DCFColors.lightGray,  // ✅ Override
  // textColor uses primaryColor (semantic)
)
```

### 3. No Breaking Changes

Semantic colors still work:
```dart
// Still works - uses semantic colors
DCFButton(
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
  // No textColor override = uses primaryColor
)
```

---

## Implementation Details

### iOS Native Side

All components use the `ColorUtilities.getColor()` helper:

```swift
// Pattern used in all components
if let textColor = ColorUtilities.getColor(
    explicitColor: "textColor",      // Explicit prop name
    semanticColor: "primaryColor",   // Semantic fallback
    from: props
) {
    // Apply color
    button.setTitleColor(textColor, for: .normal)
}
```

### Dart Side

All components include optional explicit color props:

```dart
class DCFButton extends DCFStatelessComponent {
  final DCFColor? textColor;  // Optional override
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      elementProps: {
        ...styleSheet.toMap(),  // Includes semantic colors
        if (textColor != null) 'textColor': textColor!.toHexString(),  // Override if provided
      },
    );
  }
}
```

---

## Component Reference

### Complete List of Explicit Color Overrides

| Component | Explicit Color Props | Semantic Fallback |
|-----------|---------------------|-------------------|
| **Button** | `textColor` | `primaryColor` |
| **Text** | `textColor` | `primaryColor` |
| **TextInput** | `textColor`, `placeholderColor`, `selectionColor` | `primaryColor`, `secondaryColor`, `accentColor` |
| **SegmentedControl** | `selectedBackgroundColor`, `tintColor` | `primaryColor`, `secondaryColor` |
| **Slider** | `minimumTrackColor`, `maximumTrackColor`, `thumbColor` | `primaryColor`, `secondaryColor` |
| **Toggle** | `activeColor`, `inactiveColor` | `primaryColor`, `secondaryColor` |
| **Checkbox** | `checkedColor`, `uncheckedColor`, `checkmarkColor` | `primaryColor`, `secondaryColor` |
| **Dropdown** | `placeholderColor` | `secondaryColor` |
| **Spinner** | `spinnerColor` | `primaryColor` |

---

## Best Practices

### 1. Use Semantic Colors by Default

```dart
// ✅ Good - Use semantic colors
DCFButton(
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)
```

### 2. Override Only When Needed

```dart
// ✅ Good - Override only specific aspect
DCFTextInput(
  placeholderColor: DCFColors.lightGray,  // Only override placeholder
  // Text color still uses primaryColor
)
```

### 3. Don't Override Everything

```dart
// ❌ Bad - Overriding everything defeats the purpose
DCFButton(
  textColor: DCFColors.red,
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),  // Unused
)
```

**Better:**
```dart
// ✅ Good - Use semantic color
DCFButton(
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.red),
)
```

---

## Summary

✅ **Semantic colors are the default** - Theme consistency maintained  
✅ **Explicit colors override specific aspects** - Fine-grained control when needed  
✅ **No breaking changes** - Existing code still works  
✅ **Component-specific overrides** - Override only what you need  

The system ensures semantic colors remain the default for theming and unified styling, while allowing explicit color overrides for specific edge cases where component-specific color changes are needed.

