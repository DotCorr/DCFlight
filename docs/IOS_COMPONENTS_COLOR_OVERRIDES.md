# iOS Components - Explicit Color Overrides Complete List

## All iOS Components (18 Total)

### ✅ Components with Explicit Color Overrides (11 components)

| # | Component | Explicit Color Props | Semantic Fallback | Status |
|---|-----------|---------------------|-------------------|--------|
| 1 | **Button** | `textColor` | `primaryColor` | ✅ Complete |
| 2 | **Text** | `textColor` | `primaryColor` | ✅ Complete |
| 3 | **TextInput** | `textColor`, `placeholderColor`, `selectionColor` | `primaryColor`, `secondaryColor`, `accentColor` | ✅ Complete |
| 4 | **SegmentedControl** | `selectedBackgroundColor`, `tintColor` | `primaryColor`, `secondaryColor` | ✅ Complete |
| 5 | **Slider** | `minimumTrackColor`, `maximumTrackColor`, `thumbColor` | `primaryColor`, `secondaryColor` | ✅ Complete |
| 6 | **Toggle** | `activeColor`, `inactiveColor` | `primaryColor`, `secondaryColor` | ✅ Complete |
| 7 | **Checkbox** | `checkedColor`, `uncheckedColor`, `checkmarkColor` | `primaryColor`, `secondaryColor` | ✅ Complete |
| 8 | **Dropdown** | `placeholderColor` | `secondaryColor` | ✅ Complete |
| 9 | **Spinner** | `spinnerColor` | `primaryColor` | ✅ Complete |
| 10 | **Icon** | `iconColor` | `primaryColor` | ✅ Complete |
| 11 | **Svg** | `tintColor` | `primaryColor` | ✅ Complete |

### ⚪ Components Without Color Overrides (7 components)

| # | Component | Reason |
|---|-----------|--------|
| 12 | **View** | Colors handled via StyleSheet only (backgroundColor) |
| 13 | **Image** | Colors handled via StyleSheet only (backgroundColor) |
| 14 | **ScrollView** | No color properties |
| 15 | **GestureDetector** | No color properties |
| 16 | **TouchableOpacity** | No color properties (opacity is not a color) |
| 17 | **Alert** | Uses system colors (no customization needed) |
| 18 | **WebView** | No color properties |

---

## Implementation Summary

### iOS Native Side
- ✅ All 11 color-using components updated
- ✅ All use `ColorUtilities.getColor()` helper
- ✅ Priority: Explicit Color > Semantic Color

### Dart Side
- ✅ All 11 components have explicit color props
- ✅ All use `DCFColors.toNativeString()` for conversion
- ✅ Props are optional (null = use semantic color)

---

## Complete Component Reference

### Button
```dart
DCFButton(
  textColor: DCFColors.red,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)
```

### Text
```dart
DCFText(
  textColor: DCFColors.green,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
)
```

### TextInput
```dart
DCFTextInput(
  textColor: DCFColors.black,           // ✅ Overrides primaryColor
  placeholderColor: DCFColors.gray,     // ✅ Overrides secondaryColor
  selectionColor: DCFColors.blue,       // ✅ Overrides accentColor
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.black,
    secondaryColor: DCFColors.lightGray,
    accentColor: DCFColors.blue,
  ),
)
```

### SegmentedControl
```dart
DCFSegmentedControl(
  selectedBackgroundColor: DCFColors.blue,  // ✅ Overrides primaryColor
  tintColor: DCFColors.gray,                // ✅ Overrides secondaryColor
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,
    secondaryColor: DCFColors.gray,
  ),
)
```

### Slider
```dart
DCFSlider(
  minimumTrackColor: DCFColors.green,  // ✅ Overrides primaryColor
  maximumTrackColor: DCFColors.lightGray,  // ✅ Overrides secondaryColor
  thumbColor: DCFColors.orange,        // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,
    secondaryColor: DCFColors.gray,
  ),
)
```

### Toggle
```dart
DCFToggle(
  activeColor: DCFColors.green,    // ✅ Overrides primaryColor
  inactiveColor: DCFColors.gray,  // ✅ Overrides secondaryColor
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,
    secondaryColor: DCFColors.lightGray,
  ),
)
```

### Checkbox
```dart
DCFCheckbox(
  checkedColor: DCFColors.blue,      // ✅ Overrides primaryColor
  uncheckedColor: DCFColors.gray,    // ✅ Overrides secondaryColor
  checkmarkColor: DCFColors.white,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(
    primaryColor: DCFColors.blue,
    secondaryColor: DCFColors.gray,
  ),
)
```

### Dropdown
```dart
DCFDropdown(
  dropdownProps: DCFDropdownProps(
    placeholderColor: DCFColors.lightGray,  // ✅ Overrides secondaryColor
  ),
  styleSheet: DCFStyleSheet(secondaryColor: DCFColors.gray),
)
```

### Spinner
```dart
DCFSpinner(
  spinnerColor: DCFColors.blue,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)
```

### Icon
```dart
DCFIcon(
  iconProps: DCFIconProps(name: 'home'),
  iconColor: DCFColors.red,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)
```

### Svg
```dart
DCFSVG(
  svgProps: DCFSVGProps(source: 'assets/icon.svg'),
  tintColor: DCFColors.purple,  // ✅ Overrides primaryColor
  styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
)
```

---
