# Component Conventions & Requirements

## Critical Requirements for All Components

All components MUST follow these conventions to work correctly with the framework.

---

## 1. Semantic Colors (MUST Support)

**CRITICAL:** All components MUST support semantic colors for theme consistency.

### Required Semantic Colors

1. **`primaryColor`** - Primary text/action color
2. **`secondaryColor`** - Secondary text/placeholder color
3. **`tertiaryColor`** - Tertiary text/hint color
4. **`accentColor`** - Accent/highlight color

### Why This Is Required

- **StyleSheet always provides them** - `StyleSheet.toMap()` always includes semantic colors
- **Theme support** - Colors change when theme toggles
- **Framework optimization** - `onlySemanticColorsChanged()` detects theme changes
- **Cross-platform consistency** - Same colors on iOS and Android

### Implementation Pattern

**iOS:**
```swift
// In createView and updateView
if let primaryColor = props["primaryColor"] as? String {
    if let color = ColorUtilities.color(fromHexString: primaryColor) {
        // Apply color
        button.setTitleColor(color, for: .normal)
    }
    // NO FALLBACK - StyleSheet always provides colors
}
```

**Android:**
```kotlin
// In createView and updateView
// Framework automatically merges props - use mergedProps
val existingProps = getStoredProps(view)
val mergedProps = mergeProps(existingProps, props)
storeProps(view, mergedProps)

mergedProps["primaryColor"]?.let { color ->
    val colorInt = ColorUtilities.parseColor(color.toString())
    if (colorInt != null) {
        // Apply color
        button.setTextColor(colorInt)
    }
    // NO FALLBACK - StyleSheet always provides colors
}
```

### What Happens If You Don't Support Semantic Colors?

**❌ Problem:**
- Component won't respond to theme changes
- Colors will be inconsistent
- Framework optimization won't work
- Cross-platform inconsistency

**Example of broken component:**
```swift
// ❌ BAD - No semantic color support
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    button.setTitleColor(.black, for: .normal)  // Hardcoded color!
    return button
}
```

**✅ GOOD - Supports semantic colors:**
```swift
// ✅ GOOD - Supports semantic colors
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    if let primaryColor = props["primaryColor"] as? String {
        if let color = ColorUtilities.color(fromHexString: primaryColor) {
            button.setTitleColor(color, for: .normal)
        }
    }
    return button
}
```

---

## 2. Component Protocol Compliance

### iOS: All Methods Required

```swift
public protocol DCFComponent {
    init()                                    // ✅ Required
    func createView(props: [String: Any]) -> UIView  // ✅ Required
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool  // ✅ Required
    func applyLayout(_ view: UIView, layout: YGNodeLayout)  // ✅ Required
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String)  // ✅ Required
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any?  // ✅ Required
}
```

**Key Changes:**
- ✅ `getIntrinsicSize` removed - Components set `intrinsicContentSize` on shadow view if needed
- ✅ `viewRegisteredWithShadowTree` now receives `shadowView` parameter

**Missing any method = Component won't work!**

### Android: All Methods Required

```kotlin
abstract class DCFComponent {
    abstract fun createView(context: Context, props: Map<String, Any?>): View  // ✅ Required
    open fun updateView(view: View, props: Map<String, Any?>): Boolean  // ✅ Override this - framework handles prop merging
    abstract fun viewRegisteredWithShadowTree(view: View, nodeId: String)  // ✅ Required
    abstract fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any?  // ✅ Required
}
```

**Key Changes:**
- ✅ `updateView` is now `open` (override it directly)
- ✅ **No `updateViewInternal`** - Removed, use `updateView` instead
- ✅ **No `getIntrinsicSize`** - Removed, Android handles intrinsic size internally
- ✅ **Automatic prop merging** - Framework merges new props with existing stored props
- ✅ **All properties preserved** - Text alignment, font size, colors automatically preserved

**Missing any method = Component won't compile!**

---

## 3. Component Registration

### Must Register Component

**iOS:**
```swift
// In plugin registration
DCFComponentRegistry.shared.registerComponent("MyComponent", componentClass: DCFMyComponent.self)
```

**Android:**
```kotlin
// In plugin registration
DCFComponentRegistry.shared.registerComponent("MyComponent", DCFMyComponent::class.java)
```

**Component name MUST match exactly on both platforms!**

### Registration Checklist

- ✅ Component registered in plugin initialization
- ✅ Component name matches on iOS and Android
- ✅ Component name matches Dart component name
- ✅ Component registered before first use

---

## 4. Event Naming Conventions

### Standard Event Names

Use standard event names for consistency:

