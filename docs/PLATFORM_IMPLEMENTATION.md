# Platform Implementation Guide

## 🎯 Overview

This guide provides detailed implementation patterns for both iOS and Android platforms in DCFlight, covering method channels, native UI components, and platform-specific features.

## 🍎 iOS Implementation

### App Delegate Setup

```swift
// DCFAppDelegate.swift
import UIKit
import Flutter

@main
@objc class DCFAppDelegate: FlutterAppDelegate {
    static let ENGINE_ID = "com.dcflight.engine"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Flutter engine with specific ID
        let engine = FlutterEngine(name: Self.ENGINE_ID)
        engine.run()
        
        // Register all plugins with the engine
        GeneratedPluginRegistrant.register(with: engine)
        
        // Cache engine for reuse
        FlutterEngineCache.shared.setEngine(engine, forId: Self.ENGINE_ID)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### Method Channel Handlers

#### Event Handler Implementation
```swift
// DCMauiEventMethodHandler.swift
import Flutter
import UIKit

class DCMauiEventMethodHandler: NSObject {
    static let shared = DCMauiEventMethodHandler()
    private var methodChannel: FlutterMethodChannel?
    private let channelName = "com.dcmaui.events"
    
    private override init() {
        super.init()
    }
    
    func initialize(binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: binaryMessenger
        )
        print("🔥 DCF_ENGINE: iOS Method Channel initialized: \(channelName)")
    }
    
    func sendEventToFlutter(componentId: String, eventData: [String: Any]) {
        print("📤 iOS: Calling method channel onEvent for ID: \(componentId)")
        print("📤 iOS: Event data: \(eventData)")
        
        methodChannel?.invokeMethod("onEvent", arguments: [
            "id": componentId,
            "event_data": eventData
        ]) { result in
            if let error = result as? FlutterError {
                print("❌ Method channel error: \(error)")
            } else {
                print("✅ Method channel call successful")
            }
        }
    }
}
```

### Native Component Implementation

#### DCFButton Component
```swift
// DCFButtonComponent.swift
import UIKit

class DCFButtonComponent: UIButton {
    private let componentId: String
    private var eventData: [String: Any] = [:]
    
    init(componentId: String) {
        self.componentId = componentId
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButton() {
        // Configure button appearance
        layer.cornerRadius = 8
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        // Add touch handler
        addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        
        print("🔥 DCF_ENGINE: iOS Button component initialized with ID: \(componentId)")
    }
    
    @objc private func buttonPressed() {
        print("🔥 DCF_ENGINE: iOS Button pressed - ID: \(componentId)")
        
        // Send event to Flutter via method channel
        DCMauiEventMethodHandler.shared.sendEventToFlutter(
            componentId: componentId,
            eventData: eventData
        )
    }
    
    func updateProps(_ props: [String: Any]) {
        // Update button title
        if let title = props["title"] as? String {
            setTitle(title, for: .normal)
        }
        
        // Update background color
        if let colorHex = props["backgroundColor"] as? String {
            backgroundColor = UIColor(hex: colorHex)
        }
        
        // Update text color
        if let textColorHex = props["textColor"] as? String {
            setTitleColor(UIColor(hex: textColorHex), for: .normal)
        }
        
        // Store event data for when button is pressed
        eventData = props
        
        print("🔥 DCF_ENGINE: iOS Button props updated - ID: \(componentId)")
    }
}

// Color extension for hex support
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
```

### Plugin Registration

```swift
// DcflightPlugin.swift
import Flutter
import UIKit

public class DcflightPlugin: NSObject, FlutterPlugin {
    public static var shared: DcflightPlugin?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DcflightPlugin()
        shared = instance
        
        // Initialize method channel handlers
        DCMauiEventMethodHandler.shared.initialize(
            binaryMessenger: registrar.messenger()
        )
        
        print("🔥 DCF_ENGINE: iOS Plugin registered successfully")
    }
}
```

## 🤖 Android Implementation

### Plugin Registration

```kotlin
// DcflightPlugin.kt
package com.dotcorr.dcflight

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodCallHandler
import io.flutter.plugin.common.MethodChannel

class DcflightPlugin: FlutterPlugin, MethodCallHandler {
    companion object {
        const val ENGINE_ID = "com.dcflight.engine"
        @JvmStatic
        lateinit var instance: DcflightPlugin
            private set
    }
    
