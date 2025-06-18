# Presentable Components Development Guide

## Overview

Presentable components are UI elements that appear outside the normal view hierarchy, such as modals, popovers, alerts, bottom sheets, and tooltips. This guide shows how to implement these components following the established patterns in DCFlight.

## Core Pattern for Presentable Components

### 1. **Placeholder View Pattern**

All presentable components use a "placeholder view" that acts as an anchor in the main UI while the actual content is presented elsewhere.

```swift
func createView(props: [String: Any]) -> UIView {
    // Create a simple placeholder view
    let view = UIView()
    
    // Set the view as hidden but don't override its geometry
    view.isHidden = true
    view.backgroundColor = UIColor.clear
    view.isUserInteractionEnabled = false
    
    let _ = updateView(view, withProps: props)
    return view
}
```

**Key Points:**
- Placeholder is hidden from main UI (`isHidden = true`)
- Clear background and no user interaction
- Serves as container for children when not presented

### 2. **Visibility Management Pattern**

Handle visibility state with proper type checking:

```swift
func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    // Check if component should be visible (handle multiple types)
    var isVisible = false
    if let visible = props["visible"] as? Bool {
        isVisible = visible
    } else if let visible = props["visible"] as? Int {
        isVisible = visible == 1
    } else if let visible = props["visible"] as? NSNumber {
        isVisible = visible.boolValue
    }
    
    if isVisible {
        presentContent(from: view, props: props)
    } else {
        dismissContent(from: view)
    }
    
    view.applyStyles(props: props)
    return true
}
```

### 3. **Child Management Pattern**

Implement proper child storage and movement:

```swift
func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
    // Store children in placeholder but keep them hidden from main UI
    view.subviews.forEach { $0.removeFromSuperview() }
    childViews.forEach { childView in
        view.addSubview(childView)
        // Hide children in placeholder view (they'll be shown when moved to presented content)
        childView.isHidden = true
        childView.alpha = 0.0
    }
    
    // If content is currently presented, move children to presented view
    if let presentedView = getCurrentPresentedView(for: viewId) {
        addChildrenToPresentedContent(presentedView: presentedView, childViews: childViews)
    }
    
    return true
}
```

### 4. **Content Layout Pattern**

Give full control to the abstraction layer:

```swift
private func addChildrenToPresentedContent(presentedView: UIView, childViews: [UIView]) {
    // Clear existing content children
    presentedView.subviews.forEach { subview in
        // Don't remove system views (keep platform chrome)
        if subview.tag != 999 && subview.tag != 998 {
            subview.removeFromSuperview()
        }
    }
    
    let availableFrame = presentedView.bounds
    
    if childViews.count == 1, let childView = childViews.first {
        // Single child gets full space
        childView.removeFromSuperview()
        childView.translatesAutoresizingMaskIntoConstraints = true
        presentedView.addSubview(childView)
        
        // Make visible and give full frame
        childView.isHidden = false
        childView.alpha = 1.0
        childView.frame = CGRect(
            x: 0, y: 0,
            width: availableFrame.width,
            height: availableFrame.height
        )
    } else {
        // Multiple children - stack or arrange as appropriate
        layoutMultipleChildren(childViews, in: presentedView, availableFrame: availableFrame)
    }
}
```

## Implementation Examples

### Modal Component Pattern

```swift
class DCFModalComponent: NSObject, DCFComponent {
    static var presentedModals: [String: DCFModalViewController] = [:]
    
    // ... standard createView, updateView, setChildren methods ...
    
    private func presentModal(from view: UIView, props: [String: Any], viewId: String) {
        let modalVC = DCFModalViewController()
        modalVC.modalProps = props
        modalVC.sourceView = view
        modalVC.viewId = viewId
        
        // Configure modal presentation style
        configureModalPresentation(modalVC, props: props)
        
        // Store reference before presenting
        DCFModalComponent.presentedModals[viewId] = modalVC
        
        // Present modal
        if let topViewController = getTopViewController() {
            topViewController.present(modalVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
}
```

### Popover Component Pattern

```swift
class DCFPopoverComponent: NSObject, DCFComponent {
    static var presentedPopovers: [String: UIPopoverPresentationController] = [:]
    
    private func presentPopover(from view: UIView, props: [String: Any], viewId: String) {
        let popoverContentVC = UIViewController()
        popoverContentVC.modalPresentationStyle = .popover
        
        guard let popoverController = popoverContentVC.popoverPresentationController else {
            return
        }
        
        // Configure popover anchor
        popoverController.sourceView = view.superview ?? view
        popoverController.sourceRect = view.frame
        
        // Configure popover properties
        configurePopoverProperties(popoverController, props: props)
        
        // Present popover
        if let topViewController = getTopViewController() {
            topViewController.present(popoverContentVC, animated: true)
        }
    }
}
```

### Alert Component Pattern

```swift
class DCFAlertComponent: NSObject, DCFComponent {
    private func presentAlert(from view: UIView, props: [String: Any]) {
        let title = props["title"] as? String
        let message = props["message"] as? String
        let alertStyle = parseAlertStyle(props["style"] as? String)
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
        
        // Add actions if specified
        if let actions = props["actions"] as? [[String: Any]] {
            for actionProps in actions {
                let action = createAlertAction(from: actionProps, sourceView: view)
                alertController.addAction(action)
            }
        }
        
        // Present alert
        if let topViewController = getTopViewController() {
            topViewController.present(alertController, animated: true)
        }
    }
}
```

