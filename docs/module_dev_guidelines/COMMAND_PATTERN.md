# Command Pattern Implementation

## DCFlight Command System

Commands are pure data objects that replace imperative method calls, providing type-safe, memory-efficient control over native components.

## Command Definition Pattern

### Base Command Interface
```dart
abstract class ComponentCommand {
  Map<String, dynamic> toMap();
}
```

### Specific Command Implementation
```dart
class AnimateToPositionCommand implements ComponentCommand {
  final double x;
  final double y;
  final double duration;
  final String curve;
  
  const AnimateToPositionCommand({
    required this.x,
    required this.y,
    this.duration = 0.3,
    this.curve = 'easeInOut',
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'animateToPosition',
      'x': x,
      'y': y,
      'duration': duration,
      'curve': curve,
    };
  }
}

class ResetStateCommand implements ComponentCommand {
  const ResetStateCommand();

  @override
  Map<String, dynamic> toMap() {
    return {'type': 'resetState'};
  }
}
```

## Component Command Integration

### Dart Component
```dart
class DCFAnimatedView extends StatelessComponent {
  final ComponentCommand? command;
  final List<DCFComponentNode> children;
  // ... other properties
  
  DCFAnimatedView({
    this.command,
    this.children = const [],
    // ... other parameters
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'AnimatedView',
      props: {
        'command': command?.toMap(),
        // ... other props
      },
      children: children,
    );
  }
}
```

### Native Command Handling
```swift
class DCFAnimatedViewComponent: NSObject, DCFComponent {
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Handle commands FIRST
        if let commandDict = props["command"] as? [String: Any] {
            handleCommand(view, commandDict)
        }
        
        // Handle other props
        // ...
        
        return true
    }
    
    private func handleCommand(_ view: UIView, _ command: [String: Any]) {
        guard let type = command["type"] as? String else {
            print("⚠️ Command missing 'type' field")
            return
        }
        
        switch type {
        case "animateToPosition":
            handleAnimateToPositionCommand(view, command)
        case "resetState":
            handleResetStateCommand(view, command)
        default:
            print("⚠️ Unknown command type: \\(type)")
        }
    }
    
    private func handleAnimateToPositionCommand(_ view: UIView, _ command: [String: Any]) {
        guard let x = command["x"] as? Double,
              let y = command["y"] as? Double else {
            print("⚠️ Invalid animateToPosition command parameters")
            return
        }
        
        let duration = command["duration"] as? Double ?? 0.3
        let curve = command["curve"] as? String ?? "easeInOut"
        
        let targetPoint = CGPoint(x: x, y: y)
        
        // Convert curve string to animation options
        let animationOptions = getAnimationOptions(for: curve)
        
        UIView.animate(withDuration: duration, options: animationOptions, animations: {
            view.center = targetPoint
        }) { completed in
            // Propagate completion event
            propagateEvent(on: view, eventName: "onAnimationComplete", data: [
                "command": "animateToPosition",
                "completed": completed,
                "finalPosition": ["x": x, "y": y]
            ])
        }
    }
    
    private func handleResetStateCommand(_ view: UIView, _ command: [String: Any]) {
        // Reset view to initial state
        view.center = view.superview?.center ?? CGPoint.zero
        view.transform = CGAffineTransform.identity
        view.alpha = 1.0
        
        propagateEvent(on: view, eventName: "onStateReset", data: [:])
    }
    
    private func getAnimationOptions(for curve: String) -> UIView.AnimationOptions {
        switch curve {
        case "easeIn":
            return .curveEaseIn
        case "easeOut":
            return .curveEaseOut
        case "easeInOut":
            return .curveEaseInOut
        case "linear":
            return .curveLinear
        default:
            return .curveEaseInOut
        }
    }
}
```

## Text Input Commands Example

### Command Definitions
```dart
abstract class TextInputCommand {
  Map<String, dynamic> toMap();
}

class FocusCommand implements TextInputCommand {
  const FocusCommand();

  @override
  Map<String, dynamic> toMap() {
    return {'type': 'focus'};
  }
}

class BlurCommand implements TextInputCommand {
  const BlurCommand();

  @override
  Map<String, dynamic> toMap() {
    return {'type': 'blur'};
  }
}

class ClearCommand implements TextInputCommand {
  const ClearCommand();

  @override
  Map<String, dynamic> toMap() {
    return {'type': 'clear'};
  }
}

class SetSelectionCommand implements TextInputCommand {
  final int start;
  final int end;
  
  const SetSelectionCommand({
    required this.start,
    required this.end,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'setSelection',
      'start': start,
      'end': end,
    };
  }
}
```

