# DCFlight Layout Properties Reference

A comprehensive guide to all layout properties available in DCFlight with visual illustrations and practical examples.

## Table of Contents

1. [Sizing Properties](#sizing-properties)
2. [Spacing Properties](#spacing-properties) 
3. [Position Properties](#position-properties)
4. [Flexbox Properties](#flexbox-properties)
5. [Transform Properties](#transform-properties)
6. [Display & Overflow](#display--overflow)
7. [Modern Layout Features](#modern-layout-features)

---

## Sizing Properties

### Width & Height

Basic sizing properties that define the dimensions of an element.

```dart
LayoutProps(
  width: 100,        // Fixed width in points
  height: 50,        // Fixed height in points
  width: '50%',      // Percentage width
  height: '100%',    // Percentage height
)
```

**Visual Example:**
```
┌─────────────────────────────────┐ Parent (300x200)
│  ┌──────────────┐               │
│  │   width:100  │               │ Fixed width
│  │   height:50  │               │
│  └──────────────┘               │
│                                 │
│  ┌──────────────────┐           │ 50% width = 150
│  │    width:'50%'   │           │
│  │    height:80     │           │
│  └──────────────────┘           │
└─────────────────────────────────┘
```

### Min/Max Constraints

Control minimum and maximum dimensions to create responsive layouts.

```dart
LayoutProps(
  width: '100%',
  minWidth: 200,     // Minimum 200 points
  maxWidth: 500,     // Maximum 500 points
  minHeight: 100,
  maxHeight: 300,
)
```

**Visual Example:**
```
Container expands/contracts within bounds:

┌─────────────┐ ← minWidth: 200
│   Content   │
└─────────────┘

┌───────────────────────────────┐ ← maxWidth: 500
│         Content               │
└───────────────────────────────┘

┌─────────────────────┐ ← Actual: fits content within bounds
│      Content        │
└─────────────────────┘
```

---

## Spacing Properties

### Margin (External Spacing)

Space around the outside of an element, pushing away other elements.

```dart
LayoutProps(
  margin: 10,              // All sides: 10
  marginTop: 20,           // Top only
  marginHorizontal: 15,    // Left + Right
  marginVertical: 25,      // Top + Bottom
)
```

**Visual Example:**
```
┌─────────────────────────────────┐ Parent
│        margin: 10               │
│   ┌─┬─────────────────┬─┐       │
│   │ │                 │ │       │
│ ┌─┼─┼─────────────────┼─┼─┐     │
│ │ │ │     Element     │ │ │     │
│ └─┼─┼─────────────────┼─┼─┘     │
│   │ │                 │ │       │
│   └─┴─────────────────┴─┘       │
└─────────────────────────────────┘

Margin creates space between elements:
┌───────────┐  ←margin→  ┌───────────┐
│ Element A │            │ Element B │
└───────────┘            └───────────┘
```

### Padding (Internal Spacing)

Space inside an element, between its border and content.

```dart
LayoutProps(
  padding: 15,             // All sides: 15
  paddingLeft: 20,         // Left only
  paddingVertical: 10,     // Top + Bottom
)
```

**Visual Example:**
```
┌─────────────────────────────────┐ Element border
│        padding: 15              │
│   ┌─────────────────────────┐   │
│   │                         │   │
│   │       Content           │   │
│   │                         │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘

Padding affects available space for children:
Parent (width: 200, padding: 20):
┌──┬────────────────────────────┬──┐
│20│     160 available for      │20│
│  │      child content         │  │
└──┴────────────────────────────┴──┘
```

---

## Position Properties

### Relative Positioning (Default)

Elements are positioned relative to their normal position in the flow.

```dart
LayoutProps(
  position: YogaPositionType.relative, // Default
)
```

**Visual Example:**
```
Normal flow:
┌─────────┐
│ Item 1  │
├─────────┤
│ Item 2  │ ← Relative positioning moves from here
├─────────┤
│ Item 3  │
└─────────┘

With relative positioning (top: -10, left: 20):
┌─────────┐
│ Item 1  │
├─────────┤    ┌─────────┐
│ [space] │    │ Item 2  │ ← Moved but space preserved
├─────────┤    └─────────┘
│ Item 3  │
└─────────┘
```

### Absolute Positioning

Elements are positioned relative to their closest positioned ancestor.

```dart
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout(
    top: 20,
    left: 30,
  ),
)
```

**Visual Example:**
```
┌─────────────────────────────────┐ Positioned parent
│  (30,20)                        │
│     ┌─────────┐                 │
│     │Absolute │                 │
│     │Element  │                 │
│     └─────────┘                 │
│                                 │
│  Other content flows normally   │
│  ┌─────────┐ ┌─────────┐        │
│  │ Item 1  │ │ Item 2  │        │
│  └─────────┘ └─────────┘        │
└─────────────────────────────────┘
```

### AbsoluteLayout Helper Patterns

```dart
// Center an element perfectly
AbsoluteLayout.centered()
// Equivalent to:
AbsoluteLayout(
  left: "50%", top: "50%",
  translateX: "-50%", translateY: "-50%"
)

// Center horizontally only
AbsoluteLayout.centeredHorizontally(top: 100)

// Position in corners
AbsoluteLayout(top: 0, right: 0)      // Top-right
AbsoluteLayout(bottom: 0, left: 0)    // Bottom-left
```

**Centering Visual:**
```
Perfect centering with translate:
┌─────────────────────────────────┐
│                                 │
│              (50%,50%)          │
│                 ├─────────┐     │
│                 │ Center  │     │
│                 │Element  │     │
│                 └─────────┘     │
│                                 │
└─────────────────────────────────┘
↑ left:50%, translateX:-50% centers horizontally
↑ top:50%, translateY:-50% centers vertically
```

### Static Positioning (UseWebDefaults)

Static positioned elements ignore insets and don't form containing blocks.

```dart
LayoutProps(
  position: YogaPositionType.static,
  // Inset properties are ignored
  absoluteLayout: AbsoluteLayout(top: 100), // No effect
)
```

---

## Flexbox Properties

### Flex Direction

Controls the main axis direction for laying out children.

```dart
LayoutProps(
  flexDirection: YogaFlexDirection.row,    // Horizontal
  flexDirection: YogaFlexDirection.column, // Vertical (default)
)
```

**Visual Examples:**

**Column (Default):**
```
┌─────────────┐
│   Child 1   │ ↕ Main axis (vertical)
├─────────────┤
│   Child 2   │
├─────────────┤
│   Child 3   │
└─────────────┘
←──────────────→ Cross axis (horizontal)
```

**Row:**
```
┌───────┬───────┬───────┐
│Child 1│Child 2│Child 3│ ←→ Main axis (horizontal)
└───────┴───────┴───────┘
        ↕
   Cross axis (vertical)
```

**Column Reverse:**
```
┌─────────────┐
│   Child 3   │ ↕ Main axis (reversed)
├─────────────┤
│   Child 2   │
├─────────────┤
│   Child 1   │
└─────────────┘
```

**Row Reverse:**
```
┌───────┬───────┬───────┐
│Child 3│Child 2│Child 1│ ←→ Main axis (reversed)
└───────┴───────┴───────┘
```

### Justify Content (Main Axis Alignment)

Controls how children are distributed along the main axis.

```dart
LayoutProps(
  justifyContent: YogaJustifyContent.spaceBetween,
)
```

**Visual Examples (Row Direction):**

**flex-start (default):**
```
┌───┬───┬───┬─────────────────┐
│ 1 │ 2 │ 3 │      space      │
└───┴───┴───┴─────────────────┘
```

**center:**
```
┌─────────┬───┬───┬───┬─────────┐
│  space  │ 1 │ 2 │ 3 │  space  │
└─────────┴───┴───┴───┴─────────┘
```

**flex-end:**
```
┌─────────────────┬───┬───┬───┐
│      space      │ 1 │ 2 │ 3 │
└─────────────────┴───┴───┴───┘
```

**space-between:**
```
┌───┬─────────┬───┬─────────┬───┐
│ 1 │  space  │ 2 │  space  │ 3 │
└───┴─────────┴───┴─────────┴───┘
```

**space-around:**
```
┌───┬───┬───────┬───┬───────┬───┬───┐
│ s │ 1 │ space │ 2 │ space │ 3 │ s │
└───┴───┴───────┴───┴───────┴───┴───┘
```

**space-evenly:**
```
┌─────┬───┬─────┬───┬─────┬───┬─────┐
│space│ 1 │space│ 2 │space│ 3 │space│
└─────┴───┴─────┴───┴─────┴───┴─────┘
```

### Align Items (Cross Axis Alignment)

Controls how children are aligned along the cross axis.

```dart
LayoutProps(
  alignItems: YogaAlign.center,
)
```

**Visual Examples (Row Direction):**

**flex-start:**
```
┌───┬─────┬───────┐ ← Cross axis start
│ 1 │  2  │   3   │
└───┤     ├───────┤
    │     │       │
    └─────┴───────┘
```

**center:**
```
    ┌─────┬───────┐
┌───┤  2  │   3   │
│ 1 │     │       │ ← Cross axis center
└───┤     ├───────┤
    └─────┴───────┘
```

**flex-end:**
```
    ┌─────┬───────┐
    │  2  │   3   │
┌───┤     ├───────┤ ← Cross axis end
│ 1 │     │       │
└───┴─────┴───────┘
```

**stretch:**
```
┌───┬─────┬───────┐
│ 1 │  2  │   3   │ ← All stretch to fill cross axis
│   │     │       │
└───┴─────┴───────┘
```

### Flex Properties

Control how children grow, shrink, and their base size.

```dart
LayoutProps(
  flex: 1,           // Shorthand for flexGrow: 1
  flexGrow: 2,       // Grow factor
  flexShrink: 1,     // Shrink factor
  flexBasis: 100,    // Base size before growing/shrinking
)
```

**Visual Examples:**

**Equal flex (flex: 1 for all):**
```
┌─────────────┬─────────────┬─────────────┐
│   Child 1   │   Child 2   │   Child 3   │
│   flex: 1   │   flex: 1   │   flex: 1   │
└─────────────┴─────────────┴─────────────┘
```

**Different flex ratios:**
```
┌─────┬─────────────────┬─────────────┐
│  1  │      Child 2    │   Child 3   │
│flex:│     flex: 3     │   flex: 2   │
│ 1   │                 │             │
└─────┴─────────────────┴─────────────┘
```

**flexBasis example:**
```
Before growing (flexBasis: 100 each):
┌───────────┬───────────┬───────────┬──────────┐
│  Child 1  │  Child 2  │  Child 3  │   free   │
│  100px    │  100px    │  100px    │  space   │
└───────────┴───────────┴───────────┴──────────┘

After growing (flex: 1 each):
┌─────────────┬─────────────┬─────────────┐
│   Child 1   │   Child 2   │   Child 3   │
│ 100+33.3px  │ 100+33.3px  │ 100+33.3px  │
└─────────────┴─────────────┴─────────────┘
```

### Flex Wrap

Controls whether items wrap to new lines.

```dart
LayoutProps(
  flexWrap: YogaWrap.wrap,
)
```

**Visual Examples:**

**nowrap (default):**
```
┌───┬───┬───┬───┬───┬───┐ All items on one line,
│ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ may overflow or shrink
└───┴───┴───┴───┴───┴───┘
```

**wrap:**
```
┌───┬───┬───┬───┐ Items wrap to new lines
│ 1 │ 2 │ 3 │ 4 │ when they don't fit
├───┼───┼───┼───┤
│ 5 │ 6 │   │   │
└───┴───┴───┴───┘
```

**wrap-reverse:**
```
┌───┬───┬───┴───┐ New lines appear above
│ 5 │ 6 │   │   │ (reverse order)
├───┼───┼───┼───┤
│ 1 │ 2 │ 3 │ 4 │
└───┴───┴───┴───┘
```

---

## Transform Properties

### Rotation

Rotate elements around their center point.

```dart
LayoutProps(
  rotateInDegrees: 45, // 45 degree rotation
)
```

**Visual Example:**
```
Original:          Rotated 45°:
┌─────────┐             ╱───╲
│  Hello  │      →    ╱ Hello ╲
│  World  │           ╲ World ╱
└─────────┘             ╲───╱
```

### Scaling

Scale elements uniformly or along specific axes.

```dart
LayoutProps(
  scale: 1.5,      // 150% size (uniform)
  scaleX: 2.0,     // 200% width
  scaleY: 0.5,     // 50% height
)
```

**Visual Examples:**

**Uniform scaling (scale: 1.5):**
```
Original:     Scaled:
┌─────┐      ┌─────────┐
│ Box │  →   │   Box   │
└─────┘      │         │
             └─────────┘
```

**X-axis scaling (scaleX: 2.0):**
```
Original:     Scaled X:
┌─────┐      ┌───────────┐
│ Box │  →   │    Box    │
└─────┘      └───────────┘
```

**Y-axis scaling (scaleY: 0.5):**
```
Original:     Scaled Y:
┌─────┐      ┌─────┐
│ Box │  →   │ Box │
└─────┘      └─────┘
```

---

## Display & Overflow

### Display

Controls whether and how an element is rendered.

```dart
LayoutProps(
  display: YogaDisplay.flex,  // Default - rendered as flex
  display: YogaDisplay.none,  // Not rendered at all
)
```

**Visual Example:**
```
display: flex:
┌───┬───┬───┐
│ 1 │ 2 │ 3 │ All elements visible
└───┴───┴───┘

display: none (middle item):
┌───┬───┐
│ 1 │ 3 │ Item 2 completely removed from layout
└───┴───┘
```

### Overflow

Controls how content is handled when it exceeds container bounds.

```dart
LayoutProps(
  overflow: YogaOverflow.hidden,  // Clip content
  overflow: YogaOverflow.visible, // Show overflow
  overflow: YogaOverflow.scroll,  // Enable scrolling
)
```

**Visual Examples:**

**hidden:**
```
┌─────────────┐ ← Container bounds
│ Visible     │
│ Content ┌───┤ ← Content clipped at boundary
└─────────────┘
```

**visible:**
```
┌─────────────┐ ← Container bounds
│ Visible     │
│ Content     │
└─────────────┤
  Overflow    │ ← Content extends beyond bounds
  Content     │
  ───────────┘
```

**scroll:**
```
┌─────────────┐ ↕ Scrollable
│ Visible     │ │
│ Content     │ │ User can scroll to see
│ Hidden      │ │ additional content
│ Content     │ │
└─────────────┘ ↕
```

---

## Modern Layout Features

### Aspect Ratio

Maintains a specific width-to-height ratio.

```dart
LayoutProps(
  aspectRatio: 16 / 9,  // 16:9 ratio (widescreen)
  aspectRatio: 1.0,     // 1:1 ratio (square)
)
```

**Visual Examples:**

**16:9 aspect ratio:**
```
┌─────────────────────────────────┐
│                                 │ Height automatically
│           Content               │ calculated based on
│                                 │ width and ratio
└─────────────────────────────────┘
Width = 320, Height = 320 × (9/16) = 180
```

**1:1 aspect ratio (square):**
```
┌─────────────┐
│             │ Always maintains
│   Content   │ square shape
│             │ regardless of content
└─────────────┘
```

### Gap Properties

Control spacing between child elements in flex layouts.

```dart
LayoutProps(
  gap: 10,        // Equal spacing in both directions
  rowGap: 15,     // Vertical spacing between rows
  columnGap: 20,  // Horizontal spacing between columns
)
```

**Visual Examples:**

**Row layout with gap: 10:**
```
┌───┐ 10 ┌───┐ 10 ┌───┐
│ 1 │<-->│ 2 │<-->│ 3 │
└───┘    └───┘    └───┘
```

**Column layout with gap: 10:**
```
┌───┐
│ 1 │
└───┘
 ↕10
┌───┐
│ 2 │
└───┘
 ↕10
┌───┐
│ 3 │
└───┘
```

**Wrapped layout with rowGap: 15, columnGap: 20:**
```
┌───┐ 20 ┌───┐ 20 ┌───┐
│ 1 │<-->│ 2 │<-->│ 3 │
└───┘    └───┘    └───┘
 ↕15      ↕15      ↕15
┌───┐ 20 ┌───┐
│ 4 │<-->│ 5 │
└───┘    └───┘
```

---

## Property Combinations & Examples

### Card Layout Example

```dart
LayoutProps(
  width: '100%',
  padding: 20,
  margin: 10,
  display: YogaDisplay.flex,
  flexDirection: YogaFlexDirection.column,
  alignItems: YogaAlign.stretch,
  gap: 15,
)
```

**Visual Result:**
```
┌─────────────────────────────────┐ ← 100% width
│margin:10                        │
│ ┌─────────────────────────────┐ │ ← padding: 20
│ │padding:20                   │ │
│ │ ┌─────────────────────────┐ │ │ ← gap: 15 between children
│ │ │     Header Content      │ │ │
│ │ └─────────────────────────┘ │ │
│ │            gap:15           │ │
│ │ ┌─────────────────────────┐ │ │
│ │ │      Body Content       │ │ │
│ │ └─────────────────────────┘ │ │
│ │            gap:15           │ │
│ │ ┌─────────────────────────┐ │ │
│ │ │     Footer Content      │ │ │
│ │ └─────────────────────────┘ │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Centered Modal Example

```dart
LayoutProps(
  position: YogaPositionType.absolute,
  absoluteLayout: AbsoluteLayout.centered(),
  width: 300,
  height: 200,
  padding: 30,
)
```

**Visual Result:**
```
┌─────────────────────────────────┐ Screen/Parent
│                                 │
│        ┌─────────────┐          │
│        │padding:30   │          │ ← Perfectly centered
│        │ ┌─────────┐ │          │   300x200 modal
│        │ │Content  │ │          │
│        │ └─────────┘ │          │
│        └─────────────┘          │
│                                 │
└─────────────────────────────────┘
```

### Responsive Grid Example

```dart
LayoutProps(
  display: YogaDisplay.flex,
  flexDirection: YogaFlexDirection.row,
  flexWrap: YogaWrap.wrap,
  justifyContent: YogaJustifyContent.spaceBetween,
  gap: 20,
)
```

**Visual Result:**
```
┌─────┬─────┬─────┬─────┐ ← Items wrap when
│  1  │  2  │  3  │  4  │   container is full
├─────┼─────┼─────┼─────┤
│  5  │  6  │  7  │     │ ← Remaining space
└─────┴─────┴─────┴─────┘   distributed evenly
    ↕20     ↕20     ↕20
  gap spacing between items
```

## Tips & Best Practices

### 1. **Prefer Flexbox over Absolute Positioning**
- More predictable and responsive
- Easier to maintain and debug
- Better accessibility

### 2. **Use Meaningful Defaults**
```dart
// Good: Clear intent
LayoutProps(
  flexDirection: YogaFlexDirection.row,
  alignItems: YogaAlign.center,
)

// Less clear: Relies on defaults
LayoutProps() // What layout behavior does this create?
```

### 3. **Combine Properties Thoughtfully**
```dart
// Good: Logical combination
LayoutProps(
  flex: 1,              // Take available space
  minHeight: 200,       // But maintain minimum height
  padding: 20,          // With internal spacing
)
```

### 4. **Use Helper Constructors**
```dart
// Good: Clear intent for centering
AbsoluteLayout.centered()

// More verbose but equivalent
AbsoluteLayout(
  left: "50%", top: "50%",
  translateX: "-50%", translateY: "-50%"
)
```


