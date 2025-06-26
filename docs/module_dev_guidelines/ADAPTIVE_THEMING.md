# Adaptive Theming Guide

## DCFlight Adaptive Theming System

Every DCFlight component MUST support adaptive theming to automatically respond to system light/dark mode changes.

## Required adaptive Property

### Dart Component
```dart
class DCFCustomComponent extends StatelessComponent {
  /// REQUIRED: Adaptive theming support
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
        'adaptive': adaptive, // REQUIRED in props
        // ... other props
      },
      children: children,
    );
  }
}
```

### Native Implementation
```swift
func createView(props: [String: Any]) -> UIView {
    let view = UIView()
    
    // REQUIRED: Handle adaptive property
    let isAdaptive = props["adaptive"] as? Bool ?? true
    
    if isAdaptive {
        // Use system colors for automatic theme adaptation
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
        } else {
            // Fallback for older iOS versions
            view.backgroundColor = UIColor.white
        }
    } else {
        // Non-adaptive uses explicit colors or clear
        view.backgroundColor = UIColor.clear
    }
    
    // Apply StyleSheet AFTER adaptive theming
    view.applyStyles(props: props)
    
    return view
}
```

## System Color Usage

### iOS 13+ System Colors
```swift
// Background colors
UIColor.systemBackground       // Primary background
UIColor.secondarySystemBackground  // Secondary background
UIColor.tertiarySystemBackground   // Tertiary background

// Text colors
UIColor.label                  // Primary text
UIColor.secondaryLabel         // Secondary text
UIColor.tertiaryLabel          // Tertiary text
UIColor.placeholderText        // Placeholder text

// System colors
UIColor.systemBlue             // System blue
UIColor.systemRed              // System red
UIColor.systemGreen            // System green
UIColor.systemOrange           // System orange
UIColor.systemPurple           // System purple

// Fill colors
UIColor.systemFill             // Primary fill
UIColor.secondarySystemFill    // Secondary fill
UIColor.tertiarySystemFill     // Tertiary fill
UIColor.quaternarySystemFill   // Quaternary fill

// Gray colors
UIColor.systemGray             // System gray
UIColor.systemGray2            // System gray 2
UIColor.systemGray3            // System gray 3
UIColor.systemGray4            // System gray 4
UIColor.systemGray5            // System gray 5
UIColor.systemGray6            // System gray 6
```

### Pre-iOS 13 Fallbacks
```swift
func getAdaptiveBackgroundColor() -> UIColor {
    if #available(iOS 13.0, *) {
        return UIColor.systemBackground
    } else {
        return UIColor.white
    }
}

func getAdaptiveTextColor() -> UIColor {
    if #available(iOS 13.0, *) {
        return UIColor.label
    } else {
        return UIColor.black
    }
}

func getAdaptiveAccentColor() -> UIColor {
    if #available(iOS 13.0, *) {
        return UIColor.systemBlue
    } else {
        return UIColor.blue
    }
}
```

## Component-Specific Adaptive Implementation

### Text Components
```swift
class DCFTextComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let label = UILabel()
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                label.textColor = UIColor.label
                label.backgroundColor = UIColor.clear
            } else {
                label.textColor = UIColor.black
                label.backgroundColor = UIColor.clear
            }
        }
        
        // Apply styles after adaptive theming
        label.applyStyles(props: props)
        
        return label
    }
}
```

### Button Components
```swift
class DCFButtonComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let button = UIButton(type: .system)
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(UIColor.white, for: .normal)
            } else {
                button.backgroundColor = UIColor.blue
                button.setTitleColor(UIColor.white, for: .normal)
            }
        }
        
        button.applyStyles(props: props)
        
        return button
    }
}
```

