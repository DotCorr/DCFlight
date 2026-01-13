# How System Changes Work - Complete Flow

## 🎯 The Problem We're Solving

When you change your phone's font size in Settings, the app needs to update all text to reflect the new size. But in DCFlight's signal-inspired reconciliation model, components only update when **props change**. Since font scale is handled natively (iOS multiplies, Android uses SP), the Dart props don't change, so reconciliation skips the update.

## 🔄 The Complete Flow (Step-by-Step)

### Step 1: User Changes Font Size
```
User goes to Settings → Display → Font Size → Adjusts slider
    ↓
Native OS detects font scale change
    ↓
Native calls Flutter method channel: "onDimensionChange"
```

### Step 2: ScreenUtilities Detects Change
```dart
// In ScreenUtilities._handleMethodCall()
final oldFontScale = _fontScale;  // e.g., 1.0
final newFontScale = args['fontScale'] as double;  // e.g., 1.235

if (oldFontScale != newFontScale) {
  _fontScale = newFontScale;
  
  // 🔥 KEY MOMENT: Notify SystemStateManager
  SystemStateManager.onSystemChange(fontScale: true);
  // This increments _version: 0 → 1 → 2 → 3...
  
  // Also notify dimension change listeners
  _notifyDimensionChangeListeners();
}
```

**What happens:**
- `SystemStateManager._version` increments: `4 → 5`
- Logs: `🔄 SystemStateManager: System change detected (version: 5) - fontScale`

### Step 3: CoreWrapper Detects Version Change
```dart
// In CoreWrapper.render() - useEffect hook
subscription = ScreenUtilities.instance.dimensionChanges.listen((_) {
  final currentVersion = SystemStateManager.version;  // Now = 5
  if (currentVersion != _previousSystemVersion) {  // 5 != 4
    print('🔄 CoreWrapper: System state version changed: 4 → 5');
    _previousSystemVersion = currentVersion;  // Update to 5
    scheduleUpdate();  // 🔥 Triggers CoreWrapper re-render!
  }
});
```

**What happens:**
- `CoreWrapper` detects version changed: `4 → 5`
- Calls `scheduleUpdate()` which triggers a re-render of `CoreWrapper`
- This causes the entire app tree to re-render (because `CoreWrapper` wraps the root)

### Step 4: Components Re-render with New Version
```dart
// In DCFText.render()
@override
DCFComponentNode render() {
  Map<String, dynamic> props = {
    'content': 'Hello World',
    'fontSize': 17,
    // 🔥 KEY: Include current system version
    '_systemVersion': SystemStateManager.version,  // Now = 5 (was 4)
  };
  
  return DCFElement(
    type: 'Text',
    elementProps: props,
  );
}
```

**What happens:**
- Every `DCFText` component calls `render()` again
- New props include `_systemVersion: 5` (was `4` in previous render)
- New `DCFElement` instances are created with updated props

### Step 5: Reconciliation Detects Prop Change
```dart
// In engine._reconcileElement()
final changedProps = _diffProps(
  oldElement.type,
  oldElement.elementProps,  // { fontSize: 17, _systemVersion: 4, ... }
  newElement.elementProps   // { fontSize: 17, _systemVersion: 5, ... }
);

// _diffProps compares:
// Old: _systemVersion = 4
// New: _systemVersion = 5
// Result: { '_systemVersion': 5 }  ← Change detected!
```

**What happens:**
- Reconciliation compares old props vs new props
- Detects `_systemVersion` changed: `4 → 5`
- Creates `changedProps` map: `{ '_systemVersion': 5 }`
- Logs: `✅ _systemVersion changed - should trigger update!`

### Step 6: Update Sent to Native
```dart
// In engine._reconcileElement()
if (propsToSend.isNotEmpty) {  // { '_systemVersion': 5 }
  await _nativeBridge.updateView(
    oldElement.nativeViewId!,  // e.g., viewId = 10
    propsToSend                 // { '_systemVersion': 5 }
  );
}
```

**What happens:**
- Dart sends update to native: `updateView(viewId: 10, props: { '_systemVersion': 5 })`
- Native receives the update

### Step 7: Native Detects System Version Change
```kotlin
// In DCFTextComponent.updateView() (Android)
val oldSystemVersion = existingProps["_systemVersion"] as? Number  // 4
val newSystemVersion = mergedProps["_systemVersion"] as? Number    // 5
val systemVersionChanged = oldSystemVersion != newSystemVersion     // true!

if (systemVersionChanged) {
  Log.d(TAG, "🔄 System version changed: 4 → 5 - forcing re-measurement")
  // Force layout recalculation
  textView.requestLayout()
  textView.invalidate()
}
```

**What happens (Android):**
- Native detects `_systemVersion` changed: `4 → 5`
- Calls `requestLayout()` to force Yoga to recalculate layout
- Calls `invalidate()` to force redraw
- Text is re-measured with new font scale (SP units automatically scale)

**What happens (iOS):**
```swift
// In DCFTextComponent.updateView() (iOS)
if systemVersionChanged {
  // Mark shadow view as dirty
  shadowView.dirtyText()  // Clears cache, marks Yoga node dirty
  textView.setNeedsLayout()
  textView.setNeedsDisplay()
  DCFLayoutManager.shared.triggerLayoutCalculation()
}
```

