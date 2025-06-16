# DCFlight Component Protocol - Swift Native Components

## Overview

This document outlines the essential protocol for creating Swift native components in DCFlight to ensure proper prop handling, state preservation, and efficient VDOM reconciliation.

## The Golden Rule: Only Update What's Explicitly Requested

**CRITICAL**: Your native component should **ONLY** modify properties that are explicitly provided in the props dictionary. Never apply default values or reset properties that aren't specified in the current props update.

## Why This Matters

The DCFlight VDOM system uses efficient diffing - it only sends changed props to native components. If your native component applies defaults or resets unspecified properties, it will interfere with:
- State preservation during updates
- User expectations of iOS system defaults
- Performance optimizations
- Predictable component behavior

## Component Protocol Guidelines

### 1. Leaf Components (Text, Image, etc.)

Leaf components represent terminal UI elements that don't contain other components.

#### ✅ CORRECT Implementation

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let label = view as? UILabel else { return false }
    
    // ✅ Only update content if specified
    if let content = props["content"] as? String {
        label.text = content
    }
    
    // ✅ Only update font properties if they're explicitly provided
    var shouldUpdateFont = false
    var fontSize: CGFloat?
    var fontWeight: UIFont.Weight?
    var fontFamily: String?
    
    if let fontSizeValue = props["fontSize"] as? CGFloat {
        fontSize = fontSizeValue
        shouldUpdateFont = true
    }
    
    if let fontWeightString = props["fontWeight"] as? String {
        fontWeight = fontWeightFromString(fontWeightString)
        shouldUpdateFont = true
    }
    
    if let fontFamilyValue = props["fontFamily"] as? String {
        fontFamily = fontFamilyValue
        shouldUpdateFont = true
    }
    
    // ✅ Only rebuild font if at least one font property was specified
    if shouldUpdateFont {
        let currentFont = label.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
        let finalFontSize = fontSize ?? currentFont.pointSize
        let finalFontWeight = fontWeight ?? .regular
        
        // Apply font changes...
        label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
    }
    
    // ✅ Only update color if specified
    if let color = props["color"] as? String {
        label.textColor = ColorUtilities.color(fromHexString: color)
    }
    
    return true
}
```

#### ❌ INCORRECT Implementation

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let label = view as? UILabel else { return false }
    
    // ❌ Always setting content even if not provided
    label.text = props["content"] as? String ?? ""
    
    // ❌ Always applying font properties with defaults
    let fontSize = props["fontSize"] as? CGFloat ?? 16.0  // DON'T DO THIS
    let fontWeight = fontWeightFromString(props["fontWeight"] as? String ?? "regular")  // DON'T DO THIS
    label.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
    
    // ❌ Always resetting color
    label.textColor = ColorUtilities.color(fromHexString: props["color"] as? String ?? "#000000")  // DON'T DO THIS
    
    return true
}
```

### 2. Parent Components (Container, Stack, etc.)

Parent components manage layout and contain child components.

#### ✅ CORRECT Implementation

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    guard let stackView = view as? UIStackView else { return false }
    
    // ✅ Only update spacing if specified
    if let spacing = props["spacing"] as? CGFloat {
        stackView.spacing = spacing
    }
    
    // ✅ Only update axis if specified
    if let direction = props["direction"] as? String {
        stackView.axis = direction == "horizontal" ? .horizontal : .vertical
    }
    
    // ✅ Only update alignment if specified
    if let alignment = props["alignment"] as? String {
        switch alignment {
        case "center":
            stackView.alignment = .center
        case "leading":
            stackView.alignment = .leading
        case "trailing":
            stackView.alignment = .trailing
        default:
            stackView.alignment = .fill
        }
    }
    
    // ✅ Handle child components through VDOM (don't manage manually)
    
    return true
}
```

### 3. Initial View Creation

Use minimal defaults in `createView` - let the system provide natural defaults.

#### ✅ CORRECT Initial Setup

```swift
func createView(props: [String: Any]) -> UIView {
    let label = UILabel()
    
    // ✅ Only set essential defaults that users expect
    label.numberOfLines = 0  // Allow multiline by default
    // ✅ Let iOS provide natural font and color defaults
    
    // ✅ Apply initial props
    updateView(label, withProps: props)
    
    return label
}
```

#### ❌ INCORRECT Initial Setup

```swift
func createView(props: [String: Any]) -> UIView {
    let label = UILabel()
    
    // ❌ Setting unnecessary defaults
    label.font = UIFont.systemFont(ofSize: 16)  // DON'T DO THIS
    label.textColor = UIColor.black  // DON'T DO THIS
    label.textAlignment = .left  // DON'T DO THIS
    
    updateView(label, withProps: props)
    return label
}
```

## Common Anti-Patterns to Avoid

### 1. ❌ Always Applying Defaults
```swift
// DON'T DO THIS
let fontSize = props["fontSize"] as? CGFloat ?? 16.0
```

### 2. ❌ Resetting Unspecified Properties
```swift
// DON'T DO THIS
if props["color"] == nil {
    label.textColor = UIColor.black
}
```

### 3. ❌ Forcing Property Updates
```swift
// DON'T DO THIS - always rebuilding font
label.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
```

### 4. ❌ Managing Child Components Manually
```swift
// DON'T DO THIS - let VDOM handle children
stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
```

## Testing Your Component

### Test Case 1: Initial Creation
```swift
// Should use iOS system defaults
let label = component.createView(props: [:])
// label.font should be system default
// label.textColor should be system default
```

### Test Case 2: Partial Updates
```swift
// Should only change specified properties
component.updateView(label, withProps: ["content": "Hello"])
// Only text should change, font/color should remain unchanged
```

### Test Case 3: State Changes
```swift
// Should preserve all existing properties
component.updateView(label, withProps: ["content": "New text"])
// Font, color, alignment should all remain exactly the same
```

## Summary

Following this protocol ensures:
- ✅ Efficient VDOM reconciliation
- ✅ Predictable component behavior  
- ✅ Proper state preservation
- ✅ Respect for iOS system defaults
- ✅ No unexpected property resets
- ✅ Better performance through minimal updates

Remember: **Your component is a thin bridge between DCFlight props and native iOS views. Don't add your own opinions about defaults - let the VDOM and iOS system handle what they do best.**
