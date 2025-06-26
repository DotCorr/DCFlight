# DCFlight Module Development Guidelines

**FACT**: DCFlight components use StatelessComponent and DCFElement patterns, NOT Flutter widgets. This guide shows the correct way to build DCFlight modules.

## Core Component Pattern

### Dart Component Structure
```dart
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// A custom component following DCFlight patterns
class DCFCustomComponent extends StatelessComponent {
  /// Custom properties
  final String customProperty;
  final int? optionalProperty;
  final bool adaptive;
  
  /// Layout and styling
  final LayoutProps layout;
  final StyleSheet styleSheet;
  final List<DCFComponentNode> children;
  final Map<String, dynamic>? events;

  /// Constructor
  DCFCustomComponent({
    super.key,
    required this.customProperty,
    this.optionalProperty,
    this.adaptive = true,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.children = const [],
    this.events,
  });

  @override
  DCFComponentNode render() {
    // Build event map
    Map<String, dynamic> eventMap = events ?? {};
    
    // Return DCFElement - NOT a widget!
    return DCFElement(
      type: 'CustomComponent', // Must match native registration
      props: {
        'customProperty': customProperty,
        'optionalProperty': optionalProperty,
        'adaptive': adaptive,
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: children,
    );
  }
}
```

### Native iOS Implementation Protocol
```swift
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

class DCFCustomComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        
        // Apply adaptive theming by default
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                view.backgroundColor = UIColor.systemBackground
            } else {
                view.backgroundColor = UIColor.white
            }
        } else {
            view.backgroundColor = UIColor.clear
        }
        
        // Apply StyleSheet properties
        view.applyStyles(props: props)
        
        // Apply initial props
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Handle custom properties
        if let customProperty = props["customProperty"] as? String {
            // Handle the custom property
            handleCustomProperty(view, customProperty)
        }
        
        if let optionalProperty = props["optionalProperty"] as? Int {
            // Handle optional property
            handleOptionalProperty(view, optionalProperty)
        }
        
        // Apply StyleSheet properties
        view.applyStyles(props: props)
        
        return true
    }
    
    private func handleCustomProperty(_ view: UIView, _ value: String) {
        // Implement custom property handling
        // Propagate events when needed
        propagateEvent(on: view, eventName: "onCustomPropertyChange", data: [
            "value": value,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func handleOptionalProperty(_ view: UIView, _ value: Int) {
        // Handle optional property
    }
}
```

## Event Handling

### Using propagateEvent() for All Events
```swift
// Text change event
func textFieldDidChange(_ textField: UITextField) {
    propagateEvent(on: textField, eventName: "onChangeText", data: [
        "text": textField.text ?? ""
    ])
}

// Touch events
func buttonPressed(_ button: UIButton) {
    propagateEvent(on: button, eventName: "onPress", data: [
        "buttonTitle": button.titleLabel?.text ?? ""
    ])
}

// Complex gesture events
func gestureRecognized(_ gesture: UIGestureRecognizer) {
    let location = gesture.location(in: gesture.view)
    propagateEvent(on: gesture.view!, eventName: "onGesture", data: [
        "gestureType": getGestureType(gesture),
        "location": ["x": location.x, "y": location.y],
        "state": gesture.state.rawValue
    ])
}
```

### Dart Event Handling
```dart
DCFCustomComponent(
  customProperty: "value",
  events: {
    'onCustomPropertyChange': (data) {
      print('Property changed: ${data['value']}');
    },
    'onPress': (data) {
      print('Button pressed: ${data['buttonTitle']}');
    },
    'onGesture': (data) {
      final location = data['location'];
      print('Gesture at: ${location['x']}, ${location['y']}');
    },
  },
)
```

## Adaptive Theming Protocol

### Required adaptive Property
Every component MUST have an `adaptive` property:

```dart
class DCFCustomComponent extends StatelessComponent {
  final bool adaptive;
  
  DCFCustomComponent({
    this.adaptive = true, // Default to adaptive
    // ... other properties
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'CustomComponent',
      props: {
        'adaptive': adaptive, // REQUIRED
        // ... other props
      },
      children: children,
    );
  }
}
```

### Native Adaptive Implementation
```swift
func createView(props: [String: Any]) -> UIView {
    let view = UIView()
    
    // REQUIRED: Handle adaptive theming
    let isAdaptive = props["adaptive"] as? Bool ?? true
    if isAdaptive {
        // Use system colors for automatic light/dark mode
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
            // Apply other system colors as needed
        } else {
            // Fallback for older iOS
            view.backgroundColor = UIColor.white
        }
    } else {
        // Non-adaptive uses explicit colors
        view.backgroundColor = UIColor.clear
    }
    
    // Apply StyleSheet after adaptive theming
    view.applyStyles(props: props)
    
    return view
}
```

## Presentable Components (Modals, Sheets, Popups)

### Pattern for Presentable Components
Presentable components hide their children in the main UI and present them elsewhere:

```dart
class DCFCustomModal extends StatelessComponent {
  final bool visible;
  final List<DCFComponentNode> children;
  // ... other props
  
  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      'visible': visible,
      // ... other props
    };
    
    // CRITICAL: Control display based on visibility
    props['display'] = visible ? 'flex' : 'none';
    
    return DCFElement(
      type: 'CustomModal',
      props: props,
      children: children, // Children are hidden in main UI, shown in modal
    );
  }
}
```

### Native Presentable Implementation
```swift
class DCFCustomModalComponent: NSObject, DCFComponent {
    static var presentedModals: [String: UIViewController] = [:]
    
    func createView(props: [String: Any]) -> UIView {
        // Create placeholder view (hidden)
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        
        updateView(view, withProps: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let viewId = String(view.hash)
        
        // Check visibility
        let isVisible = props["visible"] as? Bool ?? false
        
        if isVisible {
            presentModal(from: view, props: props, viewId: viewId)
        } else {
            dismissModal(viewId: viewId)
        }
        
        return true
    }
    
    // REQUIRED: Handle children for presentable components
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        // Hide children in placeholder view
        view.subviews.forEach { $0.removeFromSuperview() }
        childViews.forEach { childView in
            view.addSubview(childView)
            childView.isHidden = true // Hidden in main UI
            childView.alpha = 0.0
        }
        
        // Move children to presented modal if active
        if let modalVC = DCFCustomModalComponent.presentedModals[viewId] {
            moveChildrenToModal(modalVC: modalVC, childViews: childViews)
        }
        
        return true
    }
    
    private func presentModal(from view: UIView, props: [String: Any], viewId: String) {
        guard DCFCustomModalComponent.presentedModals[viewId] == nil else { return }
        
        let modalVC = UIViewController()
        
        // Move children to modal and make them visible
        let existingChildren = view.subviews
        moveChildrenToModal(modalVC: modalVC, childViews: existingChildren)
        
        // Store reference
        DCFCustomModalComponent.presentedModals[viewId] = modalVC
        
        // Present modal
        if let topVC = getTopViewController() {
            topVC.present(modalVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    private func dismissModal(viewId: String) {
        guard let modalVC = DCFCustomModalComponent.presentedModals[viewId] else { return }
        
        modalVC.dismiss(animated: true) {
            // Clean up
            DCFCustomModalComponent.presentedModals.removeValue(forKey: viewId)
        }
    }
    
    private func moveChildrenToModal(modalVC: UIViewController, childViews: [UIView]) {
        childViews.forEach { child in
            child.removeFromSuperview()
            modalVC.view.addSubview(child)
            child.isHidden = false // Visible in modal
            child.alpha = 1.0
            
            // Position child in modal
            child.frame = modalVC.view.bounds
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}
```

## Component Registration

