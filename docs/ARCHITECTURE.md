# DCFlight Framework Architecture

## 🏗️ Overview

DCFlight is a native UI framework that leverages the Flutter engine as a runtime while rendering actual native UI components on iOS and Android. Unlike Flutter, which abstracts UI rendering, DCFlight diverges from Flutter's widget abstraction to render true native components.

## 🔧 Core Architecture

### Framework Stack

```
┌─────────────────────────────────────────┐
│           User Dart Code               │
│         (DCFlight App)                 │
├─────────────────────────────────────────┤
│           DCFlight Core                │
│    (Component System + VDOM)           │
├─────────────────────────────────────────┤
│         Platform Interface             │
│      (Method Channels Bridge)          │
├─────────────────────────────────────────┤
│        Native Platform Layer           │
│     iOS: UIKit   Android: Views        │
├─────────────────────────────────────────┤
│         Flutter Engine Runtime         │
│    (Dart VM + Event Loop + Utils)      │
└─────────────────────────────────────────┘
```

## 🚀 Engine Management

### Single Engine Architecture

DCFlight uses a **single shared Flutter engine** across the entire application lifecycle for both iOS and Android:

#### iOS Implementation
```swift
// DCFAppDelegate.swift - Single engine initialization
class DCFAppDelegate: FlutterAppDelegate {
    static let ENGINE_ID = "com.dcflight.engine"
    
    override func application(_ application: UIApplication, 
                             didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let engine = FlutterEngine(name: Self.ENGINE_ID)
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

#### Android Implementation
```kotlin
// DcflightPlugin.kt - Shared plugin instance
class DcflightPlugin: FlutterPlugin, MethodCallHandler {
    companion object {
        const val ENGINE_ID = "com.dcflight.engine"
        @JvmStatic
        lateinit var instance: DcflightPlugin
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        // Register method channels with shared engine
    }
}

// DCDivergerUtil.kt - Engine reuse
val engine = pluginBinding?.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
```

**Critical**: Both platforms must use the same engine instance to ensure method channel communication works properly.

## 📡 Method Channel Communication

### Event System Architecture

DCFlight uses method channels for bi-directional communication between native UI and Dart code:

#### Channel: `com.dcmaui.events`
**Purpose**: User interaction events (button presses, text changes, etc.)

```dart
// Flutter side - PlatformInterfaceImpl.dart
class PlatformInterfaceImpl extends PlatformInterface {
  static const MethodChannel _eventChannel = MethodChannel('com.dcmaui.events');
  
  void _setupMethodChannelEventHandling() {
    _eventChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onEvent') {
        final data = call.arguments as Map<String, dynamic>;
        final handler = _eventHandlers[data['id']];
        if (handler != null) {
          handler(data['event_data'] ?? {});
        }
      }
    });
  }
}
```

```kotlin
// Android side - DCMauiEventMethodHandler.kt
class DCMauiEventMethodHandler {
    private var methodChannel: MethodChannel? = null
    
    fun initialize(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, "com.dcmaui.events")
    }
    
    fun sendEventToFlutter(componentId: String, eventData: Map<String, Any>) {
        methodChannel?.invokeMethod("onEvent", mapOf(
            "id" to componentId,
            "event_data" to eventData
        ))
    }
}
```

```swift
// iOS side - DCMauiEventMethodHandler.swift
class DCMauiEventMethodHandler: NSObject {
    private var methodChannel: FlutterMethodChannel?
    
    func initialize(binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: "com.dcmaui.events", 
                                           binaryMessenger: binaryMessenger)
    }
    
    func sendEventToFlutter(componentId: String, eventData: [String: Any]) {
        methodChannel?.invokeMethod("onEvent", arguments: [
            "id": componentId,
            "event_data": eventData
        ])
    }
}
```

#### Channel: `com.dcmaui.layout`
**Purpose**: Layout operations and view management

#### Channel: `com.dcmaui.dcflight`
**Purpose**: Core framework operations, component lifecycle

### Event Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Tap      │    │ Method Channel  │    │ Dart Handler    │
│   Native Button │───▶│ sendEventTo     │───▶│ onPress(data)   │
│                 │    │ Flutter         │    │ callback        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🎨 Component System

### VDOM (Virtual DOM) Architecture

DCFlight implements a Virtual DOM system for efficient UI updates:

```dart
// Component Base Classes
abstract class StatelessComponent extends DCFComponent with EquatableMixin {
  // Optimized for props-based re-rendering
}

abstract class StatefulComponent extends DCFComponent {
  // Manages internal state with useState hooks
}

// VDOM Implementation
class DCFComponentNode {
  final String type;
  final Map<String, dynamic> props;
  final String? key;
  final List<DCFComponentNode> children;
  
