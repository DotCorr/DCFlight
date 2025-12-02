# iOS View Controller Systems

This document describes the view controller wrapper and layout guide systems that ensure proper integration between DCFlight-managed views and iOS's view controller hierarchy.

## Overview

DCFlight uses several interconnected systems to handle iOS-specific layout concerns:

1. **DCFWrapperViewController** - Wraps content views in view controllers
2. **DCFViewControllerProtocol** - Protocol for caching layout guides
3. **DCFAutoInsetsProtocol** - Protocol for automatic content inset adjustment
4. **UIView+DCFLayoutGuides** - Utilities for finding view controllers and calculating insets

These systems work together to ensure that:
- Views can access layout guides (safe areas) at any time
- Scroll views automatically adjust content insets when layout guides change
- Navigation controllers don't interfere with DCFlight's layout system
- Content is properly positioned relative to safe areas (notches, status bars, etc.)

---

## DCFWrapperViewController

### Purpose

`DCFWrapperViewController` wraps DCFlight-managed views in a `UIViewController`. This is essential for:

1. **Layout Guide Caching** - Provides stable access to `topLayoutGuide` and `bottomLayoutGuide` even when views are being laid out
2. **Scroll View Inset Management** - Automatically refreshes scroll view content insets when layout guides change (e.g., navigation bar height changes, device rotation)
3. **Frame Protection** - Prevents `UINavigationController` from resetting frames for DCFlight-managed views
4. **Navigation Integration** - Enables proper integration with iOS navigation and tab bar controllers

### Usage

Used automatically by the screen system for:
- **Navigation screens** - Each screen in a navigation stack
- **Tab screens** - Each tab in a tab bar controller

### Implementation Details

```swift
@objc public class DCFWrapperViewController: UIViewController, DCFViewControllerProtocol {
    private var _wrapperView: UIView?
    private var _contentView: UIView
    
    // Caches layout guides via DCFViewControllerProtocol
    @objc public var currentTopLayoutGuide: UILayoutSupport
    @objc public var currentBottomLayoutGuide: UILayoutSupport
}
```

**Key Behaviors:**

1. **Layout Guide Monitoring** - In `viewDidLayoutSubviews()`, monitors changes to layout guide lengths and refreshes scroll view insets when they change
2. **Wrapper View** - Uses a wrapper view to prevent navigation controllers from interfering with DCFlight-managed view frames
3. **Scroll View Discovery** - Recursively searches for scroll views implementing `DCFAutoInsetsProtocol` and refreshes their insets

---

## DCFViewControllerProtocol

### Purpose

Protocol that view controllers implement to provide cached access to layout guides. This ensures views can access layout guide information at any time, even during layout calculations.

### Definition

```swift
@objc public protocol DCFViewControllerProtocol: NSObjectProtocol {
    @objc var currentTopLayoutGuide: UILayoutSupport { get }
    @objc var currentBottomLayoutGuide: UILayoutSupport { get }
}
```

### Why It's Needed

iOS's `topLayoutGuide` and `bottomLayoutGuide` are only available during certain lifecycle methods. By caching them through this protocol, views can access layout guide information at any time, which is essential for:
- Calculating content insets for scroll views
- Positioning content relative to safe areas
- Handling layout guide changes (rotation, navigation bar appearance, etc.)

---

## DCFAutoInsetsProtocol

### Purpose

Protocol for views that want to support automatic content inset adjustment based on layout guides. This is primarily used by `DCFScrollView` to automatically adjust content insets when:
- Navigation bar height changes
- Device rotates
- Safe area insets change
- Layout guides are updated

### Definition

```swift
@objc public protocol DCFAutoInsetsProtocol: NSObjectProtocol {
    var contentInset: UIEdgeInsets { get set }
    var automaticallyAdjustContentInsets: Bool { get set }
    func refreshContentInset()
}
```

### Implementation

`DCFScrollView` implements this protocol and uses `UIView.autoAdjustInsets()` to calculate and apply insets based on the containing view controller's layout guides.

**When Insets Are Refreshed:**

1. **Layout Guide Changes** - `DCFWrapperViewController` detects layout guide changes in `viewDidLayoutSubviews()` and calls `refreshContentInset()` on scroll views
2. **Manual Refresh** - Components can call `refreshContentInset()` manually when needed

---

## UIView+DCFLayoutGuides

### Purpose

Extension on `UIView` that provides utilities for:
1. Finding the containing view controller for any view
2. Calculating content insets based on layout guides
3. Automatically adjusting scroll view content insets

### Key Methods

#### `dcfViewController`