### Step 8: Text Re-measured with New Font Scale
```kotlin
// In DCFTextComponent.updateTextView() (Android)
// Font size is converted using SP (scaled pixels)
val fontSizePixels = TypedValue.applyDimension(
    TypedValue.COMPLEX_UNIT_SP,  // ← SP automatically scales with system font size!
    fontSizeLogicalPoints,        // e.g., 17
    displayMetrics
)
// If system font scale = 1.235, then:
// fontSizePixels = 17 * 1.235 = 20.995px (larger!)
```

**What happens:**
- Text layout is recreated with new pixel size
- SP units automatically account for system font scale
- Text appears larger/smaller based on user's font size setting

### Step 9: UI Updates
```
Native view invalidated
    ↓
onDraw() called with new layout
    ↓
Text rendered at new size
    ↓
User sees updated text! 🎉
```

## 🎨 Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  USER ACTION: Changes font size in Settings                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Native OS → Flutter Method Channel                         │
│  "onDimensionChange" with new fontScale                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  ScreenUtilities._handleMethodCall()                        │
│  SystemStateManager.onSystemChange(fontScale: true)         │
│  _version: 4 → 5                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  dimensionChanges stream fires                              │
│  CoreWrapper detects version changed: 4 → 5                 │
│  scheduleUpdate() → Triggers re-render                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  All components re-render                                    │
│  DCFText.render() includes _systemVersion: 5                │
│  (Previous render had _systemVersion: 4)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Reconciliation: _diffProps()                               │
│  Detects: { '_systemVersion': 5 } changed                   │
│  Sends updateView(viewId, { '_systemVersion': 5 })          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Native: DCFTextComponent.updateView()                      │
│  Detects _systemVersion changed: 4 → 5                      │
│  Forces re-measurement: requestLayout() + invalidate()      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Text re-measured with new font scale                       │
│  SP units automatically scale (17 * 1.235 = 20.995px)       │
│  Layout recalculated, view invalidated                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  UI UPDATES: Text appears at new size! 🎉                  │
└─────────────────────────────────────────────────────────────┘
```

## 🔑 Key Components

### 1. SystemStateManager
- **Purpose**: Global version counter for system changes
- **When it increments**: When `onSystemChange()` is called
- **Who calls it**: `ScreenUtilities` when font scale changes
- **Why it exists**: To signal that system state changed, even if props didn't

### 2. CoreWrapper
- **Purpose**: Triggers re-renders when system state changes
- **How it works**: Listens to `dimensionChanges`, checks if `SystemStateManager.version` changed
- **Why it exists**: Components need to re-render to include new `_systemVersion` in props
- **Without it**: Components wouldn't re-render, so `_systemVersion` wouldn't update

### 3. _systemVersion Prop
- **Purpose**: Include system version in component props
- **Where**: In `DCFText.render()` (and other system-dependent components)
- **Why it exists**: Reconciliation detects prop changes, so we need a prop that changes
- **How it works**: When version increments, prop changes, reconciliation detects it

### 4. Native Detection
- **Purpose**: Force re-measurement when `_systemVersion` changes
- **Where**: In `DCFTextComponent.updateView()` (Android & iOS)
- **Why it exists**: Native needs to know to re-measure text with new font scale
- **How it works**: Detects `_systemVersion` prop changed, forces layout recalculation

## 💡 Why This Design?

### Signal-Inspired Reconciliation
DCFlight uses signal-inspired reconciliation, which means:
- ✅ Only updates when props actually change
- ✅ Very efficient (no unnecessary updates)
- ❌ But skips updates when props don't change (even if system state did)

### The Solution
We trick reconciliation into detecting changes by:
1. Including `_systemVersion` in props (a prop that changes when system state changes)
2. Reconciliation detects prop change → sends update to native
3. Native detects `_systemVersion` change → forces re-measurement

### Why Not Just Force Re-render Everything?
- ❌ Too expensive (re-renders entire tree)
- ❌ Not aligned with signal-based model
- ✅ Our solution: Only components with `_systemVersion` are affected

## 🚀 Future Extensions

This same mechanism works for:
- **Language changes**: `SystemStateManager.onSystemChange(language: true)`
- **Theme changes**: `SystemStateManager.onSystemChange(theme: true)`
- **Accessibility**: `SystemStateManager.onSystemChange(accessibility: true)`

Just include `_systemVersion` in props and the same flow applies!

## 📝 Summary

1. **User changes font size** → Native notifies Flutter
2. **ScreenUtilities** → Calls `SystemStateManager.onSystemChange()` → Version increments
3. **CoreWrapper** → Detects version change → Triggers re-render
4. **Components re-render** → Include new `_systemVersion` in props
5. **Reconciliation** → Detects prop change → Sends update to native
6. **Native** → Detects `_systemVersion` change → Forces re-measurement
7. **Text re-measured** → With new font scale → UI updates! 🎉

The magic is in the **version counter** (`SystemStateManager`) that increments on system changes, which causes props to change, which triggers reconciliation, which updates native, which re-measures text!


