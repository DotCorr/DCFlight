# Event System
## How Events Work in DCFlight

The event system allows native components to communicate with Dart through a unified, cross-platform API.

---

## Event Flow

```
┌─────────────────────────────────────────────────────────┐
│              Event Flow Architecture                    │
└─────────────────────────────────────────────────────────┘

User Interaction
    │
    │ (User taps button)
    │
Native Component
    │
    │ propagateEvent(view, "onPress", data)
    │
    ├──────────────────────────────────┐
    │                                  │
iOS Bridge                    Android Bridge
    │                                  │
    │ MethodChannel                   │ MethodChannel
    │ "onEvent"                       │ "onEvent"
    │                                  │
    └──────────────────────────────────┘
                    │
                    │ handleNativeEvent()
                    │
            VDOM Engine
                    │
                    │ Finds component by viewId
                    │
            Component Handler
                    │
                    │ onPress(data)
                    │
            Your Code
```

---

## Native Side: Sending Events

### iOS

**Function:** `propagateEvent(on:view, eventName:data:nativeAction:)`

```swift
// In component
@objc private func handlePress(_ sender: UIButton) {
    propagateEvent(
        on: sender,
        eventName: "onPress",
        data: [
            "timestamp": Date().timeIntervalSince1970,
            "pressed": true
        ]
    )
}
```

**Simplified Helper:**
```swift
// For simple events
fireEvent(on: button, "onPress", ["pressed": true])
```

### Android

**Function:** `propagateEvent(view, eventName, data, nativeAction)`

```kotlin
// In component
button.setOnClickListener {
    propagateEvent(
        button,
        "onPress",
        mapOf(
            "timestamp" to System.currentTimeMillis(),
            "pressed" to true
        )
    )
}
```

**Simplified Helper:**
```kotlin
// For simple events
fireEvent(button, "onPress", mapOf("pressed" to true))
```

---

## Event Registration

### How Events Are Registered

**VDOM automatically registers events:**

```dart
// In Dart
DCFButton(
  buttonProps: DCFButtonProps(
    onPress: (data) => print("Pressed!"),
    onLongPress: (data) => print("Long pressed!"),
  ),
)
```

**VDOM extracts event handlers:**
- Finds all props starting with `on`
- Registers them with native via `addEventListeners()`
- Native stores them in view tags

**iOS:**
```swift
// Framework stores in view
objc_setAssociatedObject(
    view,
    UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
    ["onPress", "onLongPress"],
    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
)
```

**Android:**
```kotlin
// Framework stores in view
view.setTag(R.id.dcf_event_types, setOf("onPress", "onLongPress"))
```

---

## Event Name Conventions

### Standard Event Names

**Touch Events:**
- `onPress` - Single tap/press
- `onLongPress` - Long press
- `onPressIn` - Touch down
- `onPressOut` - Touch up

**Value Change Events:**
- `onValueChange` - Value changed (Slider, Toggle)
- `onSelectionChange` - Selection changed (SegmentedControl)

**Text Input Events:**
- `onChangeText` - Text changed
- `onSubmit` - Text submitted

**Scroll Events:**
- `onScroll` - Scrolling
- `onScrollBeginDrag` - Scroll started
- `onScrollEndDrag` - Scroll ended

### Event Name Normalization

The framework normalizes event names for matching:

```swift
// iOS
"onPress" → "onPress" (exact match)
"press" → "onPress" (normalized)
"Press" → "onPress" (normalized)
```

```kotlin
// Android
"onPress" → "onPress" (exact match)
"press" → "onPress" (normalized)
```

**This allows flexibility in event naming while maintaining consistency.**

---

## Event Data

### Standard Event Data

**Touch Events:**
```dart
{
  "timestamp": 1234567890000,  // Milliseconds since epoch
  "fromUser": true
}
```

**Note:** Modern components use type-safe callbacks. See component documentation for specific event data structures.

**Value Change Events:**
```dart
{
  "value": 0.5,
  "fromUser": true
}
```

**Selection Change Events:**
```dart
{
  "selectedIndex": 2,
  "selectedTitle": "Profile"
}
```

### Custom Event Data

Components can include custom data:

```swift
// iOS
propagateEvent(on: view, eventName: "onCustomEvent", data: [
    "customField": "customValue",
    "number": 123
])
```

```kotlin
// Android
propagateEvent(view, "onCustomEvent", mapOf(
    "customField" to "customValue",
    "number" to 123
))
```

---

## Dart Side: Receiving Events

### Type-Safe Event Handlers

Modern components use type-safe callbacks instead of raw maps:

```dart
// Type-safe handler (recommended)
DCFButton(
  children: [DCFText(content: "Click me")],
  onPress: (DCFButtonPressData data) {
    print("Button pressed at: ${data.timestamp}");
    print("From user: ${data.fromUser}");
  },
)

// TouchableOpacity with type-safe handlers
DCFTouchableOpacity(
  children: [...],
  onPress: (DCFTouchableOpacityPressData data) {
    print("Pressed at: ${data.timestamp}");
  },
  onPressIn: (DCFTouchableOpacityPressInData data) {
    print("Press started");
  },
  onPressOut: (DCFTouchableOpacityPressOutData data) {
    print("Press ended");
  },
)

// GestureDetector with type-safe handlers
DCFGestureDetector(
  children: [...],
  onTap: (DCFGestureTapData data) {
    print("Tapped at: ${data.x}, ${data.y}");
  },
  onSwipeLeft: (DCFGestureSwipeData data) {
    print("Swiped left with velocity: ${data.velocity}");
  },
)
```

