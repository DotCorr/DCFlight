# DCFlight Troubleshooting Guide

## 🚨 Common Issues and Solutions

### 1. Method Channel Communication Issues

#### Problem: Button events not triggering Dart callbacks

**Symptoms:**
- Native button animations work (visual feedback)
- Android/iOS logs show events being sent
- Dart callbacks never execute
- No errors in console

**Root Cause:** Multiple Flutter engines breaking method channel communication

**Solution:**
Ensure single engine architecture:

**Android (`DCDivergerUtil.kt`):**
```kotlin
// ✅ Correct - Use existing engine from plugin binding
val engine = pluginBinding?.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)

// ❌ Wrong - Creates new engine, breaks communication  
val engine = FlutterEngine(context)
```

**iOS (`DCFAppDelegate.swift`):**
```swift
// ✅ Correct - Single engine initialization
override func application(_ application: UIApplication, 
                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let engine = FlutterEngine(name: ENGINE_ID)
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    FlutterEngineCache.shared.setEngine(engine, forId: ENGINE_ID)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

**Debug Steps:**
1. Enable debug logging:
   ```dart
   void main() {
     DCFlight.enableDebugLogging();
     DCFlight.start(app: MyApp());
   }
   ```

2. Check logs for engine creation:
   ```
   // Should see ONCE during app startup:
   🔥 DCF_ENGINE: Using existing Flutter engine: com.dcflight.engine
   
   // Should NOT see multiple times:
   🔥 DCF_ENGINE: Creating new Flutter engine
   ```

3. Verify method channel flow:
   ```
   📤 Android: Calling method channel onEvent for ID: [component-id]
   🔥 DCF_ENGINE: ✅ METHOD CHANNEL HANDLER CALLED!
   🔥 DCF_ENGINE: Event handler executed successfully!
   ```

### 2. Plugin Registration Issues

#### Problem: Method channels not initialized

**Symptoms:**
- App crashes on native UI interaction
- "No implementation found" method channel errors
- Missing method channel handlers

**Solution:**
Verify plugin registration:

**Android (`MainActivity.kt`):**
```kotlin
// ✅ Correct
class MainActivity: DCFActivity() {
    // DCFActivity handles plugin registration automatically
}

