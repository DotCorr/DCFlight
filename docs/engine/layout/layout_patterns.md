# Layout Patterns Quick Reference

Common layout patterns and their implementations in DCFlight.

## 🎯 Centering Patterns

### Center Everything
```dart
LayoutProps(
  justifyContent: YogaJustifyContent.center,
  alignItems: YogaAlign.center,
)
```
```
┌─────────────────┐
│                 │
│       ┌───┐     │
│       │ X │     │ ← Perfectly centered
│       └───┘     │
│                 │
└─────────────────┘
```

### Absolute Center
```dart
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout.centered(),
)
```

### Center Horizontally Only
```dart
LayoutProps(
  alignItems: YogaAlign.center, // For flex children
  // OR for absolute:
  absoluteLayout: AbsoluteLayout.centeredHorizontally(),
)
```

## 📋 List Layouts

### Vertical List (Default)
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  gap: 10,
)
```
```
┌─────────────┐
│    Item 1   │
├─────────────┤ ← gap: 10
│    Item 2   │
├─────────────┤
│    Item 3   │
└─────────────┘
```

### Horizontal List
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  gap: 15,
)
```
```
┌─────┬───┬─────┬───┬─────┐
│Item1│gap│Item2│gap│Item3│
└─────┴───┴─────┴───┴─────┘
```

### Scrollable List
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  overflow: YogaOverflow.scroll,
  maxHeight: 300, // Limit height to enable scrolling
)
```

## 🎴 Card Layouts

### Basic Card
```dart
LayoutProps(
  padding: 20,
  margin: 10,
  width: '100%',
  flexDirection: YogaFlexDirection.column,
  alignItems: YogaAlign.stretch,
)
```

### Card with Header/Body/Footer
```dart
// Container
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  padding: 0,
)

// Header
LayoutProps(padding: 20, borderWidth: 1)

// Body  
LayoutProps(flex: 1, padding: 20)

// Footer
LayoutProps(padding: 15, justifyContent: YogaJustifyContent.flexEnd)
```

## 🌐 Grid Layouts

### Equal Width Grid
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  flexWrap: YogaWrap.wrap,
  gap: 10,
)

// Each child:
LayoutProps(
  flex: 1,
  minWidth: 150, // Minimum before wrapping
)
```

### 2-Column Grid
```dart
// Container
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  flexWrap: YogaWrap.wrap,
  gap: 20,
)

// Each item (50% width minus gap)
LayoutProps(
  width: 'calc(50% - 10px)', // Account for gap
  marginBottom: 20,
)
```

### Masonry-like Layout
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  flexWrap: YogaWrap.wrap,
  alignContent: YogaAlign.flexStart,
  maxHeight: 600, // Fixed container height
)
```

## 📱 App Layout Patterns

### Header/Content/Footer App
```dart
// App Container
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  height: '100%',
)

// Header
LayoutProps(height: 60, flexShrink: 0)

// Content
LayoutProps(flex: 1, overflow: YogaOverflow.scroll)

// Footer
LayoutProps(height: 80, flexShrink: 0)
```
```
┌─────────────────┐
│     Header      │ ← Fixed height: 60
├─────────────────┤
│                 │
│    Content      │ ← flex: 1 (grows)
│   (scrollable)  │
│                 │
├─────────────────┤
│     Footer      │ ← Fixed height: 80
└─────────────────┘
```

### Sidebar Layout
```dart
// App Container
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  height: '100%',
)

// Sidebar
LayoutProps(width: 250, flexShrink: 0)

// Main Content
LayoutProps(flex: 1)
```
```
┌─────┬─────────────┐
│     │             │
│Side │   Content   │
│bar  │             │
│     │             │ ← flex: 1
│250px│             │
│     │             │
└─────┴─────────────┘
```

### Tab Layout
```dart
// Tab Container
LayoutProps(
  flexDirection: YogaFlexDirection.column,
)

// Tab Bar
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  height: 50,
)

