# Component Protocol Guide
## Native Component Implementation (iOS & Android)

This guide explains what each part of the component protocol does and how to implement components correctly.

---

## 🎉 Recent Updates (Android API Stabilization)

**Android components are now 100% stable with automatic prop merging!**

### What Changed:
- ✅ **`updateView` is now `open`** - Override it directly (no more `updateViewInternal`)
- ✅ **Automatic prop merging** - Framework automatically merges new props with existing stored props
- ✅ **No glue code needed** - Removed `hasPropChanged()`, `updateViewInternal`, and all prop comparison logic
- ✅ **All properties preserved** - Text alignment, font size, colors, etc. are automatically preserved during state updates
- ✅ **Framework-level fix** - Works automatically for all components, no component-specific code needed

### Before (Old API):
```kotlin
override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
    if (hasPropChanged("title", existingProps, props)) {
        // Update title
    }
    // Manual prop comparison everywhere...
}
```

### After (New API):
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    // All properties preserved automatically - just update directly!
    mergedProps["title"]?.let { button.text = it.toString() }
    return true
}
```

**Result:** Simpler, more reliable, and consistent across all components! 🚀

---

## Component Protocol Overview

All components must implement the component protocol. The protocol differs slightly between iOS and Android due to platform architecture differences.

### iOS: Protocol-Based (Natural Architecture)

```swift
public protocol DCFComponent {
    init()
    func createView(props: [String: Any]) -> UIView
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool
    func applyLayout(_ view: UIView, layout: YGNodeLayout)
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String)
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any?
}
```

### Android: Abstract Class (Framework-Enforced)

```kotlin
abstract class DCFComponent {
    abstract fun createView(context: Context, props: Map<String, Any?>): View
    open fun updateView(view: View, props: Map<String, Any?>): Boolean  // Override this - framework handles prop merging automatically
    abstract fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF
    abstract fun viewRegisteredWithShadowTree(view: View, nodeId: String)
    abstract fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any?
}
```

**Key Changes:**
- ✅ `updateView` is now `open` (override it directly)
- ✅ **Automatic prop merging** - Framework merges new props with existing stored props
- ✅ **No glue code needed** - No `hasPropChanged()` or `updateViewInternal`
- ✅ **All properties preserved** - Text alignment, font size, colors, etc. are automatically preserved

---

## Protocol Methods Explained

### 1. `createView` - Create Native View

**Purpose:** Create a new native view instance with initial props.

**When called:**
- First time a component is rendered
- When component type changes (e.g., View → ScrollView)

**iOS:**
```swift
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    
    // Apply initial props
    if let title = props["title"] as? String {
        button.setTitle(title, for: .normal)
    }
    
    // Apply semantic colors (MUST support)
    if let primaryColor = props["primaryColor"] as? String {
        if let color = ColorUtilities.color(fromHexString: primaryColor) {
            button.setTitleColor(color, for: .normal)
        }
    }
    
    // Store props for merging (optional but recommended)
    storeProps(props.mapValues { $0 as Any? }, in: button)
    
    return button
}
```

**Android:**
```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val button = Button(context)
    
    // Apply initial props
    props["title"]?.let { button.text = it.toString() }
    
    // Apply semantic colors (MUST support)
    props["primaryColor"]?.let { color ->
        val colorInt = ColorUtilities.parseColor(color.toString())
        if (colorInt != null) {
            button.setTextColor(colorInt)
        }
    }
    
    // Framework automatically stores props via updateView
    updateView(button, props)
    
    return button
}
```

**Key Points:**
- ✅ Create native view instance
- ✅ Apply initial props
- ✅ **MUST support semantic colors** (primaryColor, secondaryColor, tertiaryColor, accentColor)
- ✅ Set up event listeners if needed
- ✅ Return the view

---

### 2. `updateView` - Update Existing View

**Purpose:** Update an existing view with new props.

**iOS:**
```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let button = view as? UIButton else { return false }
    
    // Update title if changed
    if let title = props["title"] as? String {
        button.setTitle(title, for: .normal)
    }
    
    // Update semantic colors (MUST support)
    if let primaryColor = props["primaryColor"] as? String {
        if let color = ColorUtilities.color(fromHexString: primaryColor) {
            button.setTitleColor(color, for: .normal)
        }
    }
    
    return true
}
```

**Android:**
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val button = view as? Button ?: return false
    
    // CRITICAL: Framework automatically merges props with existing stored props
    // You receive merged props - all properties are preserved automatically
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
    
    // Update title if provided
    mergedProps["title"]?.let { button.text = it.toString() }
    
    // Update semantic colors (MUST support)
    mergedProps["primaryColor"]?.let { color ->
        val colorInt = ColorUtilities.parseColor(color.toString())
        if (colorInt != null) {
            button.setTextColor(colorInt)
        }
    }
    
    // Apply styles (framework handles layout properties)
    button.applyStyles(nonNullProps)
    
    return true
}
```