// ❌ Wrong - Missing DCFActivity inheritance
class MainActivity: FlutterActivity() {
    // Manual plugin registration required but often missed
}
```

**iOS (`AppDelegate.swift`):**
```swift
// ✅ Correct
@main
@objc class AppDelegate: DCFAppDelegate {
  override func application(...) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Component State Issues

#### Problem: Components not re-rendering on state changes

**Symptoms:**
- `useState` values update but UI doesn't change
- Console shows correct state values
- UI remains static

**Solution:**
Check component optimization:

```dart
// ❌ Wrong - EquatableMixin without proper props
class BrokenComponent extends StatelessComponent with EquatableMixin {
  final String title;
  final int count;
  
  BrokenComponent({required this.title, required this.count});
  
  // Missing props getter!
  // @override
  // List<Object?> get props => [title, count];
}

// ✅ Correct - Proper EquatableMixin implementation
class WorkingComponent extends StatelessComponent with EquatableMixin {
  final String title;
  final int count;
  
  WorkingComponent({required this.title, required this.count});
  
  @override
  List<Object?> get props => [title, count];
}
```

### 4. Layout Issues

#### Problem: Components not displaying or positioned incorrectly

**Symptoms:**
- Components invisible or clipped
- Unexpected layout behavior
- Components overlapping

**Solution:**
Check layout properties:

```dart
// ❌ Common mistakes
DCFView(
  layout: LayoutProps(
    // Missing flex or dimensions
    // width: 0, height: 0 (implicit)
  ),
  children: [...],
)

// ✅ Correct layout setup
DCFView(
  layout: LayoutProps(
    flex: 1, // Take available space
    // OR specify dimensions:
    // width: 300, height: 200,
    
    // Ensure children can fit
    justifyContent: YogaJustifyContent.flexStart,
    alignItems: YogaAlign.stretch,
  ),
  children: [...],
)
```

### 5. Hot Reload Issues

#### Problem: Hot reload not working or causing crashes

**Symptoms:**
- Changes not reflecting in app
- App crashes after hot reload
- State lost during reload

**Solution:**
Check development setup:

```bash
# ✅ Use DCFlight CLI for proper hot reload
dcf go

# ❌ Avoid direct flutter commands in DCFlight projects
flutter run  # May not work correctly
```

### 6. Build Issues

#### Problem: Build fails with platform-specific errors

**iOS Build Errors:**
```bash
# Common: Missing iOS deployment target
# Fix in ios/Podfile:
platform :ios, '12.0'

# Missing import
# Add to Runner/AppDelegate.swift:
import dcflight
```

**Android Build Errors:**
```bash
# Common: Kotlin version mismatch
# Fix in android/build.gradle:
ext.kotlin_version = '1.7.10'

# Missing MainActivity inheritance
# Fix in MainActivity.kt:
class MainActivity: DCFActivity()
```

## 🔍 Debugging Techniques

### 1. Enable Comprehensive Logging

```dart
// In main.dart
void main() {
  // Enable all debug features
  DCFlight.enableDebugLogging();
  DCFlight.enableComponentDebugging();
  DCFlight.enableMethodChannelLogging();
  
  DCFlight.start(app: MyApp());
}
```

### 2. Component Debugging

```dart
// Add debug names to components
DCFView(
  debugName: "MainContainer",
  layout: LayoutProps(flex: 1),
  children: [
    DCFButton(
      debugName: "IncrementButton",
      onPress: (data) {
        print("🐛 Button pressed: $data");
        print("🐛 Component: IncrementButton");
      },
    ),
  ],
)
```

### 3. State Debugging

```dart
class DebuggableComponent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    
    // Debug state changes
    print("🐛 Rendering with count: ${count.state}");
    
    return DCFButton(
      onPress: (data) {
        print("🐛 Before setState: ${count.state}");
        count.setState(count.state + 1);
        print("🐛 After setState: ${count.state}");
      },
    );
  }
}
```

### 4. Method Channel Debugging

```dart
// Custom platform interface with debugging
class DebugPlatformInterface extends PlatformInterfaceImpl {
  @override
  void registerEventHandler(String componentId, Function(Map<String, dynamic>) handler) {
    print("🐛 Registering handler for: $componentId");
    super.registerEventHandler(componentId, (data) {
      print("🐛 Handler called for $componentId with data: $data");
      handler(data);
    });
  }
}
```

## 🛠 Development Tools

### 1. DCFlight CLI Diagnostic

```bash
# Clean and rebuild
flutter clean
dcf go --verbose

# Verbose output for debugging
dcf go --verbose
```

### 2. Platform-Specific Debugging

**iOS (Xcode):**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Set breakpoints in native Swift code
3. Use Xcode debugger and console
4. Check iOS Simulator logs

**Android (Android Studio):**
1. Open `android/` folder in Android Studio
2. Set breakpoints in Kotlin code
3. Use Android Studio debugger
4. Monitor `adb logcat` for system logs

### 3. Flutter DevTools

```bash
# Enable DevTools for Dart debugging
flutter run --debug
# Then open DevTools URL in browser
```

## 📋 Verification Checklist

### Before Reporting Issues

- [ ] **Single Engine**: Verified both iOS and Android use single shared engine
- [ ] **Plugin Registration**: Confirmed proper DCFActivity/DCFAppDelegate inheritance
- [ ] **Method Channels**: Validated method channel initialization and registration
- [ ] **Component Props**: Checked EquatableMixin implementation if used
- [ ] **Layout Properties**: Verified component dimensions and flex properties
- [ ] **Debug Logging**: Enabled comprehensive logging to trace issue
- [ ] **Clean Build**: Performed clean build after changes
- [ ] **Both Platforms**: Tested on both iOS and Android if applicable

### Platform Verification

**iOS Checklist:**
- [ ] `AppDelegate` extends `DCFAppDelegate`
- [ ] `GeneratedPluginRegistrant.register(with: self)` called
- [ ] iOS deployment target ≥ 12.0
- [ ] Proper import statements in Swift files

**Android Checklist:**
- [ ] `MainActivity` extends `DCFActivity`
- [ ] Kotlin version compatibility
- [ ] Proper plugin registration in `DcflightPlugin.kt`
- [ ] Method channel initialization in handlers

### Event System Verification

- [ ] **Component ID Generation**: Unique IDs for each component instance
- [ ] **Handler Registration**: Event handlers properly registered with platform interface
- [ ] **Method Channel Flow**: Events flow from native → method channel → Dart handler
- [ ] **Error Handling**: Proper error handling in method channel calls
- [ ] **Cleanup**: Event handlers properly cleaned up on component unmount

## 🆘 Getting Help

If you're still experiencing issues after following this guide:

1. **Enable Debug Logging**: Include full debug output in your issue report
2. **Minimal Reproduction**: Create minimal example that reproduces the issue
3. **Platform Information**: Specify iOS/Android versions and device information
4. **DCFlight Version**: Include DCFlight CLI and framework versions
5. **Error Logs**: Include complete error logs and stack traces

**GitHub Issues:** [https://github.com/DotCorr/DCFlight/issues](https://github.com/DotCorr/DCFlight/issues)

**Debug Template:**
```
**Environment:**
- DCFlight Version: [version]
- Platform: iOS/Android/Both
- Device: [device info]
- Development OS: [macOS/Windows/Linux]

**Issue:**
[Describe the problem]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Debug Output:**
```
[Include relevant logs with debug enabled]
```

**Minimal Reproduction:**
[Include minimal code that reproduces the issue]
```
