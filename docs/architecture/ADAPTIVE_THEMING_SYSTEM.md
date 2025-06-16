# DCFlight Adaptive Theming System

## 📋 **Overview**

DCFlight implements a comprehensive adaptive theming system that automatically handles light/dark mode transitions and ensures consistent visual appearance across all components. This document outlines the requirements and implementation details for the adaptive theming system.

## 🎯 **Adaptive Flag Requirement**

### **Critical Implementation Rule**

**MANDATORY**: Every DCFlight component **MUST** implement adaptive theming support through the `adaptive` flag:

```swift
func createView(props: [String: Any]) -> UIView {
    let view = YourCustomView()
    
    // ✅ REQUIRED: Check adaptive flag
    let isAdaptive = props["adaptive"] as? Bool ?? true  // Default to true
    
    if isAdaptive {
        // Use system colors that automatically adapt to light/dark mode
        applyAdaptiveColors(view)
    } else {
        // Use explicit colors when adaptive is disabled
        applyNonAdaptiveColors(view)
    }
    
    // Apply StyleSheet properties AFTER adaptive setup
    view.applyStyles(props: props)
    
    return view
}
```

### **Framework-Level Adaptive Control**

The framework can globally disable/enable adaptive theming when needed:

```swift
// Framework-level adaptive control
class DCFThemeManager {
    static var globalAdaptiveEnabled: Bool = true
    
    static func setGlobalAdaptive(_ enabled: Bool) {
        globalAdaptiveEnabled = enabled
        // Notify all components to update their appearance
        NotificationCenter.default.post(name: .DCFThemeChanged, object: nil)
    }
}
```

## 🎨 **System Color Requirements**

### **Required System Colors for Adaptive Components**

**Text Colors:**
```swift
// Primary text (highest contrast)
UIColor.label                    // Black in light mode, white in dark mode

// Secondary text (medium contrast)
UIColor.secondaryLabel           // Gray in light mode, light gray in dark mode

// Tertiary text (lowest contrast)
UIColor.tertiaryLabel            // Light gray in light mode, dark gray in dark mode

// Placeholder text
UIColor.placeholderText          // Light gray with reduced opacity
```

**Background Colors:**
```swift
// Primary background
UIColor.systemBackground         // White in light mode, black in dark mode

// Secondary background (elevated surfaces)
UIColor.secondarySystemBackground // Light gray in light mode, dark gray in dark mode

// Tertiary background (grouped content)
UIColor.tertiarySystemBackground // Very light gray in light mode, darker gray in dark mode
```

**UI Element Colors:**
```swift
// Interactive elements
UIColor.systemBlue              // Primary action color
UIColor.systemGreen             // Success states
UIColor.systemRed               // Error/destructive states
UIColor.systemOrange            // Warning states
UIColor.systemYellow            // Attention states
UIColor.systemPurple            // Secondary actions
UIColor.systemTeal              // Accent color
UIColor.systemIndigo            // Alternative accent

// Neutral colors
UIColor.systemGray              // Neutral elements
UIColor.systemGray2             // Subtle borders
UIColor.systemGray3             // Disabled states
UIColor.systemGray4             // Separator lines
UIColor.systemGray5             // Background tints
UIColor.systemGray6             // Subtle backgrounds
```

**Fill Colors:**
```swift
// Hierarchical fills
UIColor.systemFill              // Primary fill
UIColor.secondarySystemFill     // Secondary fill
UIColor.tertiarySystemFill      // Tertiary fill
UIColor.quaternarySystemFill    // Quaternary fill
```

## 🏗️ **Implementation Patterns**

### **1. Basic Adaptive Implementation**

