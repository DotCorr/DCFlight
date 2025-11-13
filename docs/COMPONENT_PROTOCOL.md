# Component Protocol Guide
## Native Component Implementation (iOS & Android)

This guide explains what each part of the component protocol does and how to implement components correctly.

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
    fun updateView(view: View, props: Map<String, Any?>): Boolean  // Final - framework handles merging
    protected abstract fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean
    abstract fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF
    abstract fun viewRegisteredWithShadowTree(view: View, nodeId: String)
    abstract fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any?
}
```

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
// Framework handles updateView (final method)
// You implement updateViewInternal instead:

override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
    val button = view as Button
    
    // Use framework helper to check if prop changed
    if (hasPropChanged("title", existingProps, props)) {
        props["title"]?.let { button.text = it.toString() }
    }
    
    // Update semantic colors (MUST support)
    if (hasPropChanged("primaryColor", existingProps, props)) {
        props["primaryColor"]?.let { color ->
            val colorInt = ColorUtilities.parseColor(color.toString())
            if (colorInt != null) {
                button.setTextColor(colorInt)
            }
        }
    }
    
    return true
}
```

**Key Points:**
- ✅ Update view properties based on props
- ✅ **MUST support semantic colors**
- ✅ Use `hasPropChanged()` (Android) to avoid unnecessary updates
- ✅ Return `true` if view was updated, `false` if not

**iOS Optional Helper:**
```swift
// iOS can use updateViewWithMerging for automatic props merging
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    return updateViewWithMerging(view, withProps: props.mapValues { $0 as Any? })
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

### Android (Framework Optimization)

Android uses framework optimization:
```kotlin
override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
    val seekBar = view as SeekBar
    
    // Framework helper: Only update if changed
    if (hasPropChanged("value", existingProps, props)) {
        props["value"]?.let { seekBar.progress = (it as Float * 100).toInt() }
    }
    
    // Framework optimization: Preserve state when only colors change
    if (onlySemanticColorsChanged(existingProps, props)) {
        // Read state from view (not props - might be stale)
        val value = seekBar.progress / 100f
        updateColors(seekBar, props)
        // State preserved!
    }
    
    return true
}
```

**Key Pattern:**
- ✅ Use `hasPropChanged()` to avoid unnecessary updates
- ✅ Use `onlySemanticColorsChanged()` for theme changes
- ✅ Read state from view when only colors change

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
    propagateEvent(on: sender, eventName: "onPress", data: ["pressed": true])
}
```

**Android:**
```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val button = Button(context)
    
    // Set up event listener
    button.setOnClickListener {
        propagateEvent(button, "onPress", mapOf("pressed" to true))
    }
    
    return button
}
```

**Key Points:**
- ✅ Use `propagateEvent()` to send events to Dart
- ✅ Event names must match Dart handlers (e.g., `onPress`)
- ✅ Event data is optional but recommended

---

## Complete Component Example

### iOS Example

```swift
class DCFButtonComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let button = UIButton(type: .system)
        
        // Apply semantic colors (MUST)
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                button.setTitleColor(color, for: .normal)
            }
        }
        
        // Apply title
        if let title = props["title"] as? String {
            button.setTitle(title, for: .normal)
        }
        
        // Set up events
        button.addTarget(self, action: #selector(handlePress(_:)), for: .touchUpInside)
        
        // Store props
        storeProps(props.mapValues { $0 as Any? }, in: button)
        
        return button
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let button = view as? UIButton else { return false }
        
        // Update title
        if let title = props["title"] as? String {
            button.setTitle(title, for: .normal)
        }
        
        // Update semantic colors (MUST)
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                button.setTitleColor(color, for: .normal)
            }
        }
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let button = view as? UIButton else { return CGSize.zero }
        let size = button.intrinsicContentSize
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Store nodeId if needed
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil  // No tunnel methods needed
    }
    
    @objc private func handlePress(_ sender: UIButton) {
        propagateEvent(on: sender, eventName: "onPress", data: ["pressed": true])
    }
}
```

### Android Example (Traditional View)

```kotlin
class DCFButtonComponent : DCFComponent() {
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val button = Button(context)
        
        // Apply semantic colors (MUST)
        props["primaryColor"]?.let { color ->
            val colorInt = ColorUtilities.parseColor(color.toString())
            if (colorInt != null) {
                button.setTextColor(colorInt)
            }
        }
        
        // Apply title
        props["title"]?.let { button.text = it.toString() }
        
        // Set up events
        button.setOnClickListener {
            propagateEvent(button, "onPress", mapOf("pressed" to true))
        }
        
        // Framework handles props storage via updateView
        updateView(button, props)
        
        return button
    }
```

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
    
    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val wrapper = view as? DCFComposeWrapper ?: return false
        val composeView = wrapper.composeView
        
        // Update Compose content
        updateComposeContent(composeView, props)
        
        // Update styles
        wrapper.applyStyles(props)
        
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