**Key Points:**
- ✅ **Framework automatically merges props** - No need to check if props changed
- ✅ **All properties preserved** - Text alignment, font size, colors automatically preserved
- ✅ **No glue code needed** - No `hasPropChanged()` or manual prop comparison
- ✅ **MUST support semantic colors**
- ✅ Return `true` if view was updated, `false` if not

**Simplified Pattern (Most Components):**
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val button = view as? Button ?: return false
    
    // Framework handles merging automatically - just use props directly
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
    
    // Update properties
    mergedProps["title"]?.let { button.text = it.toString() }
    
    // Apply styles
    button.applyStyles(nonNullProps)
    
    return true
}
```

---

### 3. `applyLayout` - Apply Yoga Layout

**Purpose:** Apply layout constraints from Yoga layout engine.

**When called:**
- After layout calculation
- When layout changes

**iOS:**
```swift
func applyLayout(_ view: UIView, layout: YGNodeLayout) {
    view.frame = CGRect(
        x: layout.left,
        y: layout.top,
        width: layout.width,
        height: layout.height
    )
}
```

**Android:**
```kotlin
// Not directly in protocol, but handled by framework
// Views automatically receive layout via ViewManager
```

**Key Points:**
- ✅ Apply position and size from Yoga layout
- ✅ iOS: Set `view.frame`
- ✅ Android: Framework handles automatically

---

### 4. `getIntrinsicSize` - Measure View Size

**Purpose:** Return the intrinsic content size of the view for layout calculation.

**When called:**
- During layout calculation
- When Yoga needs to measure the view

**iOS:**
```swift
func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
    guard let button = view as? UIButton else {
        return CGSize.zero
    }
    
    let size = button.intrinsicContentSize
    return CGSize(
        width: max(1, size.width),
        height: max(1, size.height)
    )
}
```

**Android (Traditional View):**
```kotlin
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val button = view as Button
    
    // Measure view
    button.measure(
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    )
    
    return PointF(
        max(1f, button.measuredWidth.toFloat()),
        max(1f, button.measuredHeight.toFloat())
    )
}
```

**Android (Compose Component):**
```kotlin
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
    val composeView = wrapper.composeView
    
    // CRITICAL: Yoga calls getIntrinsicSize with emptyMap(), 
    // so we MUST get props from storedProps
    val storedProps = getStoredProps(view)
    val allProps = if (props.isEmpty()) storedProps else props
    
    val content = allProps["content"]?.toString() ?: ""
    if (content.isEmpty()) {
        return PointF(0f, 0f)
    }
    
    // CRITICAL: Framework ensures ComposeView is composed before this is called
    // (handled in YogaShadowTree.setupMeasureFunction)
    // So we can use actual measurement, not estimation
    wrapper.ensureCompositionReady()
    
    // Measure the actual ComposeView
    val maxWidth = 10000
    composeView.measure(
        View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    )
    
    val measuredWidth = composeView.measuredWidth.toFloat()
    val measuredHeight = composeView.measuredHeight.toFloat()
    
    // Fallback if measurement returns 0 (should be rare)
    if (measuredWidth == 0f || measuredHeight == 0f) {
    val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
        val lines = content.split("\n")
        val maxLineLength = lines.maxOfOrNull { it.length } ?: content.length
        val estimatedWidth = maxLineLength * fontSize * 0.6f
        val estimatedHeight = lines.size * fontSize * 1.2f
        return PointF(estimatedWidth.coerceAtLeast(1f), estimatedHeight.coerceAtLeast(1f))
    }
    
    return PointF(measuredWidth.coerceAtLeast(1f), measuredHeight.coerceAtLeast(1f))
}
```

**Key Points:**
- ✅ Return intrinsic content size
- ✅ Used by Yoga for layout calculation
- ✅ Return at least 1x1 (never zero)
- ✅ **For Compose:** Framework ensures composition before `getIntrinsicSize` is called, so use **actual measurement** instead of estimation. See [Android Compose Integration](../ANDROID_COMPOSE_INTEGRATION.md) for details.

---

### 5. `viewRegisteredWithShadowTree` - View Registration

**Purpose:** Called when view is registered with the shadow tree (Yoga layout).

**When called:**
- After view is created and added to hierarchy
- When view is registered with Yoga

**iOS:**
```swift
func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
    // Store nodeId if needed
    objc_setAssociatedObject(
        view,
        UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
        nodeId,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
}
```

**Android:**
```kotlin
override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    // Store nodeId if needed
    view.setTag(R.id.dcf_node_id, nodeId)
}
```

**Key Points:**
- ✅ Called after view creation
- ✅ Can store nodeId for reference
- ✅ Usually minimal implementation needed

---

### 6. `handleTunnelMethod` - Direct Method Calls

**Purpose:** Handle direct method calls from Dart (bypasses VDOM).

**When called:**
- When Dart calls `FrameworkTunnel.call()`
- For framework-specific operations

**iOS:**
```swift
static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
    switch method {
    case "focus":
        // Focus the input field
        return true
    case "blur":
        // Blur the input field
        return true
    default:
        return nil
    }
}
```

**Android:**
```kotlin
override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
    return when (method) {
        "focus" -> {
            // Focus the input field
            true
        }
        "blur" -> {
            // Blur the input field
            true
        }
        else -> null
    }
}
```

**Key Points:**
- ✅ Handle framework-specific operations
- ✅ Return result or `null` if method not supported
- ✅ iOS: Static method
- ✅ Android: Instance method

---

## Semantic Colors (MUST Support)

**CRITICAL:** All components MUST support semantic colors for theme consistency.

### Semantic Color Props

1. **`primaryColor`** - Primary text/action color
2. **`secondaryColor`** - Secondary text/placeholder color
3. **`tertiaryColor`** - Tertiary text/hint color
4. **`accentColor`** - Accent/highlight color

### Why Semantic Colors?

- **StyleSheet always provides them** (via `toMap()`)
- **Theme support** - Colors change when theme toggles
- **Cross-platform consistency** - Same colors on iOS and Android
- **Framework optimization** - `onlySemanticColorsChanged()` detects theme changes

### Implementation Pattern

**iOS:**
```swift
// In createView and updateView
if let primaryColor = props["primaryColor"] as? String {
    if let color = ColorUtilities.color(fromHexString: primaryColor) {
        button.setTitleColor(color, for: .normal)
    }
    // NO FALLBACK - StyleSheet always provides colors
}
```

**Android:**
```kotlin
// In createView and updateViewInternal
props["primaryColor"]?.let { color ->
    val colorInt = ColorUtilities.parseColor(color.toString())
    if (colorInt != null) {
        button.setTextColor(colorInt)
    }
    // NO FALLBACK - StyleSheet always provides colors
}
```

**Key Rules:**
- ✅ **MUST support all 4 semantic colors**
- ✅ **NO fallbacks** - StyleSheet always provides them
- ✅ **Handle color parsing errors gracefully** (don't crash)
- ✅ **Apply colors in both createView and updateView**

---

## State Preservation Pattern

### iOS (Natural)

iOS UIKit naturally preserves state:
```swift
// UISlider.value is automatically preserved
// UISegmentedControl.selectedSegmentIndex is automatically preserved
// No framework intervention needed
```

### Android (Automatic Prop Merging)

Android uses automatic prop merging at the framework level:
```kotlin
override fun updateView(view: View, props: Map<String, Any?>): Boolean {
    val seekBar = view as? SeekBar ?: return false
    
    // CRITICAL: Framework automatically merges props with existing stored props
    val existingProps = getStoredProps(view)
    val mergedProps = mergeProps(existingProps, props)
    storeProps(view, mergedProps)
    
    val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
    
    // Update value if provided (framework ensures all props are preserved)
    mergedProps["value"]?.let {
        val value = when (it) {
            is Number -> it.toFloat()
            is String -> it.toFloatOrNull() ?: 0f
            else -> 0f
        }
        seekBar.progress = (value * 100).toInt()
    }
    
    // Update semantic colors (MUST support)
    ColorUtilities.getColor("minimumTrackColor", "primaryColor", nonNullProps)?.let { colorInt ->
        seekBar.progressTintList = ColorStateList.valueOf(colorInt)
    }
    
    // Apply styles
    seekBar.applyStyles(nonNullProps)
    
    return true
}
```

**Key Pattern:**
- ✅ **Framework automatically merges props** - All properties preserved
- ✅ **No glue code needed** - No `hasPropChanged()` or manual prop comparison
- ✅ **State always preserved** - Text alignment, font size, colors automatically preserved
- ✅ **Simpler code** - Just update properties directly

---

## Event Handling

### Setting Up Events

**iOS:**
```swift
func createView(props: [String: Any]) -> UIView {
    let button = UIButton(type: .system)
    
    // Set up event listener
    button.addTarget(self, action: #selector(handlePress(_:)), for: .touchUpInside)
    
    return button
}

@objc private func handlePress(_ sender: UIButton) {
    propagateEvent(on: sender, eventName: "onPress", data: [
        "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
        "fromUser": true
    ])
}
```

**Android:**
```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val button = Button(context)
    
    // Set up event listener
    button.setOnClickListener {
        propagateEvent(button, "onPress", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "fromUser" to true
        ))
    }
    
    return button
}
```

**Key Points:**
- ✅ Use `propagateEvent()` to send events to Dart
- ✅ Event names must match Dart handlers (e.g., `onPress`)
- ✅ Include `timestamp` (milliseconds) and `fromUser` in event data for type-safe callbacks
- ✅ Timestamp format: iOS uses `Int64(Date().timeIntervalSince1970 * 1000)`, Android uses `System.currentTimeMillis()`

---

## Complete Component Example

### iOS Example (TouchableOpacity Pattern)

For components that need to handle touches with children (like TouchableOpacity):

```swift
class DCFTouchableOpacityComponent: NSObject, DCFComponent {
    private static var componentInstances = NSMapTable<UIView, DCFTouchableOpacityComponent>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let touchableView = TouchableView()
        