### Native Text Input Command Implementation
```swift
class DCFTextInputComponent: NSObject, DCFComponent {
    private func handleCommand(_ view: UIView, _ command: [String: Any]) {
        guard let type = command["type"] as? String else { return }
        
        switch type {
        case "focus":
            if let textField = view as? UITextField {
                textField.becomeFirstResponder()
            } else if let textView = view as? UITextView {
                textView.becomeFirstResponder()
            }
            
        case "blur":
            if let textField = view as? UITextField {
                textField.resignFirstResponder()
            } else if let textView = view as? UITextView {
                textView.resignFirstResponder()
            }
            
        case "clear":
            if let textField = view as? UITextField {
                textField.text = ""
                propagateEvent(on: textField, eventName: "onChangeText", data: ["text": ""])
            } else if let textView = view as? UITextView {
                textView.text = ""
                propagateEvent(on: textView, eventName: "onChangeText", data: ["text": ""])
            }
            
        case "setSelection":
            guard let start = command["start"] as? Int,
                  let end = command["end"] as? Int else { return }
            
            if let textField = view as? UITextField {
                setSelection(textField, start: start, end: end)
            } else if let textView = view as? UITextView {
                setSelection(textView, start: start, end: end)
            }
            
        default:
            break
        }
    }
    
    private func setSelection(_ textField: UITextField, start: Int, end: Int) {
        guard let text = textField.text,
              start >= 0, end >= start, end <= text.count else { return }
        
        let startPosition = textField.position(from: textField.beginningOfDocument, offset: start)
        let endPosition = textField.position(from: textField.beginningOfDocument, offset: end)
        
        if let startPos = startPosition, let endPos = endPosition {
            textField.selectedTextRange = textField.textRange(from: startPos, to: endPos)
        }
    }
    
    private func setSelection(_ textView: UITextView, start: Int, end: Int) {
        guard let text = textView.text,
              start >= 0, end >= start, end <= text.count else { return }
        
        let range = NSRange(location: start, length: end - start)
        textView.selectedRange = range
    }
}
```

## Command Usage Patterns

### Single Command Execution
```dart
class MyComponent extends StatelessComponent {
  TextInputCommand? _command;
  
  void _focusInput() {
    setState(() => _command = FocusCommand());
    
    // Reset command after execution
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _command = null);
    });
  }
  
  @override
  DCFComponentNode render() {
    return DCFTextInput(
      command: _command,
      // ... other props
    );
  }
}
```

### Sequential Command Execution
```dart
class SequentialCommandExample extends StatelessComponent {
  TextInputCommand? _command;
  
  void _focusAndSelectAll() async {
    // Focus first
    setState(() => _command = FocusCommand());
    await Future.delayed(Duration(milliseconds: 50));
    
    // Then select all
    setState(() => _command = SelectAllCommand());
    await Future.delayed(Duration(milliseconds: 50));
    
    // Reset
    setState(() => _command = null);
  }
  
  @override
  DCFComponentNode render() {
    return DCFTextInput(
      command: _command,
      // ... other props
    );
  }
}
```

### Command with Parameters
```dart
class ParameterizedCommandExample extends StatelessComponent {
  AnimationCommand? _command;
  
  void _animateToPosition(double x, double y) {
    setState(() => _command = AnimateToPositionCommand(
      x: x,
      y: y,
      duration: 0.5,
      curve: 'easeOut',
    ));
    
    _resetCommand();
  }
  
  void _resetCommand() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _command = null);
    });
  }
  
  @override
  DCFComponentNode render() {
    return DCFAnimatedView(
      command: _command,
      events: {
        'onAnimationComplete': (data) {
          print('Animation completed: ${data['completed']}');
        },
      },
      // ... other props
    );
  }
}
```

## Command Validation

### Native Parameter Validation
```swift
private func handleAnimateToPositionCommand(_ view: UIView, _ command: [String: Any]) {
    // Validate required parameters
    guard let x = command["x"] as? Double,
          let y = command["y"] as? Double else {
        print("⚠️ AnimateToPosition command missing x or y parameters")
        propagateEvent(on: view, eventName: "onCommandError", data: [
            "command": "animateToPosition",
            "error": "Missing required parameters: x, y"
        ])
        return
    }
    
    // Validate parameter ranges
    let duration = command["duration"] as? Double ?? 0.3
    guard duration > 0 && duration <= 10.0 else {
        print("⚠️ Invalid duration: \\(duration)")
        propagateEvent(on: view, eventName: "onCommandError", data: [
            "command": "animateToPosition",
            "error": "Duration must be between 0 and 10 seconds"
        ])
        return
    }
    
    // Execute command
    executeAnimateToPosition(view, x: x, y: y, duration: duration)
}
```

### Dart Command Validation
```dart
class ValidatedAnimateCommand implements ComponentCommand {
  final double x;
  final double y;
  final double duration;
  
  ValidatedAnimateCommand({
    required this.x,
    required this.y,
    required this.duration,
  }) {
    // Validate at creation time
    if (duration <= 0 || duration > 10.0) {
      throw ArgumentError('Duration must be between 0 and 10 seconds');
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'animateToPosition',
      'x': x,
      'y': y,
      'duration': duration,
    };
  }
}
```

## Performance Considerations

### Command Batching
Commands are automatically batched with prop updates:

```dart
// This batches command with other prop changes
setState(() {
  _backgroundColor = Colors.red;
  _command = AnimateCommand();
  _text = "Updated text";
});
```

### Memory Efficiency
Commands are pure data objects with automatic garbage collection:

```dart
// ✅ Memory efficient - no refs or controllers
TextInputCommand? command = shouldFocus ? FocusCommand() : null;

// ✅ Automatic cleanup - no dispose() needed
// ✅ Type safe - compile-time validation
// ✅ Testable - pure data objects
```

---

**Commands replace all imperative method calls in DCFlight, providing type-safe, memory-efficient native control.**