Finds the first view controller whose view (or any subview) contains the specified view.

```swift
@objc public var dcfViewController: UIViewController?
```

**Usage:**
```swift
if let controller = someView.dcfViewController {
    // Access view controller properties
}
```

#### `contentInsets(for:)`

Finds content insets for a view based on its containing view controller's layout guides.

```swift
@objc public static func contentInsets(for view: UIView) -> UIEdgeInsets
```

**Returns:**
- `UIEdgeInsets` with `top` and `bottom` set to layout guide lengths
- `left` and `right` are always `0`
- Returns `.zero` if no view controller is found

#### `autoAdjustInsets(for:with:updateOffset:)`

Automatically adjusts content insets for a scroll view based on layout guides.

```swift
@objc public static func autoAdjustInsets(
    for parentView: DCFAutoInsetsProtocol,
    with scrollView: UIScrollView,
    updateOffset: Bool
)
```

**Parameters:**
- `parentView` - View implementing `DCFAutoInsetsProtocol` (e.g., `DCFScrollView`)
- `scrollView` - The underlying `UIScrollView` to adjust
- `updateOffset` - Whether to adjust `contentOffset` when insets change

**Behavior:**
1. Gets base insets from `parentView.contentInset`
2. If `automaticallyAdjustContentInsets` is `true`, adds layout guide insets
3. Applies final insets to scroll view
4. Optionally adjusts `contentOffset` to prevent content from being covered

---

## How They Work Together

### Example: ScrollView in Navigation Screen

1. **Screen Creation**
   - `DCFScreenComponent` creates a `ScreenContainer` with `DCFWrapperViewController`
   - The wrapper view controller wraps the screen's content view

2. **Layout Guide Caching**
   - `DCFWrapperViewController` implements `DCFViewControllerProtocol`
   - Provides cached access to `topLayoutGuide` and `bottomLayoutGuide`

3. **ScrollView Setup**
   - `DCFScrollView` implements `DCFAutoInsetsProtocol`
   - When created, it can query layout guides via `UIView.contentInsets(for:)`

4. **Automatic Inset Updates**
   - When layout guides change (e.g., navigation bar appears), `DCFWrapperViewController.viewDidLayoutSubviews()` is called
   - It finds scroll views in the hierarchy and calls `refreshContentInset()`
   - `DCFScrollView.refreshContentInset()` uses `UIView.autoAdjustInsets()` to recalculate and apply insets

### Flow Diagram

```
┌─────────────────────────────────────┐
│  DCFWrapperViewController           │
│  (wraps screen content)             │
│  ┌───────────────────────────────┐ │
│  │  Content View                 │ │
│  │  ┌─────────────────────────┐ │ │
│  │  │  DCFScrollView           │ │ │
│  │  │  (implements              │ │ │
│  │  │   DCFAutoInsetsProtocol)  │ │ │
│  │  └─────────────────────────┘ │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
         │
         │ monitors layout guide changes
         │
         ▼
┌─────────────────────────────────────┐
│  viewDidLayoutSubviews()            │
│  - Detects layout guide changes    │
│  - Finds scroll views               │
│  - Calls refreshContentInset()      │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  UIView.autoAdjustInsets()          │
│  - Gets layout guides via           │
│    contentInsets(for:)              │
│  - Calculates final insets          │
│  - Applies to scroll view           │
└─────────────────────────────────────┘
```

---

## Benefits

1. **Automatic Safe Area Handling** - Scroll views automatically adjust for notches, status bars, and navigation bars
2. **Rotation Support** - Content insets update automatically when device rotates
3. **Navigation Bar Changes** - Handles dynamic navigation bar height changes
4. **Frame Protection** - Prevents iOS from interfering with DCFlight's layout system
5. **Consistent Behavior** - All scroll views behave consistently across different screen contexts

---

## When to Use

### You Don't Need to Use These Directly

These systems are used automatically by:
- `DCFScreenComponent` - For navigation and tab screens
- `DCFScrollView` - For scroll view content inset management

### When Extending

If you're creating custom components that need layout guide access:

1. **For View Controllers** - Implement `DCFViewControllerProtocol` to provide cached layout guides
2. **For Scrollable Views** - Implement `DCFAutoInsetsProtocol` to support automatic inset adjustment
3. **For Utilities** - Use `UIView.dcfViewController` and `UIView.contentInsets(for:)` to access layout guide information

---

## Related Documentation

- [ScrollView Component](../components/SCROLLVIEW.md)
- [Screen Component](../components/SCREEN.md)
- [iOS Platform Integration](./IOS_PLATFORM_INTEGRATION.md)