        // CRITICAL: Create component instance per view and store strongly
        let componentInstance = DCFTouchableOpacityComponent()
        touchableView.component = componentInstance
        DCFTouchableOpacityComponent.componentInstances.setObject(componentInstance, forKey: touchableView)
        
        touchableView.isUserInteractionEnabled = true
        
        // Use gesture recognizer for touch tracking
        let touchTrackingGesture = TouchTrackingGestureRecognizer(target: touchableView, action: #selector(TouchableView.handleTouchTracking(_:)))
        touchTrackingGesture.cancelsTouchesInView = false
        touchTrackingGesture.delegate = touchableView
        touchableView.addGestureRecognizer(touchTrackingGesture)
        
        updateView(touchableView, withProps: props)
        touchableView.applyStyles(props: props)
        
        return touchableView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let touchableView = view as? TouchableView else { return false }
        
        // Restore component reference if lost
        if touchableView.component == nil {
            if let existingComponent = DCFTouchableOpacityComponent.componentInstances.object(forKey: touchableView) {
                touchableView.component = existingComponent
            } else {
                let newComponent = DCFTouchableOpacityComponent()
                touchableView.component = newComponent
                DCFTouchableOpacityComponent.componentInstances.setObject(newComponent, forKey: touchableView)
            }
        }
        
        // Update props...
        return true
    }
    