**Touch Events:**
- `onPress` - Single tap
- `onLongPress` - Long press
- `onPressIn` - Touch down
- `onPressOut` - Touch up

**Value Change:**
- `onValueChange` - Value changed
- `onSelectionChange` - Selection changed

**Text Input:**
- `onChangeText` - Text changed
- `onSubmit` - Text submitted

### Event Name Rules

- ✅ Start with `on` (e.g., `onPress`)
- ✅ Use PascalCase after `on` (e.g., `onValueChange`)
- ✅ Match Dart handler names exactly
- ❌ Don't use platform-specific names (e.g., `onTouchUpInside`)

---

## 5. Props Naming Conventions

### Standard Prop Names

**Colors:**
- `primaryColor`, `secondaryColor`, `tertiaryColor`, `accentColor` (semantic)
- `backgroundColor` (explicit)

**Text:**
- `title` - Button title
- `content` - Text content
- `placeholder` - Placeholder text

**State:**
- `value` - Current value (Slider, Toggle)
- `selectedIndex` - Selected index (SegmentedControl)
- `checked` - Checked state (Checkbox)

**Layout:**
- `width`, `height` - Explicit dimensions
- `margin*`, `padding*` - Spacing

### Prop Name Rules

- ✅ Use camelCase (e.g., `selectedIndex`)
- ✅ Match Dart prop names exactly
- ✅ Use semantic names (e.g., `value` not `currentValue`)
- ❌ Don't use platform-specific names (e.g., `text` on iOS, `title` on Android)

---

## 6. State Preservation

### iOS: Natural (No Action Needed)

iOS UIKit naturally preserves state:
```swift
// UISlider.value is automatically preserved
// UISegmentedControl.selectedSegmentIndex is automatically preserved
// No framework intervention needed
```

### Android: Automatic Prop Merging

**Framework automatically merges props - no glue code needed:**

```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val seekBar = view as? SeekBar ?: return false
    
    // ✅ Framework automatically merges props with existing stored props
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
    
    // ✅ All properties are preserved automatically - just update directly
    mergedProps["value"]?.let {
        val value = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        seekBar.progress = (value * 100).toInt()
    }
    
    // ✅ Update semantic colors (MUST support)
    ColorUtilities.getColor("minimumTrackColor", "primaryColor", nonNullProps)?.let { colorInt ->
        seekBar.progressTintList = ColorStateList.valueOf(colorInt)
    }
    
    // ✅ Apply styles
    seekBar.applyStyles(nonNullProps)
    
    return true
}
```

**Key Benefits:**
- ✅ **No glue code** - No `hasPropChanged()` or `updateViewInternal`
- ✅ **All properties preserved** - Text alignment, font size, colors automatically preserved
- ✅ **Simpler code** - Just update properties directly
- ✅ **Framework-level fix** - Works automatically for all components

---

## 7. Error Handling

### Graceful Degradation

**✅ Good:**
```swift
if let primaryColor = props["primaryColor"] as? String {
    if let color = ColorUtilities.color(fromHexString: primaryColor) {
        button.setTitleColor(color, for: .normal)
    }
    // If color parsing fails, just don't set color (graceful)
}
```

**❌ Bad:**
```swift
let color = ColorUtilities.color(fromHexString: props["primaryColor"] as! String)!
button.setTitleColor(color, for: .normal)
// Crashes if primaryColor is missing or invalid!
```

### Return Values

**iOS:**
```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let button = view as? UIButton else { return false }  // ✅ Return false if wrong type
    // ... update logic
    return true  // ✅ Return true if updated
}
```

