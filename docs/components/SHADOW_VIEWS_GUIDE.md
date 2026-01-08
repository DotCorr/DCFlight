# Shadow Views Guide

This guide explains what shadow views are, when you need to create custom shadow views, and how to implement them.

## What Are Shadow Views?

Shadow views are the layout representation of components in the Yoga layout engine. They form a shadow tree that mirrors your component hierarchy, allowing Yoga to calculate layout without touching the actual native views.

**Key Concept:** Every component has a shadow view, but most use the base `DCFShadowView` class. Only components with special layout needs require custom shadow view subclasses.

## Shadow View Hierarchy

```
DCFShadowView (base class)
├── DCFRootShadowView (for screen roots)
├── DCFTextShadowView (for Text components)
└── DCFScrollContentShadowView (for ScrollContentView)
```

## When Do You Need a Custom Shadow View?

**Most components DON'T need a custom shadow view.** The base `DCFShadowView` handles:
- Standard flexbox layout
- Margin, padding, border properties
- Position and size calculations
- Child layout propagation

**You only need a custom shadow view if your component needs:**

### 1. Custom Measurement Logic

**Example: Text Component**

Text components need custom measurement because:
- Text size depends on content and available width
- Must account for padding when measuring
- Requires `NSLayoutManager`/`NSTextContainer` for accurate measurement
- Text properties (font, line height, letter spacing) affect measurement

```swift
// DCFTextShadowView.swift
open class DCFTextShadowView: DCFShadowView {
    // Custom measure function that accounts for padding
    private static let textMeasureFunction: YGMeasureFunc = { (node, width, widthMode, height, heightMode) -> YGSize in
        // Get shadow view from context
        guard let context = YGNodeGetContext(node) else {
            return YGSize(width: 0, height: 0)
        }
        let shadowView = Unmanaged<DCFTextShadowView>.fromOpaque(context).takeUnretainedValue()
        return shadowView.measureText(node: node, width: width, widthMode: widthMode, height: height, heightMode: heightMode)
    }
    
    private func measureText(...) -> YGSize {
        // Account for padding
        let padding = self.paddingAsInsets
        let availableWidth = max(0, CGFloat(width) - (padding.left + padding.right))
        
        // Use NSLayoutManager for accurate text measurement
        let textStorage = buildTextStorageForWidth(availableWidth, widthMode: widthMode)
        // ... measurement logic
    }
}
```

**When to use:** If your component's size depends on content that requires special measurement (text, images with aspect ratios, etc.)

### 2. Custom Layout Behavior

**Example: ScrollContentView**

ScrollContentView needs custom layout behavior because:
- Yoga positions content incorrectly in RTL layouts
- Needs to compensate for RTL positioning
- Must override `applyLayoutNode` to fix positioning

```swift
// DCFScrollContentShadowView.swift
public class DCFScrollContentShadowView: DCFShadowView {
    public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        // Compensate for RTL layout issues
        if effectiveLayoutDirection == .leftToRight {
            super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
            return
        }
        
        // RTL compensation logic
        var newAbsolutePosition = absolutePosition
        let xCompensation = CGFloat(YGNodeLayoutGetRight(node) - YGNodeLayoutGetLeft(node))
        newAbsolutePosition.x += xCompensation
        
        super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: newAbsolutePosition)
        
        // Reset position
        let roundedRight = round(CGFloat(YGNodeLayoutGetRight(node)) * UIScreen.main.scale) / UIScreen.main.scale
        frame.origin.x = roundedRight
    }
}
```

**When to use:** If your component needs to override how layout is applied (RTL fixes, special positioning, etc.)

### 3. Custom Text Storage and Rendering

**Example: Text Component (Advanced)**

Text components also build `NSTextStorage` during layout for rendering:

```swift
public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
    // Call super to handle frame calculation
    super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
    
    // Build text storage and calculate text frame for rendering
    let padding = self.paddingAsInsets
    let width = self.frame.size.width - (padding.left + padding.right)
    
    let textStorage = buildTextStorageForWidth(width, widthMode: .exactly)
    let textFrame = calculateTextFrame(textStorage: textStorage)
    
    // Store for use by DCFTextComponent.applyLayout
    computedTextStorage = textStorage
    computedTextFrame = textFrame
    computedContentInset = padding
}
```

**When to use:** If your component needs to prepare rendering data during layout (text storage, image processing, etc.)

## How Shadow Views Are Created

Shadow views are created automatically by `YogaShadowTree` when components are registered:

```swift
// YogaShadowTree.swift
func createNode(id: String, componentType: String) {
    let shadowView: DCFShadowView
    if componentType == "ScrollContentView" {
        shadowView = DCFScrollContentShadowView(viewId: viewId)
    } else if componentType == "Text" {
        shadowView = DCFTextShadowView(viewId: viewId)
    } else {
        shadowView = DCFShadowView(viewId: viewId)  // Base class for all others
    }
    
    shadowViewRegistry[viewId] = shadowView
}
```

**You don't manually create shadow views** - the framework creates them automatically based on component type.

## Creating a Custom Shadow View

### Step 1: Create the Shadow View Class

**iOS:**

```swift
// MyComponentShadowView.swift
import UIKit
import yoga
import dcflight

public class MyComponentShadowView: DCFShadowView {
    // Custom properties if needed
    public var customProperty: String = ""
    
    public required init(viewId: Int) {
        super.init(viewId: viewId)
        
        // Set up custom measure function if needed
        // YGNodeSetMeasureFunc(self.yogaNode, myMeasureFunction)
    }
    
    // Override methods as needed
    public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        // Custom layout logic
        super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
    }
}
```