    private lateinit var channel: MethodChannel
    private lateinit var pluginBinding: FlutterPlugin.FlutterPluginBinding
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        pluginBinding = flutterPluginBinding
        
        // Initialize main plugin channel
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dcflight")
        channel.setMethodCallHandler(this)
        
        // Initialize method channel handlers
        DCMauiEventMethodHandler.initialize(flutterPluginBinding.binaryMessenger)
        
        println("🔥 DCF_ENGINE: Android Plugin attached to engine")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        println("🔥 DCF_ENGINE: Android Plugin detached from engine")
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    fun getPluginBinding(): FlutterPlugin.FlutterPluginBinding = pluginBinding
}
```

### Method Channel Handlers

#### Event Handler Implementation
```kotlin
// DCMauiEventMethodHandler.kt
package com.dotcorr.dcflight

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object DCMauiEventMethodHandler {
    private const val CHANNEL_NAME = "com.dcmaui.events"
    private var methodChannel: MethodChannel? = null
    
    fun initialize(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        println("🔥 DCF_ENGINE: Android Method Channel initialized: $CHANNEL_NAME")
    }
    
    fun sendEventToFlutter(componentId: String, eventData: Map<String, Any>) {
        println("📤 Android: Calling method channel onEvent for ID: $componentId")
        println("📤 Android: Event data: $eventData")
        
        methodChannel?.invokeMethod("onEvent", mapOf(
            "id" to componentId,
            "event_data" to eventData
        )) { result ->
            when {
                result is Exception -> {
                    println("❌ Method channel error: ${result.message}")
                }
                else -> {
                    println("✅ Method channel call successful")
                }
            }
        }
    }
}
```

### Engine Management

```kotlin
// DCDivergerUtil.kt
package com.dotcorr.dcflight

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

object DCDivergerUtil {
    private const val ENGINE_ID = "com.dcflight.engine"
    
    fun getOrCreateEngine(context: Context): FlutterEngine {
        // CRITICAL: Use existing engine from plugin binding, not create new one
        val pluginBinding = DcflightPlugin.instance.getPluginBinding()
        val engine = pluginBinding.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        
        if (engine != null) {
            println("🔥 DCF_ENGINE: Using existing Flutter engine: $ENGINE_ID")
            return engine
        }
        
        // Only create new engine if none exists (should not happen in normal flow)
        println("⚠️ DCF_ENGINE: Creating new Flutter engine: $ENGINE_ID")
        val newEngine = FlutterEngine(context)
        newEngine.dartExecutor.executeDartEntrypoint()
        FlutterEngineCache.getInstance().put(ENGINE_ID, newEngine)
        return newEngine
    }
}
```

### Native Component Implementation

#### DCFButton Component
```kotlin
// DCFButtonComponent.kt
package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.Color
import androidx.appcompat.widget.AppCompatButton
import java.util.*

class DCFButtonComponent(
    context: Context,
    private val componentId: String = UUID.randomUUID().toString()
) : AppCompatButton(context) {
    
    private var eventData: Map<String, Any> = emptyMap()
    
    init {
        setupButton()
        println("🔥 DCF_ENGINE: Android Button component initialized with ID: $componentId")
    }
    
    private fun setupButton() {
        // Configure button appearance
        cornerRadius = 8f
        textSize = 16f
        isAllCaps = false
        
        // Add click handler
        setOnClickListener {
            println("🔥 DCF_ENGINE: Android Button pressed - ID: $componentId")
            
            // Send event to Flutter via method channel
            DCMauiEventMethodHandler.sendEventToFlutter(componentId, eventData)
        }
    }
    
    fun updateProps(props: Map<String, Any>) {
        // Update button title
        props["title"]?.let { title ->
            text = title.toString()
        }
        
        // Update background color
        props["backgroundColor"]?.let { color ->
            try {
                setBackgroundColor(Color.parseColor(color.toString()))
            } catch (e: IllegalArgumentException) {
                println("⚠️ Invalid color format: $color")
            }
        }
        
        // Update text color
        props["textColor"]?.let { color ->
            try {
                setTextColor(Color.parseColor(color.toString()))
            } catch (e: IllegalArgumentException) {
                println("⚠️ Invalid text color format: $color")
            }
        }
        
        // Store event data for when button is pressed
        eventData = props
        
        println("🔥 DCF_ENGINE: Android Button props updated - ID: $componentId")
    }
}
```

### Event Propagation System

```kotlin
// DCFEngine.kt
package com.dotcorr.dcflight