## Dart Side Implementation Pattern

### Component Structure

```dart
class DCFYourPresentable extends StatelessComponent {
  final bool visible;
  final Function(Map<dynamic, dynamic>)? onShow;
  final Function(Map<dynamic, dynamic>)? onDismiss;
  final List<DCFComponentNode> children;
  final LayoutProps layout;
  final StyleSheet style;
  
  // Component-specific props
  final String? customProperty;
  
  DCFYourPresentable({
    super.key,
    required this.visible,
    this.onShow,
    this.onDismiss,
    this.children = const [],
    this.layout = const LayoutProps(),
    this.style = const StyleSheet(),
    this.customProperty,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = {};
    
    if (onShow != null) eventMap['onShow'] = onShow;
    if (onDismiss != null) eventMap['onDismiss'] = onDismiss;
    
    Map<String, dynamic> props = {
      'visible': visible,
      'customProperty': customProperty,
      ...layout.toMap(),
      ...style.toMap(),
      ...eventMap,
    };
    
    // 🔥 CRITICAL: Always enforce display property based on visibility
    props['display'] = visible ? 'flex' : 'none';
    
    return DCFElement(
      type: 'YourPresentable',
      props: props,
      children: children,
    );
  }
}
```

### Display Property Pattern

**Critical Implementation Detail:** Always set the display property based on visibility to ensure proper hiding behavior:

```dart
// 🔥 CRITICAL FIX: Always enforce display property based on visibility
// This ensures style.toMap() cannot override the visibility-based display setting
props['display'] = visible ? 'flex' : 'none';
```

This pattern ensures:
- `visible: false` → `display: 'none'` → Component completely hidden from layout
- `visible: true` → `display: 'flex'` → Component properly presented

## Component-Specific Considerations

### Modals
- Use `UIModalPresentationController` or sheet presentation
- Support detents for iOS 15+ sheet modals
- Handle user dismissal gestures properly
- Manage child visibility during drag gestures

### Popovers
- Use `UIPopoverPresentationController`
- Configure anchor point and arrow direction
- Size content based on children or specified dimensions
- Handle iPad vs iPhone behavior differences

### Alerts
- Use `UIAlertController`
- Support different alert styles (alert, actionSheet)
- Add actions and text fields as needed
- Handle alert-specific sizing and presentation

### Bottom Sheets
- Can use modal with custom detents
- Or implement custom presentation controller
- Handle drag gestures and snap points
- Consider safe area insets

### Tooltips
- Use popover with tooltip styling
- Auto-dismiss on outside tap
- Position relative to anchor element
- Keep content concise and readable

## Best Practices

### 1. **Consistent Event Handling**
```swift
// Always propagate events at appropriate times
topViewController.present(presentedController, animated: true) {
    propagateEvent(on: view, eventName: "onShow", data: [:])
}

// Handle dismissal events
presentedController.dismiss(animated: true) {
    propagateEvent(on: view, eventName: "onDismiss", data: [:])
}
```

### 2. **Proper Memory Management**
```swift
// Track presented instances
static var presentedInstances: [String: YourPresentationType] = [:]

// Store reference before presenting
presentedInstances[viewId] = presentedInstance

// Remove reference when dismissed
presentedInstances.removeValue(forKey: viewId)
```

### 3. **Graceful Fallbacks**
```swift
// Always check for top view controller
guard let topViewController = getTopViewController() else {
    print("❌ Could not find view controller to present from")
    return
}

// Handle presentation failures
topViewController.present(presentedController, animated: true) {
    // Success callback
} catch {
    // Remove from tracking if presentation failed
    presentedInstances.removeValue(forKey: viewId)
}
```

### 4. **Platform Version Handling**
```swift
// Use availability checks for new features
if #available(iOS 15.0, *) {
    modalVC.modalPresentationStyle = .pageSheet
    // Configure sheet detents
} else {
    // Fallback for older iOS versions
    modalVC.modalPresentationStyle = .formSheet
}
```

## Testing Checklist

When implementing a new presentable component:

- [ ] `visible: false` properly hides content (display: none behavior)
- [ ] `visible: true` presents content with children visible
- [ ] Children are invisible in placeholder, visible when presented
- [ ] Dismissal moves children back to placeholder correctly
- [ ] Events (onShow, onDismiss) fire at correct times
- [ ] Multiple show/hide cycles work correctly
- [ ] User dismissal (tap outside, gestures) handled properly
- [ ] Platform-specific features work as expected
- [ ] Memory management (no leaks when dismissed)
- [ ] Accessibility features work correctly
- [ ] Different child counts and layouts work properly

## Common Pitfalls to Avoid

1. **Don't** move children during dismissal animations - wait for completion
2. **Don't** override the display property after setting it based on visibility
3. **Don't** assume a specific view controller hierarchy - always find the top controller
4. **Don't** forget to remove tracking references when dismissing
5. **Don't** add system-specific padding/margins - let abstraction layer control layout
6. **Don't** forget to handle both programmatic and user-initiated dismissals
7. **Don't** ignore platform version differences - always provide fallbacks

## Future Enhancements

Consider these patterns for advanced features:

- **Animation Control**: Custom transition animations
- **Focus Management**: Automatic focus handling for accessibility
- **State Persistence**: Maintaining state across presentations
- **Multi-Instance Support**: Multiple simultaneous presentations
- **Custom Anchoring**: More flexible positioning options
- **Responsive Behavior**: Adaptive sizing based on content and screen size
