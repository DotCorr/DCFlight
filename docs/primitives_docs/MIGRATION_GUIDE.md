# Migration Guide - DCFlight v0.0.2

This guide helps you migrate from previous versions of DCFlight to v0.0.2, which includes significant improvements and some breaking changes.

## 🚨 Breaking Changes

### Removed Components

The following components have been **removed** from the framework as they were deemed unnecessary for a lean, focused primitive set:

#### DCFSwipeableViewComponent
- **Status**: ❌ Removed
- **Reason**: Overly complex for a primitive, better handled at application level
- **Migration**: Implement custom swipe gestures using `DCFGestureDetector`

```dart
// OLD (v0.0.1) - No longer available
DCFSwipeableView(
  onSwipeLeft: () => {},
  onSwipeRight: () => {},
  child: MyWidget(),
)

// NEW (v0.0.2) - Use gesture detector instead
DCFGestureDetector(
  onPanEnd: (details) {
    if (details.velocity.pixelsPerSecond.dx > 0) {
      // Handle swipe right
    } else {
      // Handle swipe left  
    }
  },
  children: [MyWidget()],
)
```

#### DCFAnimatedTextComponent
- **Status**: ❌ Removed  
- **Reason**: Animation should be handled by framework animation system
- **Migration**: Use `DCFText` with `DCFAnimatedView` wrapper

```dart
// OLD (v0.0.1) - No longer available
DCFAnimatedText(
  text: "Hello World",
  animationType: "fade",
)

// NEW (v0.0.2) - Combine text with animated view
DCFAnimatedView(
  duration: Duration(milliseconds: 500),
  children: [
    DCFText(text: "Hello World"),
  ],
)
```

## ✨ New Features

### DCFSegmentedControl (New Component)

A powerful new segmented control component with icon support:

```dart
// Basic text segments
DCFSegmentedControl(
  segments: ['First', 'Second', 'Third'],
  selectedIndex: 0,
  onSelectionChange: (data) {
    print("Selected: ${data['selectedIndex']}");
  },
)

// With icons (NEW FEATURE)
DCFSegmentedControl(
  segments: ['Home', 'Search', 'Profile'],
  iconAssets: [
    'assets/icons/home.svg',
    'assets/icons/search.svg', 
    'assets/icons/profile.svg'
  ],
  selectedIndex: 0,
  backgroundColor: "#F0F0F0",
  selectedTintColor: "#007AFF",
  onSelectionChange: (data) {
    int index = data['selectedIndex'];
    String title = data['selectedTitle'];
    // Handle selection
  },
)
```

### Enhanced Modal System

Modals now have improved behavior and child management:

```dart
DCFModal(
  visible: isModalVisible,
  dismissOnBackdropTap: true,
  onDismiss: () {
    setState(() => isModalVisible = false);
  },
  children: [
    // Children now properly preserved during animations
    MyModalContent(),
  ],
)
```

## 🔧 Technical Improvements

### Color Management Unification

All components now use centralized color utilities. **No action required** - this is backward compatible:

```dart
// These continue to work exactly the same
DCFButton(
  backgroundColor: "#FF5733",  // Still works
  titleColor: "#FFFFFF",       // Still works
)

DCFText(
  color: "#333333",            // Still works
)
```

### Enhanced Asset Loading

Asset loading is now more consistent across all components. **No changes required** for existing code:

```dart
// Continues to work as before
DCFSvg(asset: "assets/icons/star.svg")
DCFImage(asset: "assets/images/logo.png")
DCFText(
  fontFamily: "assets/fonts/custom.ttf",
  isFontAsset: true,
)
```

## 📝 Code Audit Checklist

Use this checklist to audit your codebase for v0.0.2 compatibility:

### ✅ Required Actions

- [ ] **Search for removed components**:
  ```bash
  # Search your codebase for these removed components
  grep -r "DCFSwipeableView" .
  grep -r "DCFAnimatedText" .
  ```

- [ ] **Replace removed components**:
  - Replace `DCFSwipeableView` with `DCFGestureDetector`
  - Replace `DCFAnimatedText` with `DCFText` + `DCFAnimatedView`

- [ ] **Test modal behavior**:
  - Verify modals open and close smoothly
  - Check that modal children remain visible during animations

### ✅ Optional Enhancements

- [ ] **Consider using new segmented control**:
  - Replace custom tab implementations
  - Leverage icon support for better UX

- [ ] **Audit color usage**:
  - Ensure consistent color format across components
  - Consider using adaptive theming where appropriate

## 🚀 Upgrade Steps

### 1. Update Dependencies
```yaml
# pubspec.yaml
dependencies:
  dcflight: ^0.0.2
  dcf_primitives: ^0.0.2
```

### 2. Run Migration Script
```bash
# Replace removed component imports
find . -name "*.dart" -exec sed -i '' 's/DCFSwipeableView/DCFGestureDetector/g' {} +
find . -name "*.dart" -exec sed -i '' 's/DCFAnimatedText/DCFText/g' {} +
```

### 3. Manual Code Updates
Review and manually update usage of removed components following the patterns shown above.

### 4. Test & Validate
- Run your test suite
- Manually test modal functionality
- Verify component styling and behavior

## 🆘 Need Help?

### Common Issues

**Issue**: "DCFSwipeableView not found"
**Solution**: Replace with `DCFGestureDetector` and implement custom swipe logic

**Issue**: "Modal children disappearing during animation"  
**Solution**: Update to v0.0.2 - this is fixed in the new version

**Issue**: "Colors not rendering correctly"
**Solution**: Ensure color strings are properly formatted (e.g., "#FF5733" not "FF5733")

### Getting Support

1. **Check Documentation**: Review the [Primitives Documentation](./README.md)
2. **API Reference**: See [API Reference](./API_REFERENCE.md) for detailed component specs
3. **Module Guidelines**: For adding new primitives, see [Component Development Guidelines](../module_dev_guidelines/)

## 🎯 Benefits of v0.0.2

After migration, you'll benefit from:

- **Leaner Framework**: Removed bloated components for better performance
- **Better Modals**: Smoother animations and proper child management  
- **Icon Support**: Rich segmented controls with icon capabilities
- **Consistent Architecture**: Unified color management and asset loading
- **Improved Maintainability**: Cleaner codebase with better patterns

---

**Questions?** The migration should be straightforward for most applications. The removed components were rarely used, and the improvements significantly enhance the framework's stability and performance.