### Input Components
```swift
class DCFTextInputComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let textField = UITextField()
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                textField.backgroundColor = UIColor.systemBackground
                textField.textColor = UIColor.label
                textField.layer.borderColor = UIColor.systemGray4.cgColor
            } else {
                textField.backgroundColor = UIColor.white
                textField.textColor = UIColor.black
                textField.layer.borderColor = UIColor.lightGray.cgColor
            }
        }
        
        textField.applyStyles(props: props)
        
        return textField
    }
}
```

## Theme Change Detection

### iOS 13+ Automatic Detection
```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    if #available(iOS 13.0, *) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Theme changed - propagate event to Dart
            propagateEvent(on: self, eventName: "onThemeChange", data: [
                "isDarkMode": traitCollection.userInterfaceStyle == .dark,
                "colorScheme": traitCollection.userInterfaceStyle == .dark ? "dark" : "light"
            ])
            
            // Refresh adaptive styling if needed
            refreshAdaptiveColors()
        }
    }
}

func refreshAdaptiveColors() {
    // Update colors that might not automatically refresh
    if let props = getStoredProps() {
        updateView(self, withProps: props)
    }
}
```

### Pre-iOS 13 Manual Detection
```swift
// For older iOS versions, you might need to observe notifications
override func viewDidLoad() {
    super.viewDidLoad()
    
    if #available(iOS 13.0, *) {
        // Automatic handling
    } else {
        // Manual theme detection for older versions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
}

@objc func handleThemeChange() {
    // Manual theme change handling for pre-iOS 13
    propagateEvent(on: self, eventName: "onThemeChange", data: [
        "isDarkMode": false, // Always light mode pre-iOS 13
        "colorScheme": "light"
    ])
}
```

## Dart Theme Handling

### Component Theme Response
```dart
class DCFCustomComponent extends StatelessComponent {
  final bool adaptive;
  final Function(Map<String, dynamic>)? onThemeChange;
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'CustomComponent',
      props: {
        'adaptive': adaptive,
        'onThemeChange': onThemeChange,
        // ... other props
      },
      children: children,
    );
  }
}
```

### App-Level Theme Management
```dart
class ThemeAwareApp extends StatelessComponent {
  final bool isDarkMode;
  final Function(bool)? onThemeChanged;
  
  @override
  DCFComponentNode render() {
    return DCFView(
      adaptive: true,
      events: {
        'onThemeChange': (data) {
          final isDark = data['isDarkMode'] as bool;
          onThemeChanged?.call(isDark);
        },
      },
      children: [
        // Your app content
      ],
    );
  }
}
```

## Custom Adaptive Colors

### Extended Color System
```swift
extension UIColor {
    // Custom adaptive colors
    static var customPrimary: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Lighter blue for dark mode
                default:
                    return UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0) // Darker blue for light mode
                }
            }
        } else {
            return UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        }
    }
    
    static var customSecondary: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                default:
                    return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                }
            }
        } else {
            return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
    }
}
```

### Using Custom Adaptive Colors
```swift
func applyCustomAdaptiveColors(_ view: UIView, props: [String: Any]) {
    let isAdaptive = props["adaptive"] as? Bool ?? true
    
    if isAdaptive {
        view.backgroundColor = UIColor.customPrimary
        view.layer.borderColor = UIColor.customSecondary.cgColor
    }
}
```

## Testing Adaptive Theming

### Force Theme Changes (Debug Only)
```swift
#if DEBUG
func forceThemeChange(to style: UIUserInterfaceStyle) {
    if #available(iOS 13.0, *) {
        view.overrideUserInterfaceStyle = style
    }
}

// Test both themes
forceThemeChange(to: .light)
forceThemeChange(to: .dark)
#endif
```

### Simulator Testing
```swift
// In Simulator, use Device -> Appearance to test themes
// Or programmatically:
#if targetEnvironment(simulator)
if #available(iOS 13.0, *) {
    // Force theme for testing
    UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
}
#endif
```

---

**REQUIREMENT: Every DCFlight component MUST support the adaptive property and automatically adapt to system theme changes.**