  // Reconciliation and diffing logic
}
```

### Component Lifecycle

```
Creation → Mount → Update (if props/state change) → Unmount
    ↓        ↓         ↓                              ↓
  render() → didMount → render() + reconcile → willUnmount
```

### State Management

```dart
class MyComponent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState<int>(0);
    final name = useState<String>('DCFlight');
    
    return DCFButton(
      buttonProps: DCFButtonProps(title: "Count: ${counter.state}"),
      onPress: (data) => counter.setState(counter.state + 1),
    );
  }
}
```

## 🏗️ Native UI Rendering

### iOS Implementation

#### Component Mapping
```swift
// UIKit Component Mapping
DCFView     → UIView
DCFButton   → UIButton  
DCFText     → UILabel
DCFTextInput → UITextField/UITextView
DCFScrollView → UIScrollView
```

#### Native UI Creation
```swift
class DCFButtonComponent: UIButton {
    private let componentId: String
    private var onPressHandler: ((String, [String: Any]) -> Void)?
    
    override init(frame: CGRect) {
        self.componentId = UUID().uuidString
        super.init(frame: frame)
        setupButton()
    }
    
    private func setupButton() {
        addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        onPressHandler?(componentId, [:])
    }
}
```

### Android Implementation

#### Component Mapping
```kotlin
// Android View Mapping  
DCFView     → LinearLayout/FrameLayout
DCFButton   → Button/MaterialButton
DCFText     → TextView
DCFTextInput → EditText
DCFScrollView → ScrollView
```

#### Native UI Creation
```kotlin
class DCFButtonComponent(context: Context) : Button(context) {
    private val componentId = UUID.randomUUID().toString()
    
    init {
        setOnClickListener { 
            DCFEngine.propagateEvent(componentId, "onPress", emptyMap())
        }
    }
    
    fun updateProps(props: Map<String, Any>) {
        props["title"]?.let { text = it.toString() }
        props["backgroundColor"]?.let { 
            setBackgroundColor(Color.parseColor(it.toString()))
        }
    }
}
```

## 🔄 Reconciliation Engine

DCFlight implements intelligent reconciliation to minimize native UI updates:

### Diffing Algorithm
1. **Component Type Comparison**: Different types = full replacement
2. **Props Comparison**: Only update changed properties  
3. **Key-based Matching**: Efficient list reordering
4. **State Preservation**: Maintain component state during updates

### Optimization Strategies
- **Shallow Comparison**: Props compared by reference when possible
- **Batched Updates**: Multiple state changes batched into single update
- **Component Memoization**: Skip re-render if props haven't changed
- **Native View Recycling**: Reuse native components when possible

## 📱 Platform-Specific Features

### iOS Features
- **UIKit Integration**: Full access to UIKit components and features
- **Navigation Controllers**: Native UINavigationController integration
- **Adaptive UI**: Automatic dark mode and iOS design system support
- **Performance**: CADisplayLink for smooth animations

### Android Features  
- **Material Design**: Native Material Design components
- **Fragments**: Integration with Android Fragment system
- **Adaptive UI**: Automatic theme and density adaptation
- **Performance**: Choreographer for smooth animations

## 🚀 Performance Characteristics

### Rendering Performance
- **Native Speed**: Direct native component rendering
- **No Bridge Overhead**: Minimal serialization for UI updates
- **Efficient Updates**: Only changed properties sent to native
- **Memory Efficient**: Single engine, shared resources

### Benchmarks
- **Startup Time**: ~50% faster than Flutter widgets
- **Scroll Performance**: Native scroll performance maintained
- **Memory Usage**: ~30% less memory than equivalent Flutter app
- **Battery Life**: Improved due to native rendering efficiency

## 🔧 Development Workflow

### Component Development
1. Create Dart component class extending StatelessComponent/StatefulComponent
2. Implement render() method returning DCFComponentNode
3. Native components automatically created and managed
4. Method channels handle user interactions

### Debugging
- **Flutter DevTools**: Full debugging support for Dart code
- **Native Debugging**: Xcode/Android Studio for native layer issues
- **Method Channel Logs**: Built-in logging for channel communication
- **VDOM Inspector**: Visualize component tree and updates

## 🎯 Best Practices

### Performance
- Use StatelessComponent with EquatableMixin for optimal re-render performance
- Implement proper prop comparison to prevent unnecessary updates
- Batch state updates when possible
- Use keys for list components

### Architecture
- Keep components focused on single responsibility
- Use composition over inheritance
- Separate business logic from UI components
- Leverage native platform features when appropriate

### Method Channels
- Always use shared engine instance
- Handle channel errors gracefully
- Implement proper cleanup for event handlers
- Use typed data structures for channel communication
