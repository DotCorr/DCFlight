# Event Handling Guide

## DCFlight Event System

DCFlight uses a unified event system with `propagateEvent()` for all native-to-Dart communication.

### Event Propagation Pattern

#### Native Event Propagation
```swift
// All events use propagateEvent() - NO delegate patterns
propagateEvent(on: view, eventName: "eventName", data: eventData)
```

#### Event Data Structure
```swift
let eventData: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "component": "ComponentName",
    // Event-specific data...
]
```

### Standard Event Names

#### Touch Events
```swift
// Button press
propagateEvent(on: button, eventName: "onPress", data: [:])

// Touch start/end
propagateEvent(on: view, eventName: "onTouchStart", data: [
    "location": ["x": location.x, "y": location.y]
])
propagateEvent(on: view, eventName: "onTouchEnd", data: [:])
```

#### Text Events
```swift
// Text change
func textFieldDidChange(_ textField: UITextField) {
    propagateEvent(on: textField, eventName: "onChangeText", data: [
        "text": textField.text ?? ""
    ])
}

// Focus events
func textFieldDidBeginEditing(_ textField: UITextField) {
    propagateEvent(on: textField, eventName: "onFocus", data: [:])
}

func textFieldDidEndEditing(_ textField: UITextField) {
    propagateEvent(on: textField, eventName: "onBlur", data: [:])
}
```

#### Scroll Events
```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    propagateEvent(on: scrollView, eventName: "onScroll", data: [
        "contentOffset": [
            "x": scrollView.contentOffset.x,
            "y": scrollView.contentOffset.y
        ],
        "contentSize": [
            "width": scrollView.contentSize.width,
            "height": scrollView.contentSize.height
        ]
    ])
}
```

#### Animation Events
```swift
// Animation completion
UIView.animate(withDuration: 0.3, animations: {
    // Animation
}) { completed in
    propagateEvent(on: view, eventName: "onAnimationComplete", data: [
        "completed": completed,
        "duration": 0.3
    ])
}
```

### Dart Event Handling

#### Component Event Registration
```dart
class DCFCustomComponent extends StatelessComponent {
  final Function(Map<String, dynamic>)? onCustomEvent;
  final Function(Map<String, dynamic>)? onPress;
  final Function(Map<String, dynamic>)? onChangeText;
  
  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = {};
    
    if (onCustomEvent != null) {
      eventMap['onCustomEvent'] = onCustomEvent;
    }
    if (onPress != null) {
      eventMap['onPress'] = onPress;
    }
    if (onChangeText != null) {
      eventMap['onChangeText'] = onChangeText;
    }
    
    return DCFElement(
      type: 'CustomComponent',
      props: {
        // ... other props
        ...eventMap,
      },
      children: children,
    );
  }
}
```

#### Event Usage
```dart
DCFCustomComponent(
  onPress: (data) {
    print('Button pressed at: ${data['timestamp']}');
  },
  onChangeText: (data) {
    setState(() => _text = data['text']);
  },
  onCustomEvent: (data) {
    final eventType = data['type'];
    switch (eventType) {
      case 'propertyChange':
        _handlePropertyChange(data);
        break;
      case 'animationComplete':
        _handleAnimationComplete(data);
        break;
    }
  },
)
```

### Complex Event Examples

#### Gesture Events
```swift
class DCFGestureComponent: NSObject, DCFComponent {
    func setupGestureRecognizers(_ view: UIView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        
        view.addGestureRecognizer(tapGesture)
        view.addGestureRecognizer(longPressGesture)
        view.addGestureRecognizer(panGesture)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        propagateEvent(on: gesture.view!, eventName: "onTap", data: [
            "location": ["x": location.x, "y": location.y],
            "numberOfTaps": gesture.numberOfTapsRequired
        ])
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: gesture.view)
        propagateEvent(on: gesture.view!, eventName: "onLongPress", data: [
            "location": ["x": location.x, "y": location.y],
            "minimumPressDuration": gesture.minimumPressDuration
        ])
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        
        propagateEvent(on: gesture.view!, eventName: "onPan", data: [
            "location": ["x": location.x, "y": location.y],
            "translation": ["x": translation.x, "y": translation.y],
            "velocity": ["x": velocity.x, "y": velocity.y],
            "state": gesture.state.rawValue
        ])
    }
}
```

#### Modal Events
```swift
class DCFModalComponent: NSObject, DCFComponent {
    func presentModal() {
        topViewController.present(modalVC, animated: true) {
            propagateEvent(on: view, eventName: "onShow", data: [
                "modalType": "sheet",
                "animated": true
            ])
        }
    }
    
    func dismissModal() {
        modalVC.dismiss(animated: true) {
            propagateEvent(on: view, eventName: "onDismiss", data: [
                "userInitiated": true,
                "animated": true
            ])
        }
    }
    
    // Sheet delegate method
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        propagateEvent(on: sourceView, eventName: "onDismiss", data: [
            "userInitiated": true,
            "gesture": "drag"
        ])
    }
}
```

### Event Performance Tips

#### Throttling High-Frequency Events
```swift
class DCFScrollComponent: NSObject, DCFComponent {
    private var scrollEventTimer: Timer?
    private let scrollEventDelay: TimeInterval = 0.016 // ~60fps
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Throttle scroll events to prevent bridge overload
        scrollEventTimer?.invalidate()
        scrollEventTimer = Timer.scheduledTimer(withTimeInterval: scrollEventDelay, repeats: false) { _ in
            propagateEvent(on: scrollView, eventName: "onScroll", data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y
                ]
            ])
        }
    }
}
```

#### Batch Event Data
```swift
func propagateComplexEvent(on view: UIView) {
    // Batch related data in single event
    propagateEvent(on: view, eventName: "onComplexInteraction", data: [
        "user": [
            "action": "swipe",
            "direction": "left",
            "velocity": 150.0
        ],
        "view": [
            "frame": [
                "x": view.frame.origin.x,
                "y": view.frame.origin.y,
                "width": view.frame.size.width,
                "height": view.frame.size.height
            ]
        ],
        "system": [
            "timestamp": Date().timeIntervalSince1970,
            "interfaceOrientation": UIDevice.current.orientation.rawValue
        ]
    ])
}
```

---

**Use propagateEvent() for ALL native-to-Dart communication. No exceptions.**