    func handleTouchDown(_ view: TouchableView) {
        UIView.animate(withDuration: 0.1) {
            view.alpha = view.activeOpacity
        }
        
        propagateEvent(on: view, eventName: "onPressIn", data: [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ])
    }
    
    // ... other methods
}

class TouchableView: UIView, UIGestureRecognizerDelegate {
    var component: DCFTouchableOpacityComponent?  // Strong reference, not weak!
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func handleTouchTracking(_ gesture: TouchTrackingGestureRecognizer) {
        guard let comp = component else { return }
        
        switch gesture.state {
        case .began:
            comp.handleTouchDown(self)
        case .ended:
            comp.handleTouchUp(self, inside: bounds.contains(gesture.location(in: self)))
        default:
            break
        }
    }
}
```

**Key Pattern for Touchable Components:**
- ✅ Use **strong** component reference (not weak) to prevent deallocation
- ✅ Store component instances in `NSMapTable` with weak keys and strong values
- ✅ Use gesture recognizers for touch handling when children are present
- ✅ Implement `UIGestureRecognizerDelegate` for simultaneous recognition

### Android Example (TouchableOpacity Pattern)

For components that need to handle touches with children:

```kotlin
class DCFTouchableOpacityComponent : DCFComponent() {
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "TouchableOpacity")
        
        // Framework automatically enables touch handling when event listeners are registered
        // No manual isClickable/isFocusable settings needed!
        
        frameLayout.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    propagateEvent(view, "onPressIn", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
                    ))
                    view.animate().alpha(activeOpacity).setDuration(100).start()
                    true
                }
                MotionEvent.ACTION_UP -> {
                    propagateEvent(view, "onPressOut", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "fromUser" to true
                    ))
                    view.animate().alpha(1.0f).setDuration(100).start()
                    
                    if (event.x >= 0 && event.x <= view.width && event.y >= 0 && event.y <= view.height) {
                        propagateEvent(view, "onPress", mapOf(
                            "timestamp" to System.currentTimeMillis(),
                            "fromUser" to true
                        ))
                    }
                    true
                }
                else -> false
            }
        }
        
        updateView(frameLayout, props)
        return frameLayout
    }
}
```

**Key Pattern for Touchable Components:**
- ✅ Framework automatically enables `isClickable`, `isFocusable`, and `isFocusableInTouchMode` when event listeners are registered
- ✅ Use `setOnTouchListener` for touch handling
- ✅ Include `timestamp` (milliseconds) and `fromUser` in event data
- ✅ Framework automatically skips `opacity` prop for components that manage their own alpha (TouchableOpacity, GestureDetector)

### Android Example (Compose Component)

```kotlin
class DCFTextComponent : DCFComponent() {
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Use DCFComposeWrapper for composition readiness tracking
        val composeView = ComposeView(context)
        val wrapper = DCFComposeWrapper(context, composeView)
        wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // Framework controls visibility - don't set here!
        