### Dart Export
```dart
// In your module's main library file
library dcf_custom_module;

export 'src/components/dcf_custom_component.dart';

// Module initialization
class DCFCustomModule {
  static void initialize() {
    // Register components with framework
    DCFComponentRegistry.register('CustomComponent');
    DCFComponentRegistry.register('CustomModal');
  }
}
```

### iOS Registration
```swift
// In your iOS plugin
@objc(DCFCustomPlugin)
class DCFCustomPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register native components
        DCFComponentRegistry.shared.registerComponent(
            "CustomComponent", 
            componentClass: DCFCustomComponent.self
        )
        DCFComponentRegistry.shared.registerComponent(
            "CustomModal", 
            componentClass: DCFCustomModalComponent.self
        )
    }
}
```

## Component Method Calls (Commands)

### Command Pattern Implementation
Instead of calling methods directly, use the command pattern:

#### Dart Command Definition
```dart
abstract class CustomCommand {
  Map<String, dynamic> toMap();
}

class ExecuteActionCommand implements CustomCommand {
  final String actionType;
  final Map<String, dynamic> parameters;
  
  const ExecuteActionCommand({
    required this.actionType,
    this.parameters = const {},
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'executeAction',
      'actionType': actionType,
      'parameters': parameters,
    };
  }
}
```

#### Component with Commands
```dart
class DCFCustomComponent extends StatelessComponent {
  final CustomCommand? command;
  // ... other properties
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'CustomComponent',
      props: {
        'command': command?.toMap(),
        // ... other props
      },
      children: children,
    );
  }
}
```

#### Native Command Handling
```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    // Handle commands FIRST
    if let commandDict = props["command"] as? [String: Any] {
        handleCommand(view, commandDict)
    }
    
    // ... handle other props
    
    return true
}

private func handleCommand(_ view: UIView, _ command: [String: Any]) {
    guard let type = command["type"] as? String else { return }
    
    switch type {
    case "executeAction":
        handleExecuteActionCommand(view, command)
    default:
        break
    }
}

private func handleExecuteActionCommand(_ view: UIView, _ command: [String: Any]) {
    guard let actionType = command["actionType"] as? String else { return }
    let parameters = command["parameters"] as? [String: Any] ?? [:]
    
    switch actionType {
    case "animate":
        // Execute animation
        UIView.animate(withDuration: 0.3) {
            // Animation code
        }
    case "reset":
        // Reset view state
        view.transform = CGAffineTransform.identity
    default:
        break
    }
    
    // Propagate command completion event
    propagateEvent(on: view, eventName: "onCommandComplete", data: [
        "command": type,
        "actionType": actionType
    ])
}
```

#### Usage Example
```dart
// In your app
class MyApp extends StatelessComponent {
  String _text = "";
  CustomCommand? _command;
  
  void _executeAction() {
    setState(() {
      _command = ExecuteActionCommand(
        actionType: 'animate',
        parameters: {'duration': 0.5}
      );
    });
    
    // Reset command after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _command = null);
    });
  }
  
  @override
  DCFComponentNode render() {
    return DCFCustomComponent(
      customProperty: _text,
      command: _command,
      events: {
        'onCommandComplete': (data) {
          print('Command completed: ${data['command']}');
        },
      },
    );
  }
}
```

## Best Practices

### DO ✅
- Use `StatelessComponent` and `DCFElement` patterns
- Always include `adaptive` property with default `true`
- Use `propagateEvent()` for all native-to-Dart communication
- Follow the command pattern for imperative actions
- Hide children in presentable components' placeholder views
- Apply `view.applyStyles(props: props)` in native components

### DON'T ❌
- Use Flutter widgets or StatefulWidget
- Call native methods directly - use commands instead
- Ignore the `adaptive` property
- Skip event propagation for user interactions
- Show children in main UI for presentable components
- Forget to register components properly

---

**All patterns shown are from actual DCFlight v0.0.2 implementation following the established framework architecture.**