**Android:**

Android doesn't have explicit shadow view classes - the framework handles shadow views internally. Custom measurement is handled automatically by the framework based on component behavior.

### Step 2: Register Shadow View Type

**iOS:**

Update `YogaShadowTree.createNode` to use your custom shadow view:

```swift
// YogaShadowTree.swift
func createNode(id: String, componentType: String) {
    let shadowView: DCFShadowView
    if componentType == "ScrollContentView" {
        shadowView = DCFScrollContentShadowView(viewId: viewId)
    } else if componentType == "Text" {
        shadowView = DCFTextShadowView(viewId: viewId)
    } else if componentType == "MyComponent" {
        shadowView = MyComponentShadowView(viewId: viewId)  // Your custom shadow view
    } else {
        shadowView = DCFShadowView(viewId: viewId)
    }
    
    shadowViewRegistry[viewId] = shadowView
}
```

### Step 3: Implement Custom Behavior

Override methods as needed:

- **`measureText`** - Custom measurement logic
- **`applyLayoutNode`** - Custom layout application
- **`buildTextStorageForWidth`** - Text storage building (for text components)
- **`calculateTextFrame`** - Text frame calculation (for text components)

## Common Patterns

### Pattern 1: Custom Measurement

```swift
public class MyComponentShadowView: DCFShadowView {
    private static let measureFunction: YGMeasureFunc = { (node, width, widthMode, height, heightMode) -> YGSize in
        guard let context = YGNodeGetContext(node) else {
            return YGSize(width: 0, height: 0)
        }
        let shadowView = Unmanaged<MyComponentShadowView>.fromOpaque(context).takeUnretainedValue()
        return shadowView.measure(node: node, width: width, widthMode: widthMode, height: height, heightMode: heightMode)
    }
    
    public required init(viewId: Int) {
        super.init(viewId: viewId)
        YGNodeSetMeasureFunc(self.yogaNode, Self.measureFunction)
    }
    
    private func measure(...) -> YGSize {
        // Custom measurement logic
        return YGSize(width: calculatedWidth, height: calculatedHeight)
    }
}
```

### Pattern 2: Custom Layout Application

```swift
public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
    // Do custom preprocessing
    let customPosition = adjustPosition(absolutePosition)
    
    // Call super with adjusted position
    super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: customPosition)
    
    // Do custom postprocessing
    adjustFrameAfterLayout()
}
```

### Pattern 3: Text Storage Building

```swift
private func buildTextStorageForWidth(_ width: CGFloat, widthMode: YGMeasureMode) -> NSTextStorage {
    // Check cache
    if let cached = _cachedTextStorage,
       width == _cachedTextStorageWidth,
       widthMode == _cachedTextStorageWidthMode {
        return cached
    }
    
    // Build attributed string
    let attributedString = buildAttributedString()
    
    // Create text storage with layout manager
    let textStorage = NSTextStorage(attributedString: attributedString)
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    
    // Create text container
    let textContainer = NSTextContainer()
    textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    layoutManager.addTextContainer(textContainer)
    layoutManager.ensureLayout(for: textContainer)
    
    // Cache result
    _cachedTextStorage = textStorage
    _cachedTextStorageWidth = width
    _cachedTextStorageWidthMode = widthMode
    
    return textStorage
}
```

## When NOT to Create a Custom Shadow View

**Don't create a custom shadow view for:**

- ✅ Standard flexbox layout (base `DCFShadowView` handles this)
- ✅ Margin, padding, border (base class handles this)
- ✅ Simple components (View, Button, Image, etc.)
- ✅ Components with fixed or intrinsic sizes
- ✅ Components that size based on children

**The base `DCFShadowView` handles all standard layout needs.**

## Shadow View Lifecycle

1. **Creation** - Created by `YogaShadowTree.createNode` when component is registered
2. **Props Update** - `didSetProps` called when props change
3. **Layout Calculation** - Yoga calculates layout using shadow view tree
4. **Layout Application** - `applyLayoutNode` called to apply calculated layout
5. **Cleanup** - Shadow view deallocated when component is removed

## Best Practices

1. **Only create custom shadow views when necessary** - Most components don't need them
2. **Reuse base class functionality** - Call `super` methods when overriding
3. **Cache expensive computations** - Text storage, measurements, etc.
4. **Handle edge cases** - Zero sizes, invalid inputs, etc.
5. **Document why** - Explain why your component needs a custom shadow view

## Examples

### Text Component

**Why:** Needs custom measurement for text wrapping and accurate sizing

**Key Features:**
- Custom measure function using `NSLayoutManager`
- Accounts for padding in measurement
- Builds text storage for rendering
- Calculates text frame with padding

### ScrollContentView

**Why:** Needs RTL layout compensation

**Key Features:**
- Overrides `applyLayoutNode` for RTL fixes
- Compensates for Yoga's RTL positioning bug
- Maintains column layout direction

## Summary

- **Most components use base `DCFShadowView`** - No custom shadow view needed
- **Custom shadow views only for special cases:**
  - Custom measurement (Text)
  - Custom layout behavior (ScrollContentView)
  - Text storage building (Text)
- **Framework creates shadow views automatically** - You just register the type
- **Override methods as needed** - Call `super` to reuse base functionality

## Next Steps

- [Component Protocol](./COMPONENT_PROTOCOL.md) - Component implementation guide
- [Component Conventions](./COMPONENT_CONVENTIONS.md) - Component requirements
- [Registry System](./REGISTRY_SYSTEM.md) - Component registration