```swift
class DCFViewComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        
        // Check adaptive flag (defaults to true)
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        if isAdaptive {
            // Use system colors that automatically adapt
            if #available(iOS 13.0, *) {
                view.backgroundColor = UIColor.systemBackground
            } else {
                // Fallback for older iOS versions
                view.backgroundColor = UIColor.white
            }
        } else {
            // Use explicit non-adaptive colors
            view.backgroundColor = UIColor.clear
        }
        
        // Apply StyleSheet properties (may override adaptive colors)
        view.applyStyles(props: props)
        
        return view
    }
}
```

### **2. Complex Adaptive Implementation**

```swift
class DCFButtonComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let button = UIButton(type: .system)
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        if isAdaptive {
            // Adaptive button styling
            if #available(iOS 13.0, *) {
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(UIColor.white, for: .normal)
                button.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                // iOS 12 fallback
                button.backgroundColor = UIColor.blue
                button.setTitleColor(UIColor.white, for: .normal)
                button.layer.borderColor = UIColor.blue.cgColor
            }
        } else {
            // Non-adaptive explicit styling
            button.backgroundColor = UIColor.clear
            button.setTitleColor(UIColor.black, for: .normal)
        }
        
        updateView(button, withProps: props)
        return button
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let button = view as? UIButton else { return false }
        
        // Handle component-specific props
        if let title = props["title"] as? String {
            button.setTitle(title, for: .normal)
        }
        
        if let disabled = props["disabled"] as? Bool {
            button.isEnabled = !disabled
            button.alpha = disabled ? 0.5 : 1.0
        }
        
        // Apply StyleSheet properties LAST (may override adaptive styling)
        button.applyStyles(props: props)
        
        return true
    }
}
```

### **3. Text Component Adaptive Implementation**

```swift
class DCFTextComponent: NSObject, DCFComponent {
    func createView(props: [String: Any]) -> UIView {
        let label = UILabel()
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        if isAdaptive {
            // Adaptive text styling
            if #available(iOS 13.0, *) {
                label.textColor = UIColor.label              // Primary text
                label.backgroundColor = UIColor.clear         // Transparent background
            } else {
                label.textColor = UIColor.black
                label.backgroundColor = UIColor.clear
            }
        } else {
            // Non-adaptive explicit styling
            label.textColor = UIColor.black
            label.backgroundColor = UIColor.clear
        }
        
        updateView(label, withProps: props)
        return label
    }
}
```

## 🔧 **StyleSheet Integration**

### **Adaptive Color Override Behavior**

When StyleSheet properties are applied, they can override adaptive colors:

```swift
// Component sets adaptive background
view.backgroundColor = UIColor.systemBackground  // Adaptive

// StyleSheet can override with explicit color
view.applyStyles(props: [
    "backgroundColor": "#FF0000"  // Explicit red overrides adaptive
])
```

### **Preserving Adaptive Behavior**

Components can check if StyleSheet props contain explicit colors:

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    let isAdaptive = props["adaptive"] as? Bool ?? true
    
    // Only apply adaptive colors if no explicit color is provided
    if isAdaptive && props["backgroundColor"] == nil {
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
        }
    }
    
    // Apply StyleSheet properties
    view.applyStyles(props: props)
    
    return true
}
```

## 🌓 **Dark Mode Support**

### **Automatic Dark Mode Handling**

System colors automatically handle dark mode transitions:

```swift
// These colors automatically adapt to dark mode
if #available(iOS 13.0, *) {
    view.backgroundColor = UIColor.systemBackground     // White → Black
    label.textColor = UIColor.label                     // Black → White
    button.backgroundColor = UIColor.systemBlue         // Blue → Dark Blue
}
```

### **Manual Dark Mode Detection**

For components that need custom dark mode behavior:

```swift
func applyAdaptiveColors(_ view: UIView) {
    if #available(iOS 13.0, *) {
        // Use trait collection to detect dark mode
        let isDarkMode = view.traitCollection.userInterfaceStyle == .dark
        
        if isDarkMode {
            // Custom dark mode styling
            view.layer.borderColor = UIColor.white.cgColor
        } else {
            // Custom light mode styling
            view.layer.borderColor = UIColor.black.cgColor
        }
    }
}
```

### **Trait Collection Updates**

Handle trait collection changes for real-time updates:

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    if #available(iOS 13.0, *) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors when appearance changes
            updateAdaptiveColors()
        }
    }
}
```