object DCFEngine {
    fun propagateEvent(componentId: String, eventType: String, eventData: Map<String, Any>) {
        println("🔥 DCF_ENGINE: Propagating event - ID: $componentId, Type: $eventType")
        
        when (eventType) {
            "onPress" -> {
                DCMauiEventMethodHandler.sendEventToFlutter(componentId, eventData)
            }
            // Add other event types as needed
            else -> {
                println("⚠️ Unknown event type: $eventType")
            }
        }
    }
}
```

## 🔄 Flutter Integration

### Platform Interface Implementation

```dart
// interface_impl.dart
import 'package:flutter/services.dart';

class PlatformInterfaceImpl extends PlatformInterface {
  static const MethodChannel _eventChannel = MethodChannel('com.dcmaui.events');
  
  final Map<String, Function(Map<String, dynamic>)> _eventHandlers = {};
  
  PlatformInterfaceImpl() {
    _setupMethodChannelEventHandling();
  }
  
  void _setupMethodChannelEventHandling() {
    print('🔥 DCF_ENGINE: Setting up method channel event handling');
    
    _eventChannel.setMethodCallHandler((MethodCall call) async {
      print('🔥 DCF_ENGINE: ✅ METHOD CHANNEL HANDLER CALLED!');
      print('🔥 DCF_ENGINE: Method: ${call.method}');
      print('🔥 DCF_ENGINE: Arguments: ${call.arguments}');
      
      try {
        if (call.method == 'onEvent') {
          final data = call.arguments as Map<String, dynamic>;
          final componentId = data['id'] as String;
          final eventData = data['event_data'] as Map<String, dynamic>? ?? {};
          
          print('🔥 DCF_ENGINE: Processing event for component: $componentId');
          print('🔥 DCF_ENGINE: Event data: $eventData');
          
          final handler = _eventHandlers[componentId];
          if (handler != null) {
            print('🔥 DCF_ENGINE: Found handler for component: $componentId');
            handler(eventData);
            print('🔥 DCF_ENGINE: Event handler executed successfully!');
          } else {
            print('🔥 DCF_ENGINE: ⚠️ No handler found for component: $componentId');
            print('🔥 DCF_ENGINE: Available handlers: ${_eventHandlers.keys}');
          }
        }
      } catch (e, stackTrace) {
        print('🔥 DCF_ENGINE: ❌ Error in method channel handler: $e');
        print('🔥 DCF_ENGINE: Stack trace: $stackTrace');
      }
    });
  }
  
  @override
  void registerEventHandler(String componentId, Function(Map<String, dynamic>) handler) {
    print('🔥 DCF_ENGINE: Registering event handler for component: $componentId');
    _eventHandlers[componentId] = handler;
    print('🔥 DCF_ENGINE: Total registered handlers: ${_eventHandlers.length}');
  }
  
  @override
  void unregisterEventHandler(String componentId) {
    print('🔥 DCF_ENGINE: Unregistering event handler for component: $componentId');
    _eventHandlers.remove(componentId);
  }
}
```

## 🚀 Best Practices

### Method Channel Communication

1. **Single Engine**: Always use the same Flutter engine instance
2. **Error Handling**: Implement proper error handling for channel calls
3. **Logging**: Add comprehensive logging for debugging
4. **Cleanup**: Properly cleanup handlers when components unmount

### Component Implementation

1. **Unique IDs**: Generate unique component IDs for event handling
2. **Props Updates**: Only update native properties that have changed
3. **Event Data**: Store event data for callback execution
4. **Memory Management**: Properly cleanup resources

### Platform Consistency

1. **Shared Patterns**: Use consistent patterns between iOS and Android
2. **Error Handling**: Handle platform-specific errors gracefully
3. **Performance**: Optimize for each platform's strengths
4. **Testing**: Test on both platforms thoroughly

## 🐛 Debugging

### Common Issues

1. **Multiple Engines**: Ensure single engine architecture
2. **Channel Registration**: Verify method channels are properly initialized
3. **Event Handlers**: Check event handler registration and cleanup
4. **Props Updates**: Validate prop serialization and deserialization

### Debug Logging

Enable comprehensive logging to trace:
- Plugin registration
- Method channel initialization
- Event propagation
- Handler execution
- Error conditions

### Tools

- **Flutter DevTools**: For Dart debugging
- **Xcode**: For iOS native debugging
- **Android Studio**: For Android native debugging
- **adb logcat**: For Android system logs
