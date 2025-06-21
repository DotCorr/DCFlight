# DCFlight Primitives - Component API Reference

This document provides detailed API information for each primitive component in the DCFlight framework.

## 🎛️ Input Components

### DCFTextInput
**Native Mapping**: UITextField / UITextView

#### Properties
```dart
DCFTextInput({
  String? value,                    // Current text value
  String? placeholder,              // Placeholder text
  String? placeholderColor,         // Placeholder text color (hex)
  bool multiline = false,           // Single vs multi-line input
  int? maxLines,                    // Maximum lines for multiline
  bool obscureText = false,         // Password field
  String? textColor,                // Text color (hex)
  String? selectionColor,           // Cursor/selection color (hex)
  bool enabled = true,              // Input enabled state
  TextInputType? keyboardType,      // Keyboard type
  Function(String)? onChanged,      // Text change callback
  Function(String)? onSubmitted,    // Submit callback
})
```

#### Example Usage
```dart
DCFTextInput(
  placeholder: "Enter your name",
  placeholderColor: "#999999",
  textColor: "#333333",
  onChanged: (value) => print("Text: $value"),
)
```

### DCFButton
**Native Mapping**: UIButton

#### Properties
```dart
DCFButton({
  String? title,                    // Button text
  String? titleColor,               // Text color (hex)
  String? backgroundColor,          // Background color (hex)
  bool enabled = true,              // Button enabled state
  Function()? onPressed,            // Press callback
})
```

### DCFToggle
**Native Mapping**: UISwitch

#### Properties
```dart
DCFToggle({
  bool value = false,               // Current switch state
  String? activeTrackColor,         // Track color when ON (hex)
  String? inactiveTrackColor,       // Track color when OFF (hex)
  String? activeThumbColor,         // Thumb color when ON (hex)
  bool enabled = true,              // Switch enabled state
  Function(bool)? onChanged,        // Value change callback
})
```

### DCFCheckbox
**Native Mapping**: Custom UIView

#### Properties
```dart
DCFCheckbox({
  bool checked = false,             // Current checked state
  String? checkedColor,             // Color when checked (hex)
  String? uncheckedColor,           // Color when unchecked (hex)
  String? checkmarkColor,           // Checkmark color (hex)
  double size = 24.0,               // Checkbox size
  Function(bool)? onChanged,        // State change callback
})
```

### DCFSlider
**Native Mapping**: UISlider

#### Properties
```dart
DCFSlider({
  double value = 0.0,               // Current slider value
  double minimumValue = 0.0,        // Minimum value
  double maximumValue = 1.0,        // Maximum value
  double? step,                     // Step increment
  String? minimumTrackTintColor,    // Left track color (hex)
  String? maximumTrackTintColor,    // Right track color (hex)
  String? thumbTintColor,           // Thumb color (hex)
  bool disabled = false,            // Disabled state
  Function(double)? onChanged,      // Value change callback
  Function(double)? onSlidingStart, // Slide start callback
  Function(double)? onSlidingComplete, // Slide end callback
})
```

### DCFSegmentedControl ⭐ NEW
**Native Mapping**: UISegmentedControl

#### Properties
```dart
DCFSegmentedControl({
  List<String> segments = const ['Segment 1'], // Segment titles
  List<String>? iconAssets,         // Optional icon assets for each segment
  int selectedIndex = 0,            // Currently selected index
  bool enabled = true,              // Control enabled state
  String? backgroundColor,          // Background color (hex)
  String? selectedTintColor,        // Selected segment color (hex, iOS 13+)
  String? tintColor,               // Text color for selected segment (hex)
  Function(Map<dynamic, dynamic>)? onSelectionChange, // Selection callback
})
```

#### Example with Icons
```dart
DCFSegmentedControl(
  segments: ['Home', 'Search', 'Profile'],
  iconAssets: ['assets/icons/home.svg', 'assets/icons/search.svg', 'assets/icons/profile.svg'],
  selectedIndex: 0,
  backgroundColor: "#F0F0F0",
  selectedTintColor: "#007AFF",
  onSelectionChange: (data) {
    print("Selected: ${data['selectedIndex']} - ${data['selectedTitle']}");
  },
)
```

### DCFDropdown
**Native Mapping**: UIButton + UIPickerView

#### Properties
```dart
DCFDropdown({
  List<String> options = const [],  // Dropdown options
  String? selectedValue,            // Currently selected value
  String? placeholder,              // Placeholder text
  String? placeholderColor,         // Placeholder color (hex)
  bool visible = false,             // Dropdown visibility
  Function(String)? onChanged,      // Selection change callback
})
```

## 🎨 Display Components

### DCFText
**Native Mapping**: UILabel

#### Properties
```dart
DCFText({
  String text = '',                 // Text content
  String? fontFamily,               // Font family name
  bool isFontAsset = false,         // Load font from assets
  double? fontSize,                 // Font size
  String? fontWeight,               // Font weight (100-900, bold, normal)
  String? color,                    // Text color (hex)
  int? numberOfLines,               // Max lines (0 = unlimited)
  TextAlign? textAlign,             // Text alignment
})
```