### Legacy Handler Signature (Still Supported)

```dart
// Simple handler (no data)
onPress: () => print("Pressed!")

// Handler with data map (legacy, but still works)
onPress: (data) {
  print("Pressed at: ${data['timestamp']}");
}
```

**Key Points:**
- ✅ Use type-safe callbacks when available (prevents errors)
- ✅ Type-safe callbacks include `timestamp` (DateTime) and `fromUser` (bool)
- ✅ Legacy map-based handlers still work for backward compatibility

### Example: Slider Component

```dart
DCFSlider(
  sliderProps: DCFSliderProps(
    value: sliderValue,
    onValueChange: (data) {
      setState(() {
        sliderValue = data['value'] as double;
      });
    },
    onSlidingStart: (data) {
      print("Sliding started");
    },
    onSlidingComplete: (data) {
      print("Sliding completed: ${data['value']}");
    },
  ),
)
```

---

## Event Propagation Details

### iOS Implementation

**File:** `DCFComponentProtocol.swift`

```swift
public func propagateEvent(
    on view: UIView,
    eventName: String,
    data eventData: [String: Any] = [:],
    nativeAction: ((UIView, [String: Any]) -> Void)? = nil
) {
    // 1. Execute native action if provided
    nativeAction?(view, eventData)
    
    // 2. Get event callback from view
    guard let callback = objc_getAssociatedObject(view, ...) as? (String, String, [String: Any]) -> Void else {
        return
    }
    
    // 3. Get viewId and eventTypes
    guard let viewId = objc_getAssociatedObject(view, ...) as? String else {
        return
    }
    
    guard let eventTypes = objc_getAssociatedObject(view, ...) as? [String] else {
        return
    }
    
    // 4. Normalize event name and check if registered
    let normalizedEventName = normalizeEventNameForPropagation(eventName)
    if eventTypes.contains(eventName) || eventTypes.contains(normalizedEventName) {
        callback(viewId, eventName, eventData)
    }
}
```

### Android Implementation

**File:** `DCFComponent.kt`

```kotlin
fun propagateEvent(
    view: View?,
    eventName: String,
    data: Map<String, Any?> = mapOf(),
    nativeAction: ((View, Map<String, Any?>) -> Unit)? = null
) {
    if (view == null) return
    
    // 1. Execute native action if provided
    nativeAction?.invoke(view, data)
    
    // 2. Get viewId, eventTypes, and callback from view tags
    val viewId = view.getTag(R.id.dcf_view_id) as? String
    val eventTypes = view.getTag(R.id.dcf_event_types) as? Set<String>
    val eventCallback = view.getTag(R.id.dcf_event_callback) as? (String, Map<String, Any?>) -> Unit
    
    // 3. Check if event is registered
    if (viewId != null && eventTypes != null && eventCallback != null) {
        val normalizedEventName = normalizeEventNameForPropagation(eventName)
        if (eventTypes.contains(normalizedEventName) || eventTypes.contains(eventName)) {
            eventCallback(eventName, data)
        }
    }
}
```

---

## Event Name Normalization

### Why Normalization?

Allows flexible event naming while maintaining consistency:

```dart
// All of these work:
onPress: () {}      // ✅
onpress: () {}      // ✅ (normalized)
press: () {}        // ✅ (normalized)
Press: () {}        // ✅ (normalized)
```

### Normalization Rules

**iOS:**
```swift
// If starts with "on" and third char is uppercase → keep as is
"onPress" → "onPress"

// Otherwise, add "on" and capitalize first letter
"press" → "onPress"
"Press" → "onPress"
```

**Android:**
```kotlin
// Lowercase and remove "on" prefix, then add "on" and capitalize
"onPress" → "onPress"
"press" → "onPress"
"Press" → "onPress"
```

---

## Best Practices

### 1. Use Standard Event Names

**✅ Good:**
```swift
propagateEvent(on: button, eventName: "onPress", data: [:])
```

**❌ Bad:**
```swift
propagateEvent(on: button, eventName: "buttonClicked", data: [:])  // Non-standard
```

### 2. Include Relevant Data

**✅ Good:**
```swift
propagateEvent(on: slider, eventName: "onValueChange", data: [
    "value": slider.value,
    "fromUser": true
])
```

**❌ Bad:**
```swift
propagateEvent(on: slider, eventName: "onValueChange", data: [:])  // No data
```

### 3. Use Native Actions for Side Effects

```swift
propagateEvent(
    on: button,
    eventName: "onPress",
    data: ["pressed": true],
    nativeAction: { view, data in
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
)
```

---

## Troubleshooting

### Event Not Firing

**Check:**
1. Event handler registered in Dart? (`onPress: ...`)
2. Event name matches? (case-insensitive after normalization)
3. View has viewId? (registered with framework)
4. Event types stored in view? (framework should do this)

### Event Firing But Handler Not Called

**Check:**
1. Handler signature correct? (`(data) => ...` or `() => ...`)
2. VDOM engine has event handler set? (framework should do this)
3. Component instance exists? (not unmounted)

---

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - How to send events from components
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Event naming conventions
- [Tunnel System](./TUNNEL_SYSTEM.md) - When to use tunnel vs events