// Tab Content
LayoutProps(flex: 1)
```

## 🎯 Positioning Patterns

### Floating Action Button
```dart
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout(
    bottom: 20,
    right: 20,
  ),
  width: 56,
  height: 56,
)
```
```
┌─────────────────┐
│                 │
│    Content      │
│                 │
│            ┌──┐ │ ← FAB positioned
│            │🚀│ │   bottom: 20, right: 20
└────────────└──┘─┘
```

### Notification Badge
```dart
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout(
    top: -5,
    right: -5,
  ),
  width: 20,
  height: 20,
)
```

### Overlay/Modal
```dart
// Overlay Background
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout(
    top: 0, left: 0, right: 0, bottom: 0,
  ),
)

// Modal Content
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout.centered(),
  width: 400,
  height: 300,
)
```

## 🎨 Responsive Patterns

### Breakpoint-Based Layout
```dart
// Mobile: Stack vertically
LayoutProps(
  flexDirection: screenWidth < 768 
    ? YogaFlexDirection.column 
    : YogaFlexDirection.row,
)
```

### Flexible Card Grid
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  flexWrap: YogaWrap.wrap,
  justifyContent: YogaJustifyContent.spaceBetween,
  gap: 20,
)

// Each card
LayoutProps(
  width: screenWidth > 1200 ? '30%' : 
         screenWidth > 768 ? '45%' : '100%',
)
```

### Auto-sizing Columns
```dart
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  gap: 20,
)

// Sidebar: Fixed width
LayoutProps(width: 200, flexShrink: 0)

// Main: Take remaining space
LayoutProps(flex: 1, minWidth: 300)

// Right panel: Content-based width
LayoutProps(width: 'auto', maxWidth: 250)
```

## 📏 Spacing Patterns

### Consistent Spacing System
```dart
// Define spacing scale
class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

// Usage
LayoutProps(
  padding: Spacing.md,    // 16
  margin: Spacing.sm,     // 8
  gap: Spacing.lg,        // 24
)
```

### Rhythm-Based Vertical Spacing
```dart
// Base line height
const baseLineHeight = 24.0;

LayoutProps(
  marginBottom: baseLineHeight,     // 1 line
  // or
  marginBottom: baseLineHeight * 2, // 2 lines
)
```

## 🎪 Animation-Ready Layouts

### Transform-Safe Layout
```dart
LayoutProps(
  // Avoid layout changes during animation
  width: 200,  // Fixed size
  height: 200,
  
  // Use transforms for animation
  scale: animatedValue,
  rotateInDegrees: rotationValue,
)
```

### Flex Animation Container
```dart
LayoutProps(
  overflow: YogaOverflow.hidden, // Hide during animation
  flex: animatedFlexValue,       // Animate flex changes
  maxHeight: animatedHeight,     // Animate height changes
)
```

## 🐛 Common Debugging Patterns

### Layout Debug Borders
```dart
// Temporarily add to see layout bounds
LayoutProps(
  // ... your normal props
  borderWidth: 1, // Shows element boundaries
)
```

### Container Size Visualization
```dart
LayoutProps(
  // Force minimum visibility
  minWidth: 50,
  minHeight: 50,
  // Show available space
  width: '100%',
  height: '100%',
)
```

### Overflow Debug
```dart
LayoutProps(
  overflow: YogaOverflow.visible, // Temporarily show overflow
  // Later change to hidden/scroll as needed
)
```

## 🏆 Performance Patterns

### Layout-Stable Lists
```dart
// Avoid flex: 1 on long lists
LayoutProps(
  flexDirection: YogaFlexDirection.column,
  // Use fixed heights when possible
  height: itemCount * itemHeight,
)
```

### Minimize Layout Recalculation
```dart
// Good: Fixed sizes where possible
LayoutProps(
  width: 200,
  height: 100,
  flexShrink: 0, // Prevent shrinking
)

// Avoid: Percentage sizes that change frequently
LayoutProps(
  width: '${dynamicValue}%', // Causes relayout
)
```

## 🎯 Accessibility Patterns

### Focus-Friendly Layouts
```dart
LayoutProps(
  // Ensure minimum touch targets
  minWidth: 44,
  minHeight: 44,
  
  // Provide adequate spacing
  margin: 8,
)
```

### Screen Reader Friendly
```dart
LayoutProps(
  // Logical reading order with column layout
  flexDirection: YogaFlexDirection.column,
  
  // Clear visual hierarchy
  gap: 16, // Adequate spacing for comprehension
)
```

This reference provides copy-paste solutions for the most common layout scenarios you'll encounter in DCFlight development