        storeProps(wrapper, props)
        
        // CRITICAL: Set content BEFORE measuring to prevent flash
        updateComposeContent(composeView, props)
        
        // Apply styles (Yoga layout properties)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        wrapper.applyStyles(nonNullProps)
        
        return wrapper
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val wrapper = view as? DCFComposeWrapper ?: return false
        val composeView = wrapper.composeView
        
        // CRITICAL: Framework automatically merges props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(wrapper, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update Compose content with merged props
        updateComposeContent(composeView, mergedProps)
        
        // Update styles
        wrapper.applyStyles(nonNullProps)
        
        return true
    }
    
    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        
        composeView.setContent {
            Material3Text(
                text = content,
                color = Color(textColor ?: Color.Black),
                fontSize = fontSize.sp,
            )
        }
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
        val composeView = wrapper.composeView
        
        // Framework ensures ComposeView is composed before this is called
        wrapper.ensureCompositionReady()
        
        // Measure the actual ComposeView
        val maxWidth = 10000
        composeView.measure(
            View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        
        val measuredWidth = composeView.measuredWidth.toFloat()
        val measuredHeight = composeView.measuredHeight.toFloat()
        
        // Fallback if measurement returns 0 (should be rare)
        if (measuredWidth == 0f || measuredHeight == 0f) {
            val storedProps = getStoredProps(view)
            val allProps = if (props.isEmpty()) storedProps else props
            val content = allProps["content"]?.toString() ?: ""
            val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
            val lines = content.split("\n")
            val maxLineLength = lines.maxOfOrNull { it.length } ?: content.length
            val estimatedWidth = maxLineLength * fontSize * 0.6f
            val estimatedHeight = lines.size * fontSize * 1.2f
            return PointF(estimatedWidth.coerceAtLeast(1f), estimatedHeight.coerceAtLeast(1f))
        }
        
        return PointF(measuredWidth.coerceAtLeast(1f), measuredHeight.coerceAtLeast(1f))
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val wrapper = view as? DCFComposeWrapper ?: return
        val composeView = wrapper.composeView
        val storedProps = getStoredProps(view)
        
        // CRITICAL: Ensure ComposeView is composed before layout calculation
        updateComposeContent(composeView, storedProps)
        
        // Force composition to be ready before layout calculation
        if (view.parent != null) {
            wrapper.ensureCompositionReady()
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null  // No tunnel methods needed
    }
}
```

---

## Compose Integration

DCFlight supports Jetpack Compose for Android components. See [Android Compose Integration](./ANDROID_COMPOSE_INTEGRATION.md) for:
- How ComposeView works with Yoga layout
- Compose component implementation patterns
- getIntrinsicSize pattern for Compose
- Best practices and troubleshooting

**Key Point:** `ComposeView` extends `View`, so it works natively with Yoga. The framework automatically ensures composition is ready before measurement - use `DCFComposeWrapper` and actual measurement in `getIntrinsicSize`. See [Android Compose Integration](./ANDROID_COMPOSE_INTEGRATION.md) for details.

## Next Steps

- [Android Compose Integration](./ANDROID_COMPOSE_INTEGRATION.md) - How to use Compose in components
- [Registry System](./REGISTRY_SYSTEM.md) - How to register components
- [Event System](./EVENT_SYSTEM.md) - How events work
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Requirements and best practices

