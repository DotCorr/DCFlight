# StyleSheet Property Consistency Check

## Complete Property Comparison: iOS vs Android

| Property | Dart Type | iOS Implementation | Android Implementation | Status |
|----------|-----------|-------------------|----------------------|--------|
| **Borders** |
| `borderRadius` | `dynamic` | ✅ `layer.cornerRadius` (logical points) | ✅ `drawable.cornerRadius` (density scaled) | ✅ Consistent (iOS auto-scales, Android manual) |
| `borderTopLeftRadius` | `dynamic` | ✅ `CACornerMask` + `layer.cornerRadius` | ✅ `drawable.cornerRadii[0,1]` | ✅ Consistent |
| `borderTopRightRadius` | `dynamic` | ✅ `CACornerMask` + `layer.cornerRadius` | ✅ `drawable.cornerRadii[2,3]` | ✅ Consistent |
| `borderBottomLeftRadius` | `dynamic` | ✅ `CACornerMask` + `layer.cornerRadius` | ✅ `drawable.cornerRadii[6,7]` | ✅ Consistent |
| `borderBottomRightRadius` | `dynamic` | ✅ `CACornerMask` + `layer.cornerRadius` | ✅ `drawable.cornerRadii[4,5]` | ✅ Consistent |
| `borderColor` | `Color?` | ✅ `layer.borderColor` (all sides) | ✅ `drawable.setStroke()` (all sides) | ✅ Consistent |
| `borderTopColor` | `Color?` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderRightColor` | `Color?` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderBottomColor` | `Color?` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderLeftColor` | `Color?` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderWidth` | `dynamic` | ✅ `layer.borderWidth` (all sides) | ✅ `drawable.setStroke()` (all sides) | ✅ Consistent |
| `borderTopWidth` | `dynamic` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderRightWidth` | `dynamic` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderBottomWidth` | `dynamic` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| `borderLeftWidth` | `dynamic` | ✅ `CAShapeLayer` individual | ✅ `IndividualBorderDrawable` | ✅ Consistent |
| **Background** |
| `backgroundColor` | `Color?` | ✅ `view.backgroundColor` | ✅ `drawable.setColor()` | ✅ Consistent |
| `backgroundGradient` | `DCFGradient?` | ✅ `CAGradientLayer` | ✅ `GradientDrawable` | ⚠️ Need to verify identical |
| **Opacity** |
| `opacity` | `double?` | ✅ `view.alpha` | ✅ `view.alpha` (except TouchableOpacity) | ✅ Consistent |
| **Shadows** |
| `shadowColor` | `Color?` | ✅ `layer.shadowColor` | ✅ Stored as tag, used in elevation calc | ⚠️ Android uses elevation approximation |
| `shadowOpacity` | `double?` | ✅ `layer.shadowOpacity` | ✅ Used in elevation calculation | ⚠️ Android uses elevation approximation |
| `shadowRadius` | `dynamic` | ✅ `layer.shadowRadius` | ✅ Used in elevation calculation | ⚠️ Android uses elevation approximation |
| `shadowOffsetX` | `dynamic` | ✅ `layer.shadowOffset.width` | ✅ Stored as tag (not used in elevation) | ⚠️ Android elevation doesn't support offset |
| `shadowOffsetY` | `dynamic` | ✅ `layer.shadowOffset.height` | ✅ Stored as tag (not used in elevation) | ⚠️ Android elevation doesn't support offset |
| `elevation` | `dynamic` | ✅ Converts to shadow props | ✅ `view.elevation` | ✅ Consistent |
| **Hit Slop** |
| `hitSlop` | `DCFHitSlop?` | ✅ Stored as `UIEdgeInsets` | ✅ Stored as tags | ✅ Consistent |
| **Transforms** |
| `rotateInDegrees` | N/A (not in StyleSheet) | ✅ `CATransform3DRotate` | ✅ `view.rotation` | ✅ Consistent |
| `translateX` | N/A (not in StyleSheet) | ✅ `CATransform3DTranslate` | ✅ `view.translationX` | ✅ Consistent |
| `translateY` | N/A (not in StyleSheet) | ✅ `CATransform3DTranslate` | ✅ `view.translationY` | ✅ Consistent |
| `scale` | N/A (not in StyleSheet) | ✅ `CATransform3DScale` | ✅ `view.scaleX/Y` | ✅ Consistent |
| `scaleX` | N/A (not in StyleSheet) | ✅ `CATransform3DScale` | ✅ `view.scaleX` | ✅ Consistent |
| `scaleY` | N/A (not in StyleSheet) | ✅ `CATransform3DScale` | ✅ `view.scaleY` | ✅ Consistent |
| **Accessibility** |
| `accessible` | `bool?` | ✅ `isAccessibilityElement` | ✅ `importantForAccessibility` | ✅ Consistent |
| `accessibilityLabel` | `String?` | ✅ `accessibilityLabel` | ✅ `contentDescription` | ✅ Consistent |
| `ariaLabel` | `String?` | ✅ Falls back to `accessibilityLabel` | ✅ Falls back to `contentDescription` | ✅ Consistent |
| `accessibilityHint` | `String?` | ✅ `accessibilityHint` | ✅ `AccessibilityDelegate.hintText` | ✅ Consistent |
| `accessibilityValue` | `dynamic` | ✅ `accessibilityValue` (String or Dict) | ✅ `AccessibilityDelegate.text` | ✅ Consistent |
| `accessibilityRole` | `String?` | ✅ `accessibilityTraits` | ✅ `AccessibilityDelegate` + `isClickable` | ✅ Consistent |
| `accessibilityState` | `Map?` | ✅ `accessibilityTraits` | ✅ `AccessibilityDelegate` | ✅ Consistent |
| `accessibilityElementsHidden` | `bool?` | ✅ `accessibilityElementsHidden` | ✅ `importantForAccessibility` (mapped) | ✅ Consistent |
| `ariaHidden` | `bool?` | ✅ Falls back to `accessibilityElementsHidden` | ✅ Falls back to `importantForAccessibility` | ✅ Consistent |
| `accessibilityLanguage` | `String?` | ✅ `accessibilityLanguage` (iOS 13+) | ✅ Stored as tag (Android doesn't support) | ✅ Consistent |
| `accessibilityIgnoresInvertColors` | `bool?` | ✅ `accessibilityIgnoresInvertColors` (iOS 11+) | ✅ Stored as tag (Android doesn't support) | ✅ Consistent |
| `accessibilityViewIsModal` | `bool?` | ✅ `accessibilityViewIsModal` | ✅ `importantForAccessibility` (mapped) | ✅ Consistent |
| `ariaModal` | `bool?` | ✅ Falls back to `accessibilityViewIsModal` | ✅ Falls back to `importantForAccessibility` | ✅ Consistent |
| `accessibilityLiveRegion` | `String?` | ✅ Stored as tag (iOS doesn't support) | ✅ `accessibilityLiveRegion` | ✅ Consistent |
| `ariaLive` | `String?` | ✅ Falls back to stored tag | ✅ Falls back to `accessibilityLiveRegion` | ✅ Consistent |
| `importantForAccessibility` | `String?` | ✅ Stored as tag (iOS doesn't support) | ✅ `importantForAccessibility` | ✅ Consistent |
| **Other** |
| `testID` | `String?` | ✅ `accessibilityIdentifier` | ✅ Stored as tag | ✅ Consistent |
| `pointerEvents` | `String?` | ✅ `isUserInteractionEnabled` | ✅ `isClickable` + `isFocusable` | ✅ Consistent |

## Issues Found & Fixed

### ✅ 1. **Missing Accessibility Properties - FIXED**
- **Android**: Now handles `accessibilityElementsHidden`, `ariaHidden`, `accessibilityLanguage`, `accessibilityIgnoresInvertColors`, `accessibilityViewIsModal`, `ariaModal`
- **iOS**: Now handles `accessibilityLiveRegion`, `ariaLive`, `importantForAccessibility` (stored for reference)
- **Status**: ✅ **FIXED** - All accessibility properties now handled on both platforms

### ⚠️ 2. **Shadow Offset Not Applied on Android**
- **Issue**: Android stores `shadowOffsetX/Y` as tags but doesn't use them in elevation calculation
- **Impact**: Shadows on Android won't match iOS offset exactly (elevation doesn't support custom offsets)
- **Current Solution**: Using calculated elevation that approximates iOS shadow appearance
- **Future Improvement**: Could implement custom shadow rendering for exact offset matching

### ⚠️ 3. **Background Gradient - Partial Consistency**
- **iOS**: Uses `CAGradientLayer` with arbitrary `startPoint`/`endPoint` for linear gradients
- **Android**: Uses `GradientDrawable` with predefined orientations (TOP_BOTTOM, LEFT_RIGHT, etc.)
- **Impact**: Complex linear gradients with custom angles may render differently
- **Status**: Works for common cases (vertical, horizontal), but custom angles may differ

### ✅ 4. **Corner Radius Density Scaling**
- iOS: Uses logical points (auto-scaled by system)
- Android: Applies density scaling manually
- **Status**: ✅ **CORRECT** - Both achieve same visual result

### ✅ 5. **All Other Properties**
- Borders: ✅ Consistent (individual borders work on both)
- Transforms: ✅ Consistent (rotation, translation, scale)
- Opacity: ✅ Consistent
- Hit Slop: ✅ Consistent
- Pointer Events: ✅ Consistent
- Test ID: ✅ Consistent

## Summary

**Total Properties Checked**: 40+
**Fully Consistent**: 35+
**Platform-Specific (stored for reference)**: 5
**Needs Improvement**: 2 (shadow offset, complex gradients)

## Recommendations

1. ✅ **Accessibility properties** - All now handled
2. ⚠️ **Shadow offset** - Current elevation approximation works for most cases, custom rendering for exact match if needed
3. ⚠️ **Complex gradients** - Works for common cases, may need enhancement for arbitrary angles