#### Example with Custom Font
```dart
DCFText(
  text: "Custom Font Text",
  fontFamily: "assets/fonts/custom-font.ttf",
  isFontAsset: true,
  fontSize: 18,
  fontWeight: "600",
  color: "#333333",
)
```

### DCFImage
**Native Mapping**: UIImageView

#### Properties
```dart
DCFImage({
  String? asset,                    // Image asset path
  String? backgroundColor,          // Background color (hex)
  ContentMode contentMode = ContentMode.scaleAspectFit, // Scaling mode
})
```

### DCFSvg
**Native Mapping**: UIImageView

#### Properties
```dart
DCFSvg({
  String? asset,                    // SVG asset path
  String? tintColor,                // Tint color (hex)
  String? backgroundColor,          // Background color (hex)
  bool adaptive = true,             // Adaptive theming
  bool isRelativePath = false,      // Relative path flag
})
```

### DCFSpinner
**Native Mapping**: UIActivityIndicatorView

#### Properties
```dart
DCFSpinner({
  bool animating = true,            // Animation state
  String? color,                    // Spinner color (hex)
  bool hidesWhenStopped = true,     // Hide when not animating
})
```

### DCFIcon
**Native Mapping**: UIImageView

#### Properties
```dart
DCFIcon({
  String? iconName,                 // System icon name
  String? color,                    // Icon color (hex)
  double? size,                     // Icon size
})
```

## 📦 Container Components

### DCFView
**Native Mapping**: UIView

#### Properties
```dart
DCFView({
  String? backgroundColor,          // Background color (hex)
  bool adaptive = true,             // Adaptive theming
  List<Widget> children = const [], // Child components
})
```

### DCFModal
**Native Mapping**: Custom modal presentation

#### Properties
```dart
DCFModal({
  bool visible = false,             // Modal visibility
  String? backgroundColor,          // Background color (hex)
  bool dismissOnBackdropTap = true, // Dismiss on backdrop tap
  Function()? onDismiss,           // Dismiss callback
  List<Widget> children = const [], // Modal content
})
```

### DCFVirtualizedFlatList
**Native Mapping**: UITableView

#### Properties
```dart
DCFVirtualizedFlatList({
  List<dynamic> data = const [],    // Data source
  Widget Function(dynamic item, int index)? itemBuilder, // Item builder
  double? itemHeight,               // Fixed item height
  bool scrollEnabled = true,        // Scroll enabled
  Function(int)? onItemTap,        // Item tap callback
})
```

## 🤝 Interaction Components

### DCFTouchableOpacity
**Native Mapping**: UIButton (custom)

#### Properties
```dart
DCFTouchableOpacity({
  double activeOpacity = 0.6,       // Opacity when pressed
  Function()? onPressed,            // Press callback
  List<Widget> children = const [], // Child components
})
```

### DCFGestureDetector
**Native Mapping**: UIGestureRecognizer

#### Properties
```dart
DCFGestureDetector({
  Function()? onTap,                // Tap callback
  Function()? onDoubleTap,          // Double tap callback
  Function(DragDetails)? onPanStart, // Pan start callback
  Function(DragDetails)? onPanUpdate, // Pan update callback
  Function(DragDetails)? onPanEnd,   // Pan end callback
  List<Widget> children = const [], // Child components
})
```

### DCFAnimatedView
**Native Mapping**: UIView + Core Animation

#### Properties
```dart
DCFAnimatedView({
  Duration duration = const Duration(milliseconds: 300), // Animation duration
  Curve curve = Curves.easeInOut,   // Animation curve
  String? backgroundColor,          // Background color (hex)
  double? opacity,                  // View opacity
  List<Widget> children = const [], // Child components
})
```

### DCFAlert
**Native Mapping**: UIAlertController

#### Properties
```dart
DCFAlert({
  String? title,                    // Alert title
  String? message,                  // Alert message
  List<AlertAction> actions = const [], // Alert actions
  bool visible = false,             // Alert visibility
})
```

## 🎯 Common Patterns

### Color Management
All components use the centralized `ColorUtilities` for color conversion:
```dart
// All color properties accept hex strings
color: "#FF5733"        // RGB
color: "#80FF5733"      // ARGB with alpha
color: "transparent"    // Named colors
color: "red"           // System colors
```

### Asset Loading
Assets are loaded using Flutter's asset system:
```dart
// For images and SVGs
asset: "assets/images/logo.png"
asset: "assets/icons/star.svg"

// For fonts
fontFamily: "assets/fonts/custom-font.ttf"
isFontAsset: true
```

### Adaptive Theming
Most components support automatic theme adaptation:
```dart
adaptive: true  // Uses system colors (default)
adaptive: false // Uses explicit colors only
```

---

**Need more details?** Check the implementation files in `packages/dcf_primitives/` for complete API specifications and native implementation details.