**Android:**
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val button = view as? Button ?: return false  // ✅ Return false if wrong type
    
    // Framework automatically merges props
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    // ... update logic with mergedProps
    
    return true  // ✅ Return true if updated
}
```

---

## 8. Component Checklist

Before submitting a component, verify:

### Protocol Compliance
- [ ] All protocol methods implemented
- [ ] `createView` returns correct view type
- [ ] `updateView` handles all props
- [ ] `applyLayout` sets frame/bounds correctly
- [ ] `viewRegisteredWithShadowTree` implemented (can set `intrinsicContentSize` if needed)
- [ ] `handleTunnelMethod` implemented (can return `null`)

### Semantic Colors
- [ ] `primaryColor` supported
- [ ] `secondaryColor` supported
- [ ] `tertiaryColor` supported (if applicable)
- [ ] `accentColor` supported (if applicable)
- [ ] Colors applied in both `createView` and `updateView`
- [ ] No hardcoded colors (use semantic colors)

### Registration
- [ ] Component registered in plugin
- [ ] Component name matches on iOS and Android
- [ ] Component name matches Dart component name

### Events
- [ ] Events use standard names (`onPress`, `onValueChange`, etc.)
- [ ] Events include relevant data
- [ ] `propagateEvent()` called correctly

### State Preservation (Android)
- [ ] Framework automatically merges props - no manual prop comparison needed
- [ ] All properties are preserved automatically (text alignment, font size, colors, etc.)
- [ ] Uses `mergedProps` from framework's automatic merging

### Component References (iOS)
- [ ] Uses strong component references (not weak) for touchable components
- [ ] Stores component instances in `NSMapTable` if needed
- [ ] Restores component reference in `updateView` if lost

### Touch Handling (Android)
- [ ] Makes views `clickable`, `focusable`, and `focusableInTouchMode` if needed
- [ ] Uses `setOnTouchListener` for touch handling with children

### Error Handling
- [ ] Graceful degradation (no crashes)
- [ ] Returns `false` on errors
- [ ] Handles missing/invalid props

---

## Common Mistakes

### 1. Missing Semantic Colors

**❌ Wrong:**
```swift
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    button.setTitleColor(.black, for: .normal)  // Hardcoded!
    return button
}
```

**✅ Correct:**
```swift
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    if let primaryColor = props["primaryColor"] as? String {
        if let color = ColorUtilities.color(fromHexString: primaryColor) {
            button.setTitleColor(color, for: .normal)
        }
    }
    return button
}
```

### 2. Component Name Mismatch

**❌ Wrong:**
```swift
// iOS
DCFComponentRegistry.shared.registerComponent("UIButton", componentClass: DCFButtonComponent.self)
```

```kotlin
// Android
DCFComponentRegistry.shared.registerComponent("Button", DCFButtonComponent::class.java)
```

**✅ Correct:**
```swift
// iOS
DCFComponentRegistry.shared.registerComponent("Button", componentClass: DCFButtonComponent.self)
```

```kotlin
// Android
DCFComponentRegistry.shared.registerComponent("Button", DCFButtonComponent::class.java)
```

### 3. Missing Prop Merging (Android)

**❌ Wrong:**
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val seekBar = view as SeekBar
    // Only uses new props - loses existing properties (text alignment, font size, etc.)
    props["value"]?.let { seekBar.progress = (it as Float * 100).toInt() }
    return true
}
```

**✅ Correct:**
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val seekBar = view as? SeekBar ?: return false
    
    // ✅ Framework automatically merges props with existing stored props
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
    
    // ✅ All properties preserved - update directly
    mergedProps["value"]?.let {
        val value = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        seekBar.progress = (value * 100).toInt()
    }
    
    // ✅ Apply styles (all properties preserved)
    seekBar.applyStyles(nonNullProps)
    
    return true
}
```

---

## Component Reference Patterns

### iOS: Strong Component References

For components that need to maintain references (especially touchable components with children):

```swift
class DCFTouchableOpacityComponent: NSObject, DCFComponent {
    // Store component instances per view
    private static var componentInstances = NSMapTable<UIView, DCFTouchableOpacityComponent>(
        keyOptions: .weakMemory, 
        valueOptions: .strongMemory
    )
    
    func createView(props: [String: Any]) -> UIView {
        let view = TouchableView()
        
        // Create and store component instance
        let componentInstance = DCFTouchableOpacityComponent()
        view.component = componentInstance  // Strong reference, not weak!
        DCFTouchableOpacityComponent.componentInstances.setObject(componentInstance, forKey: view)
        
        return view
    }
}

class TouchableView: UIView {
    var component: DCFTouchableOpacityComponent?  // Strong, not weak!
}
```

**Why:** Weak references can be deallocated, causing touch handlers to fail. Strong references ensure the component persists.

### Android: Touch Event Handling

**Framework automatically handles touch setup!** No manual glue code needed:

```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val frameLayout = FrameLayout(context)
    
    // Framework automatically enables isClickable/isFocusable when event listeners are registered
    // Just set up your touch listener - framework handles the rest!
    
    frameLayout.setOnTouchListener { view, event ->
        // Handle touches
        true
    }
    
    return frameLayout
}
```

**Framework automatically:**
- Enables `isClickable`, `isFocusable`, and `isFocusableInTouchMode` when event listeners are registered
- Skips `opacity` prop for components that manage their own alpha (TouchableOpacity, GestureDetector)
- Handles all Android-specific optimizations uniformly

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - Detailed protocol explanation
- [Registry System](./REGISTRY_SYSTEM.md) - How to register components
- [Event System](./EVENT_SYSTEM.md) - How events work with type-safe callbacks
- [Tunnel System](./TUNNEL_SYSTEM.md) - Direct method calls

