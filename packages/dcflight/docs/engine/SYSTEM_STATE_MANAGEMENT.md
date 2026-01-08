# System State Management

## Overview

DCFlight's **SystemStateManager** enables components to automatically update when system-level settings change (font scale, language, theme, accessibility, etc.) even when component props don't change. This works seamlessly with DCFlight's signal-inspired reconciliation model.

## Table of Contents

1. [The Problem](#the-problem)
2. [The Solution](#the-solution)
3. [How It Works](#how-it-works)
4. [Usage Guide](#usage-guide)
5. [Examples](#examples)
6. [Best Practices](#best-practices)

---

## The Problem

In DCFlight's signal-inspired reconciliation model, components only update when their **props actually change**. This is efficient, but creates a problem for system-level changes:

**Example: Font Scale Change**
```
User changes system font size: 0.882 → 1.0
    ↓
Component re-renders
    ↓
Props comparison:
  Old: { fontSize: 17, content: "Hello" }
  New: { fontSize: 17, content: "Hello" }
    ↓
No prop changes detected ❌
    ↓
Native update skipped (0 operations)
    ↓
Text doesn't reflect new font scale 😞
```

The font scale is handled natively (iOS multiplies, Android uses SP), so Dart props don't change, but native needs to re-measure/re-render.

---

## The Solution

**SystemStateManager** provides a global version counter that increments on system changes. Components include this version in their props, causing reconciliation to detect changes even when other props are identical.

```
Font Scale Changes
    ↓
SystemStateManager.onSystemChange(fontScale: true)
    ↓
_version increments: 0 → 1
    ↓
Component includes _systemVersion: 1 in props
    ↓
Reconciliation detects:
  Old: { fontSize: 17, _systemVersion: 0 }
  New: { fontSize: 17, _systemVersion: 1 }
    ↓
Prop change detected ✅
    ↓
Native update triggered 🎉
```

---

## How It Works

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              System Change Detected                          │
│  (Font scale, language, theme, accessibility, etc.)        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         SystemStateManager.onSystemChange()                 │
│                                                             │
│  _version++ (e.g., 0 → 1)                                   │
│  Logs change type for debugging                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Component Re-render Triggered                       │
│  (via CoreWrapper, state update, etc.)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Component.render()                                  │
│                                                             │
│  props = {                                                  │
│    ...otherProps,                                           │
│    '_systemVersion': SystemStateManager.version  ← Includes │
│  }                                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Reconciliation                                      │
│                                                             │
│  _diffProps(oldProps, newProps)                             │
│    Old: { fontSize: 17, _systemVersion: 0 }                │
│    New: { fontSize: 17, _systemVersion: 1 }                │
│                                                             │
│  Result: { '_systemVersion': 1 }  ← Change detected!      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Native Update                                       │
│                                                             │
│  updateView(viewId, { '_systemVersion': 1 })               │
│    ↓                                                        │
│  Native re-measures/re-renders with new system settings    │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Guide

### For Component Developers

#### Step 1: Include System Version in Props

If your component depends on system settings, include `_systemVersion` in its props:

```dart
class MyTextComponent extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      'content': 'Hello World',
      'fontSize': 17,
      // Include system version to trigger updates on system changes
      '_systemVersion': SystemStateManager.version,
    };
    
    return DCFElement(
      type: 'Text',
      elementProps: props,
    );
  }
}
```

#### Step 2: Component Automatically Updates

When any system change occurs:
- `SystemStateManager.version` increments
- Your component's `_systemVersion` prop changes
- Reconciliation detects the change
- Native update is triggered automatically

**No additional code needed!** The component will automatically update when system settings change.

---

### For Framework Developers

#### Notifying System Changes

When you detect a system-level change, call `SystemStateManager.onSystemChange()`:

```dart
// Font scale changed
SystemStateManager.onSystemChange(fontScale: true);

// Language changed
SystemStateManager.onSystemChange(language: true);

// Theme changed (dark/light mode)
SystemStateManager.onSystemChange(theme: true);

// Accessibility settings changed
SystemStateManager.onSystemChange(accessibility: true);

// Multiple changes at once
SystemStateManager.onSystemChange(
  fontScale: true,
  language: true,
);
```

#### Current Integration Points

**Font Scale Changes:**
- `ScreenUtilities._handleMethodCall()` automatically calls `SystemStateManager.onSystemChange(fontScale: true)` when font scale changes

**Future Integration Points:**
- Language changes: Call in localization handler
- Theme changes: Call in theme change listener
- Accessibility: Call in accessibility settings listener

---

## Examples

### Example 1: Text Component (Already Implemented)

```dart
class DCFText extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      'content': content,
      ...textProps.toMap(),
      // System version ensures text updates when font scale changes
      '_systemVersion': SystemStateManager.version,
    };
    
    return DCFElement(
      type: 'Text',
      elementProps: props,
    );
  }
}
```

**Result:** Text automatically updates when user changes system font size.

---

### Example 2: Custom Component with System Dependencies

```dart
class LocalizedButton extends DCFStatelessComponent {
  final String textKey;
  
  LocalizedButton({required this.textKey, super.key});
  
  @override
  DCFComponentNode render() {
    // Get localized text (depends on system language)
    final localizedText = Localizations.of(context).translate(textKey);
    
    Map<String, dynamic> props = {
      'title': localizedText,
      // Include system version to update when language changes
      '_systemVersion': SystemStateManager.version,
    };
    
    return DCFElement(
      type: 'Button',
      elementProps: props,
    );
  }
}
```

**Integration:**
```dart
// In your language change handler
void onLanguageChanged() {
  SystemStateManager.onSystemChange(language: true);
  // Component will automatically re-render and update
}
```

---

### Example 3: Theme-Aware Component

```dart
class ThemedView extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Map<String, dynamic> props = {
      'backgroundColor': isDark ? '#000000' : '#FFFFFF',
      // Include system version to update when theme changes
      '_systemVersion': SystemStateManager.version,
    };
    
    return DCFElement(
      type: 'View',
      elementProps: props,
    );
  }
}
```

**Integration:**
```dart
// In your theme change handler
void onThemeChanged() {
  SystemStateManager.onSystemChange(theme: true);
  // Component will automatically update colors
}
```

---

### Example 4: Accessibility-Aware Component

```dart
class AccessibleText extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final highContrast = MediaQuery.of(context).highContrast;
    
    Map<String, dynamic> props = {
      'content': content,
      'fontSize': highContrast ? fontSize * 1.2 : fontSize,
      'animate': !reducedMotion,
      // Include system version to update when accessibility settings change
      '_systemVersion': SystemStateManager.version,
    };
    
    return DCFElement(
      type: 'Text',
      elementProps: props,
    );
  }
}
```

**Integration:**
```dart
// In your accessibility settings handler
void onAccessibilityChanged() {
  SystemStateManager.onSystemChange(accessibility: true);
  // Component will automatically adjust for accessibility
}
```

---

## Best Practices

### ✅ DO

1. **Include `_systemVersion` in props** for components that depend on system settings
   ```dart
   '_systemVersion': SystemStateManager.version,
   ```

2. **Call `onSystemChange()` immediately** when system change is detected
   ```dart
   SystemStateManager.onSystemChange(fontScale: true);
   ```

3. **Specify change types** for better debugging
   ```dart
   SystemStateManager.onSystemChange(
     fontScale: true,
     language: false,
     theme: false,
   );
   ```

4. **Use for system-dependent components**:
   - Text (font scale)
   - Localized components (language)
   - Themed components (theme)
   - Accessible components (accessibility settings)

### ❌ DON'T

1. **Don't include `_systemVersion`** in components that don't depend on system settings
   - Unnecessary prop = unnecessary updates

2. **Don't manually increment version**
   - Always use `onSystemChange()` to ensure proper logging and consistency

3. **Don't use for user state changes**
   - `_systemVersion` is for **system-level** changes only
   - Use regular state management for user interactions

4. **Don't forget to trigger re-render**
   - `onSystemChange()` increments version, but you still need to trigger component re-render (via `CoreWrapper`, state update, etc.)

---

## Performance Considerations

### Overhead

**Minimal:**
- 1 integer prop per component (`_systemVersion`)
- O(1) version increment
- Prop diffing already runs (no extra cost)

**Efficient:**
- Only components with `_systemVersion` in props are affected
- Reconciliation only sends changed prop (`_systemVersion`) to native
- Native layer handles re-measurement efficiently

### Optimization Tips

1. **Selective Inclusion**: Only include `_systemVersion` in components that actually need system updates
   ```dart
   // ✅ Good: Text needs font scale updates
   '_systemVersion': SystemStateManager.version,
   
   // ❌ Bad: Static image doesn't need system updates
   // Don't include _systemVersion
   ```

2. **Batch System Changes**: If multiple system changes occur simultaneously, call once:
   ```dart
   // ✅ Good: Single call
   SystemStateManager.onSystemChange(
     fontScale: true,
     language: true,
   );
   
   // ❌ Bad: Multiple calls
   SystemStateManager.onSystemChange(fontScale: true);
   SystemStateManager.onSystemChange(language: true);
   ```

---

## API Reference

### SystemStateManager

#### `static int get version`
Returns the current system state version. Components should include this in props.

#### `static void onSystemChange({...})`
Notifies that a system change occurred. Increments the global version counter.

**Parameters:**
- `fontScale` (bool): Set to `true` if font scale changed
- `language` (bool): Set to `true` if language/locale changed
- `theme` (bool): Set to `true` if theme/brightness changed
- `accessibility` (bool): Set to `true` if accessibility settings changed

**Example:**
```dart
SystemStateManager.onSystemChange(fontScale: true);
```

#### `static void reset()`
Resets the version counter to 0. Useful for testing or hot restart.

---

## Troubleshooting

### Component Not Updating on System Change

**Problem:** Component includes `_systemVersion` but doesn't update when system changes.

**Solutions:**
1. Verify `onSystemChange()` is being called:
   ```dart
   SystemStateManager.onSystemChange(fontScale: true);
   // Check logs: "🔄 SystemStateManager: System change detected..."
   ```

2. Verify component re-renders:
   - Check if `CoreWrapper` or state update triggers re-render
   - `_systemVersion` only works if component re-renders

3. Verify prop is included:
   ```dart
   '_systemVersion': SystemStateManager.version, // Must be in props
   ```

### Too Many Updates

**Problem:** All components update even when only one system setting changes.

**Solution:** Only include `_systemVersion` in components that actually need that specific system update:
- Font scale → Text components only
- Language → Localized components only
- Theme → Themed components only

---

## Summary

**SystemStateManager** enables efficient, automatic updates for system-dependent components:

1. **Include `_systemVersion`** in component props
2. **Call `onSystemChange()`** when system changes detected
3. **Component automatically updates** via signal-inspired reconciliation
4. **Minimal overhead** - just 1 integer prop per component

This works seamlessly with DCFlight's signal-inspired reconciliation model, ensuring components update when system settings change while maintaining optimal performance.