## 🛡️ **Compliance Requirements**

### **Mandatory Implementation Checklist**

- [ ] ✅ Component checks `adaptive` flag in `createView`
- [ ] ✅ Defaults `adaptive` to `true` when not specified
- [ ] ✅ Uses system colors for adaptive mode (`UIColor.systemBackground`, `UIColor.label`, etc.)
- [ ] ✅ Provides fallback colors for iOS < 13.0
- [ ] ✅ Applies `view.applyStyles(props: props)` AFTER adaptive setup
- [ ] ✅ Handles non-adaptive mode with explicit colors
- [ ] ✅ Component-specific props processed before StyleSheet application

### **Non-Compliance Consequences**

**Failure to implement adaptive theming results in:**
- ❌ Module merge request rejection
- ❌ Poor user experience in dark mode
- ❌ Inconsistent visual appearance
- ❌ Framework ecosystem fragmentation

## 🎯 **Testing Adaptive Implementation**

### **Manual Testing Steps**

1. **Light Mode Test:**
   ```swift
   let props: [String: Any] = ["adaptive": true]
   let view = component.createView(props: props)
   // Verify light mode colors are applied
   ```

2. **Dark Mode Test:**
   ```swift
   // Switch to dark mode in iOS Settings or Simulator
   let props: [String: Any] = ["adaptive": true]
   let view = component.createView(props: props)
   // Verify dark mode colors are applied automatically
   ```

3. **Non-Adaptive Test:**
   ```swift
   let props: [String: Any] = ["adaptive": false]
   let view = component.createView(props: props)
   // Verify explicit colors are used regardless of system appearance
   ```

### **Automated Testing**

```swift
func testAdaptiveColors() {
    let component = YourComponent()
    
    // Test adaptive mode
    let adaptiveProps: [String: Any] = ["adaptive": true]
    let adaptiveView = component.createView(props: adaptiveProps)
    
    if #available(iOS 13.0, *) {
        XCTAssertEqual(adaptiveView.backgroundColor, UIColor.systemBackground)
    }
    
    // Test non-adaptive mode
    let nonAdaptiveProps: [String: Any] = ["adaptive": false]
    let nonAdaptiveView = component.createView(props: nonAdaptiveProps)
    
    XCTAssertNotEqual(nonAdaptiveView.backgroundColor, UIColor.systemBackground)
}
```

## 🚀 **Benefits of Adaptive Theming**

### **User Experience Benefits**
- ✅ Seamless light/dark mode transitions
- ✅ Consistent system integration
- ✅ Reduced eye strain in dark environments
- ✅ Better accessibility compliance

### **Developer Benefits**
- ✅ Automatic color management
- ✅ Consistent theming across components
- ✅ Reduced manual color configuration
- ✅ Future-proof color handling

### **Framework Benefits**
- ✅ Professional appearance
- ✅ System integration
- ✅ Accessibility compliance
- ✅ User satisfaction

## 📞 **Framework-Level Control**

### **Global Adaptive Override**

The framework reserves the right to globally control adaptive behavior:

```swift
// Framework can disable adaptive theming globally
DCFThemeManager.setGlobalAdaptive(false)

// This affects all components that check the global setting
func createView(props: [String: Any]) -> UIView {
    let isAdaptive = (props["adaptive"] as? Bool ?? true) && DCFThemeManager.globalAdaptiveEnabled
    
    // Apply adaptive or non-adaptive styling based on combined flags
    if isAdaptive {
        applyAdaptiveColors(view)
    } else {
        applyNonAdaptiveColors(view)
    }
}
```

This adaptive theming system ensures that DCFlight provides a modern, accessible, and visually consistent experience across all lighting conditions and user preferences.
