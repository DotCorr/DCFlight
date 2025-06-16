# StyleSheet Reference

The `StyleSheet` class is the primary way to apply visual styling to DCFlight components. It provides a comprehensive set of properties for borders, backgrounds, gradients, shadows, transforms, and accessibility.

## What StyleSheet Does

StyleSheet serves as the comprehensive styling system for DCFlight components, similar to CSS for web development. It allows you to:

- **Control Visual Appearance**: Set colors, borders, shadows, and gradients
- **Transform Components**: Scale, rotate, translate, and skew elements
- **Enhance Usability**: Expand touch targets and improve accessibility
- **Create Adaptive UIs**: Automatically adapt to light/dark mode and system themes
- **Optimize Performance**: Type-safe styling with native iOS integration

Each property in StyleSheet directly controls a specific visual aspect of your component, from basic colors to complex 3D transforms.

## Overview

```dart
class StyleSheet {
  // Border properties
  final dynamic borderRadius;
  final dynamic borderTopLeftRadius;
  final dynamic borderTopRightRadius;
  final dynamic borderBottomLeftRadius;
  final dynamic borderBottomRightRadius;
  final Color? borderColor;
  final dynamic borderWidth;

  // Background and opacity
  final Color? backgroundColor;
  final DCFGradient? backgroundGradient;
  final double? opacity;

  // Shadow properties
  final Color? shadowColor;
  final double? shadowOpacity;
  final dynamic shadowRadius;
  final dynamic shadowOffsetX;
  final dynamic shadowOffsetY;
  final dynamic elevation;

  // Transform properties
  final DCFTransform? transform;

  // Hit area expansion
  final DCFHitSlop? hitSlop;

  // Accessibility properties
  final bool? accessible;
  final String? accessibilityLabel;
  final String? testID;
  final String? pointerEvents;
}
```

## Border Properties

Border properties control the outline appearance of components, creating visual boundaries and definition.

### borderRadius
Controls the roundness of all four corners of a component, creating everything from subtle rounded edges to perfect circles.

**What it does:**
- Rounds sharp rectangular corners into smooth curves
- Creates circular shapes when set to 50% of width/height
- Provides visual softness and modern design aesthetics
- Affects both the border and background clipping

**Visual Effect:** Sharp 90-degree corners become smooth, curved transitions

**Type:** `dynamic` (accepts `double` or `String`)
**Values:**
- `double`: Pixel value (e.g., `8.0` for 8 pixel radius)
- `String`: Percentage (e.g., `"50%"` for circular shape)

```dart
StyleSheet(borderRadius: 8.0)        // All corners with 8px radius
StyleSheet(borderRadius: "50%")      // Circular shape (50% of width/height)
StyleSheet(borderRadius: 0.0)        // Sharp corners (no radius)
```

### Individual Corner Radius
Control each corner independently for asymmetric designs and creative layouts.

**What it does:**
- Allows unique styling for each corner (top-left, top-right, bottom-left, bottom-right)
- Creates asymmetric shapes like speech bubbles, cards with specific orientations
- Enables design patterns like "torn paper" effects or directional indicators
- Useful for connected UI elements (tabs, breadcrumbs)

**Visual Effect:** Each corner can have different curvature, creating unique geometric shapes

**Properties:**
- `borderTopLeftRadius`: Top-left corner radius
- `borderTopRightRadius`: Top-right corner radius  
- `borderBottomLeftRadius`: Bottom-left corner radius
- `borderBottomRightRadius`: Bottom-right corner radius

**Type:** `dynamic` (accepts `double` or `String`)

```dart
// Top-rounded rectangle (common for cards)
StyleSheet(
  borderTopLeftRadius: 8.0,
  borderTopRightRadius: 8.0,
  borderBottomLeftRadius: 0.0,
  borderBottomRightRadius: 0.0,
)

// Asymmetric design
StyleSheet(
  borderTopLeftRadius: 16.0,
  borderTopRightRadius: 4.0,
  borderBottomLeftRadius: 4.0,
  borderBottomRightRadius: 16.0,
)
```

### borderColor
Sets the color of the component's border, creating visual boundaries and emphasis.

**What it does:**
- Creates a colored outline around the component
- Provides visual separation between components
- Indicates state changes (focus, error, success)
- Adds visual hierarchy and structure to layouts
- Can be transparent for invisible borders that maintain spacing

**Visual Effect:** A colored line appears around the component's perimeter

**Type:** `Color?`
**Default:** `null` (uses adaptive system separator color)

```dart
StyleSheet(borderColor: Colors.blue)                    // Solid blue border
StyleSheet(borderColor: Colors.red.withOpacity(0.5))    // Semi-transparent red
StyleSheet(borderColor: Colors.transparent)             // Invisible border
// borderColor: null                                    // Adaptive system color
```

### borderWidth
Controls the thickness of the border, determining how prominent the border appears.

**What it does:**
- Sets the stroke width of the border line
- Controls visual weight and prominence of the border
- Creates emphasis through varying thickness (thin borders for subtle separation, thick borders for strong emphasis)
- Affects component's total visual size (border adds to component dimensions)
- Can create decorative effects with very thick borders

**Visual Effect:** The border line becomes thicker or thinner, affecting visual prominence

**Type:** `dynamic` (accepts `double`)
**Default:** `null` (no border)
**Units:** Logical pixels

```dart
StyleSheet(borderWidth: 1.0)    // Thin border (common for inputs)
StyleSheet(borderWidth: 2.0)    // Medium border (common for buttons)
StyleSheet(borderWidth: 4.0)    // Thick border (emphasis)
StyleSheet(borderWidth: 0.5)    // Hairline border (subtle separation)
```

**Note:** Border is only visible when both `borderWidth` and `borderColor` are specified.

## Background Properties

Background properties control the fill and appearance behind the component's content.

### backgroundColor
Sets the solid background color of a component, providing the foundational color behind all content.

**What it does:**
- Fills the component's bounds with a solid color
- Provides contrast for text and other content
- Creates visual hierarchy through color variation
- Can be transparent to show content behind the component
- Automatically adapts to system theme when set to null (light/dark mode support)

**Visual Effect:** The entire component area is filled with the specified color

**Type:** `Color?`
**Default:** `null` (uses adaptive system background)

```dart
StyleSheet(backgroundColor: Colors.blue)                    // Solid blue background
StyleSheet(backgroundColor: Colors.blue.withOpacity(0.5))   // Semi-transparent blue
StyleSheet(backgroundColor: Colors.transparent)             // Fully transparent
StyleSheet(backgroundColor: Color(0xFF1976D2))              // Custom hex color
// backgroundColor: null                                     // Adaptive system background
```

**Adaptive Behavior:** When `null`, uses iOS `systemBackground` which automatically adapts to light/dark mode.

### backgroundGradient
Creates gradient backgrounds using the DCFGradient system, enabling smooth color transitions.

**What it does:**
- Creates smooth color transitions across the component's surface
- Replaces solid backgrounds with dynamic, multi-color effects
- Enables both linear (straight-line) and radial (circular) gradients
- Adds visual depth and modern design aesthetics
- Provides professional, polished appearance for buttons, cards, and backgrounds

**Visual Effect:** Colors smoothly blend from one to another across the component area

**Type:** `DCFGradient?`
**Default:** `null` (no gradient)

```dart
// Linear gradient (horizontal)
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [Colors.blue, Colors.purple],
    startX: 0.0, startY: 0.0,  // Top-left
    endX: 1.0, endY: 0.0,      // Top-right
  ),
)

// Linear gradient (vertical)
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [Colors.white, Colors.grey],
    startX: 0.0, startY: 0.0,  // Top
    endX: 0.0, endY: 1.0,      // Bottom
  ),
)

// Radial gradient (circular)
StyleSheet(
  backgroundGradient: DCFGradient.radial(
    colors: [Colors.yellow, Colors.orange, Colors.red],
    centerX: 0.5, centerY: 0.5,  // Center of view
    radius: 0.8,                  // 80% of view radius
  ),
)

// Gradient with color stops
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [Colors.red, Colors.yellow, Colors.green],
    stops: [0.0, 0.3, 1.0],  // Red at 0%, yellow at 30%, green at 100%
    startX: 0.0, startY: 0.0,
    endX: 1.0, endY: 1.0,
  ),
)
```

**Priority:** `backgroundGradient` takes precedence over `backgroundColor` when both are specified.

### opacity
Controls the overall transparency of the entire component and its children.

**What it does:**
- Makes the entire component (including all children) more or less transparent
- Creates fade effects and disabled states
- Allows layering with partial transparency
- Affects all visual properties (background, border, shadows, content)
- Useful for creating loading states, disabled components, or overlay effects

**Visual Effect:** The component appears "ghosted" or faded, allowing background content to show through

**Type:** `double?`
**Default:** `null` (fully opaque, equivalent to `1.0`)
**Range:** `0.0` (fully transparent) to `1.0` (fully opaque)

```dart
StyleSheet(opacity: 1.0)    // Fully opaque (default behavior)
StyleSheet(opacity: 0.8)    // 80% opaque (20% transparent)
StyleSheet(opacity: 0.5)    // 50% opaque (semi-transparent)
StyleSheet(opacity: 0.0)    // Fully transparent (invisible but still takes space)
```

**Note:** Affects the entire component tree, including children. For background transparency only, use `backgroundColor.withOpacity()` instead.

## Shadow Properties

Shadow properties add depth and dimension to components by casting shadows behind them.

### shadowColor
Sets the color of the drop shadow cast by the component.

**What it does:**
- Determines the hue and tone of the shadow
- Can create colored lighting effects (blue shadows for cool lighting, warm shadows for sunset effects)
- Black shadows create realistic depth, colored shadows create artistic effects
- Transparent shadows effectively disable shadow visibility

**Visual Effect:** The shadow takes on the specified color, creating depth with that color tone

**Type:** `Color?`
**Default:** `null` (uses `Colors.black`)

```dart
StyleSheet(shadowColor: Colors.black)                    // Standard black shadow
StyleSheet(shadowColor: Colors.blue.withOpacity(0.3))    // Colored shadow
StyleSheet(shadowColor: Colors.transparent)              // No shadow (invisible)
```

### shadowOpacity
Controls the transparency of the shadow, determining how prominent the shadow appears.

**What it does:**
- Sets how strong and visible the shadow appears
- Controls the depth perception created by the shadow
- Allows for subtle shadows (low opacity) or dramatic shadows (high opacity)
- Completely hides shadows when set to 0.0

**Visual Effect:** The shadow becomes more or less visible, creating varying degrees of depth

**Type:** `double?`
**Default:** `null` (no shadow)
**Range:** `0.0` (invisible) to `1.0` (fully opaque)

```dart
StyleSheet(shadowOpacity: 0.0)     // No shadow
StyleSheet(shadowOpacity: 0.1)     // Very subtle shadow
StyleSheet(shadowOpacity: 0.25)    // Standard shadow (recommended)
StyleSheet(shadowOpacity: 0.5)     // Strong shadow
StyleSheet(shadowOpacity: 1.0)     // Maximum shadow
```

### shadowRadius
Controls the blur radius of the shadow (how soft/spread out it appears).

**What it does:**
- Determines how soft or sharp the shadow edge appears
- Small radius creates sharp, hard shadows (closer light sources)
- Large radius creates soft, diffuse shadows (distant or large light sources)
- Controls the size of the blur effect around the shadow

**Visual Effect:** The shadow edge becomes sharper (small radius) or softer (large radius)

**Type:** `dynamic` (accepts `double`)
**Default:** `null` (no shadow)
**Units:** Logical pixels

```dart
StyleSheet(shadowRadius: 0.0)      // Sharp, hard shadow edge
StyleSheet(shadowRadius: 2.0)      // Slightly soft shadow
StyleSheet(shadowRadius: 4.0)      // Standard soft shadow
StyleSheet(shadowRadius: 8.0)      // Very soft, spread shadow
StyleSheet(shadowRadius: 16.0)     // Extremely soft shadow
```

### shadowOffsetX & shadowOffsetY
Controls the horizontal and vertical offset of the shadow from the component.

**What it does:**
- Determines the direction and distance of the shadow from the component
- Simulates light source position (positive Y = light from above, negative Y = light from below)
- Creates realistic lighting effects by positioning shadows appropriately
- Can create dramatic effects with large offsets

**Visual Effect:** The shadow appears displaced from the component, simulating the direction of light

**Type:** `dynamic` (accepts `double`)
**Default:** `null` (no offset, shadow directly behind component)
**Units:** Logical pixels

```dart
// Standard drop shadow (down and right)
StyleSheet(
  shadowOffsetX: 0.0,     // No horizontal offset
  shadowOffsetY: 2.0,     // 2px down
)

// Left-side shadow
StyleSheet(
  shadowOffsetX: -2.0,    // 2px to the left
  shadowOffsetY: 0.0,     // No vertical offset
)

// Top shadow (uncommon)
StyleSheet(
  shadowOffsetX: 0.0,     // No horizontal offset
  shadowOffsetY: -2.0,    // 2px up
)

// Diagonal shadow
StyleSheet(
  shadowOffsetX: 3.0,     // 3px right
  shadowOffsetY: 3.0,     // 3px down
)
```

### elevation
Android-style elevation that automatically converts to iOS shadow properties.

**What it does:**
- Provides a simple way to create consistent shadows across platforms
- Automatically calculates appropriate shadow values based on elevation distance
- Simulates Material Design elevation system
- Higher elevation = stronger, more offset shadows
- Easier than manually setting individual shadow properties

**Visual Effect:** Creates shadows that simulate the component being lifted above the surface

**Type:** `dynamic` (accepts `double`)
**Default:** `null` (no elevation)
**Units:** Logical pixels

```dart
StyleSheet(elevation: 0.0)     // No elevation (flat)
StyleSheet(elevation: 2.0)     // Subtle elevation (buttons)
StyleSheet(elevation: 4.0)     // Standard elevation (cards)
StyleSheet(elevation: 8.0)     // High elevation (dialogs)
StyleSheet(elevation: 16.0)    // Maximum elevation (overlays)
```

**Automatic Conversion:**
- `shadowOpacity = elevation > 0 ? 0.25 : 0.0`
- `shadowRadius = elevation * 0.5`
- `shadowOffsetY = elevation * 0.5`
- `shadowOffsetX = 0.0`
- `shadowColor = Colors.black`

### Complete Shadow Examples

```dart
// Subtle card shadow
StyleSheet(
  shadowColor: Colors.black,
  shadowOpacity: 0.1,
  shadowRadius: 4.0,
  shadowOffsetX: 0.0,
  shadowOffsetY: 2.0,
)

// Strong button shadow
StyleSheet(
  shadowColor: Colors.black,
  shadowOpacity: 0.3,
  shadowRadius: 6.0,
  shadowOffsetX: 0.0,
  shadowOffsetY: 4.0,
)

// Using elevation (equivalent to above)
StyleSheet(elevation: 8.0)  // Automatically creates strong shadow

// Colored glow effect
StyleSheet(
  shadowColor: Colors.blue,
  shadowOpacity: 0.6,
  shadowRadius: 12.0,
  shadowOffsetX: 0.0,
  shadowOffsetY: 0.0,
)
```

## Transform Properties

Transform properties enable 2D and 3D transformations of components, allowing you to move, scale, rotate, and skew them without affecting layout.

**What transforms do:**
- **Translation**: Move components horizontally and vertically
- **Scaling**: Make components larger or smaller
- **Rotation**: Rotate components around their center point
- **Skewing**: Slant components for perspective effects
- **Combinations**: Apply multiple transforms simultaneously for complex animations

Transform properties allow you to scale, rotate, translate, and skew components using the type-safe `DCFTransform` class.

**Type:** `DCFTransform?`
**Default:** `null` (no transform)

### DCFTransform Properties

Each property controls a specific type of transformation:

- `translateX`: **Horizontal translation** - Moves component left (negative) or right (positive) in logical pixels
- `translateY`: **Vertical translation** - Moves component up (negative) or down (positive) in logical pixels  
- `scaleX`: **Horizontal scaling** - Stretches (>1.0) or compresses (<1.0) component width, 1.0 = normal size
- `scaleY`: **Vertical scaling** - Stretches (>1.0) or compresses (<1.0) component height, 1.0 = normal size
- `rotation`: **Rotation angle** - Rotates component clockwise (positive) or counterclockwise (negative) in radians
- `skewX`: **Horizontal skew** - Slants component horizontally, creating italic-like effect in radians
- `skewY`: **Vertical skew** - Slants component vertically, creating perspective effect in radians

### Factory Constructors

```dart
// Translation (movement)
DCFTransform.translate(10.0, -5.0)  // Move 10px right, 5px up

// Uniform scaling
DCFTransform.scale(1.5)             // Scale to 150% of original size

// Non-uniform scaling
DCFTransform.scale(1.2, 0.8)        // 120% wide, 80% tall

// Rotation (in radians)
DCFTransform.rotate(pi / 4)         // 45-degree rotation
DCFTransform.rotate(-pi / 6)        // -30-degree rotation
```

### Custom Transforms

```dart
// Complex transform combining multiple operations
StyleSheet(
  transform: DCFTransform(
    translateX: 20.0,
    translateY: -10.0,
    scaleX: 1.1,
    scaleY: 1.1,
    rotation: pi / 8,  // 22.5 degrees
  ),
)

// Scaling only
StyleSheet(
  transform: DCFTransform(
    scaleX: 1.2,
    scaleY: 0.9,
  ),
)

// Translation only
StyleSheet(
  transform: DCFTransform(
    translateX: 50.0,
    translateY: 100.0,
  ),
)
```

### Transform Examples

```dart
// Hover effect (scale up slightly)
StyleSheet(
  transform: DCFTransform.scale(1.05),
)

// Card lift animation
StyleSheet(
  transform: DCFTransform(
    scaleX: 1.02,
    scaleY: 1.02,
    translateY: -2.0,
  ),
  shadowOpacity: 0.3,
  shadowRadius: 8.0,
)

// Rotation for loading spinner
StyleSheet(
  transform: DCFTransform.rotate(pi / 2),  // 90-degree rotation
)

// Flip effect
StyleSheet(
  transform: DCFTransform(
    scaleX: -1.0,  // Horizontal flip
    scaleY: 1.0,   // Normal vertical
  ),
)

// Skew for italic-like effect
StyleSheet(
  transform: DCFTransform(
    skewX: pi / 12,  // 15-degree skew
  ),
)
```

**Note:** Transforms are applied around the center point of the component (transform origin is 50%, 50%).

## Hit Area Expansion Properties

Hit area expansion improves usability by making components easier to interact with, especially on touch devices.

**What hit slop does:**
- **Expands touch target**: Makes small buttons easier to tap by expanding their touchable area
- **Improves accessibility**: Ensures interactive elements meet minimum size requirements (44x44 points)
- **Invisible expansion**: Only affects touch detection, visual appearance remains unchanged
- **Prevents accidental taps**: Can be used strategically to avoid expanding toward screen edges
- **Better UX**: Reduces user frustration with hard-to-tap small elements

Hit area expansion allows you to increase the touchable area of a component beyond its visual bounds, improving usability especially for small interactive elements.

**Type:** `DCFHitSlop?`
**Default:** `null` (no expansion)

### DCFHitSlop Properties

Each property expands the touchable area in a specific direction:

- `top`: **Upward expansion** - Increases touchable area above the component (logical pixels)
- `bottom`: **Downward expansion** - Increases touchable area below the component (logical pixels)
- `left`: **Leftward expansion** - Increases touchable area to the left of the component (logical pixels)
- `right`: **Rightward expansion** - Increases touchable area to the right of the component (logical pixels)

**Visual Effect:** The component becomes easier to tap, but looks exactly the same

### Factory Constructors

```dart
// Uniform expansion (all sides equal)
DCFHitSlop.all(10.0)  // 10px expansion on all sides

// Symmetric expansion
DCFHitSlop.symmetric(
  vertical: 15.0,    // 15px top and bottom
  horizontal: 20.0,  // 20px left and right
)
```

### Custom Hit Slop

```dart
// Individual side control
StyleSheet(
  hitSlop: DCFHitSlop(
    top: 10.0,
    bottom: 10.0,
    left: 15.0,
    right: 15.0,
  ),
)

// Only expand specific sides
StyleSheet(
  hitSlop: DCFHitSlop(
    top: 20.0,
    bottom: 20.0,
    // left and right remain at visual bounds
  ),
)
```

### Use Cases

```dart
// Small icon button (easier to tap)
StyleSheet(
  hitSlop: DCFHitSlop.all(12.0),  // 44x44 minimum touch target
)

// Close button in corner (prevent accidental taps)
StyleSheet(
  hitSlop: DCFHitSlop(
    top: 8.0,
    left: 8.0,
    // Don't expand toward screen edges
  ),
)

// Slider thumb (larger grab area)
StyleSheet(
  hitSlop: DCFHitSlop.symmetric(
    vertical: 20.0,
    horizontal: 10.0,
  ),
)
```

**Note:** Hit slop is invisible and only affects touch detection. The visual appearance remains unchanged.

## Accessibility Properties

Accessibility properties help make components usable by assistive technologies like VoiceOver on iOS.

### accessible
Controls whether the component is considered an accessibility element.

**What it does:**
- Determines if screen readers and assistive technologies can interact with this component
- Forces components to be accessible even if they normally wouldn't be
- Hides decorative elements from accessibility tree to reduce clutter
- Improves navigation for users with disabilities

**Effect on Experience:** Makes components discoverable or hidden from screen readers

**Type:** `bool?`
**Default:** `null` (uses component defaults)

```dart
StyleSheet(accessible: true)   // Force accessibility element
StyleSheet(accessible: false)  // Not an accessibility element
// accessible: null            // Use component default behavior
```

### accessibilityLabel
Provides a descriptive label for assistive technologies.

**What it does:**
- Gives screen readers meaningful text to announce when the component is focused
- Overrides any default text that might be read automatically
- Provides context for interactive elements (buttons, inputs, etc.)
- Describes the purpose or content of visual elements
- Essential for users who cannot see the visual interface

**Effect on Experience:** Screen readers announce this text when users navigate to the component

**Type:** `String?`
**Default:** `null` (uses component content or defaults)

```dart
StyleSheet(accessibilityLabel: "Submit button")           // Clear description
StyleSheet(accessibilityLabel: "Close dialog")            // Action description
StyleSheet(accessibilityLabel: "Profile picture")         // Content description
StyleSheet(accessibilityLabel: "Loading, please wait")    // Status description
```

### testID
Provides an identifier for automated testing frameworks.

**What it does:**
- Creates a unique identifier that testing tools can use to find components
- Enables automated UI testing (unit tests, integration tests, end-to-end tests)
- Helps maintain test stability when UI changes
- Provides a reliable way to target components in test scripts
- Does not affect visual appearance or user experience

**Effect on Testing:** Allows test frameworks to reliably locate and interact with components

**Type:** `String?`
**Default:** `null` (no test identifier)

```dart
StyleSheet(testID: "submit_btn")       // Button identifier
StyleSheet(testID: "user_profile")     // Screen section identifier
StyleSheet(testID: "modal_overlay")    // Modal identifier
```

### pointerEvents
Controls how the component responds to touch events.

**What it does:**
- Determines which components can be tapped or touched
- Controls event propagation through component hierarchies
- Enables or disables interactions for specific components
- Useful for creating overlays, disabled states, or transparent containers
- Affects both the component and its children's touch behavior

**Effect on Interaction:** Changes whether users can tap the component and whether taps pass through to components behind it

**Type:** `String?`
**Default:** `null` (equivalent to `"auto"`)
**Values:**
- `"auto"`: Component and children receive touch events (default)
- `"none"`: Component and children ignore touch events
- `"box-none"`: Children receive touch events, component doesn't
- `"box-only"`: Component receives touch events, children don't

```dart
// Normal touch behavior (default)
StyleSheet(pointerEvents: "auto")

// Disable all touch events (overlay, disabled state)
StyleSheet(pointerEvents: "none")

// Component is touchable, children are not (custom button)
StyleSheet(pointerEvents: "box-only")

// Component is not touchable, children are (transparent container)
StyleSheet(pointerEvents: "box-none")
```

### Complete Accessibility Example

```dart
// Accessible button with complete metadata
StyleSheet(
  accessible: true,
  accessibilityLabel: "Add new item to shopping cart",
  testID: "add_to_cart_btn",
  pointerEvents: "auto",
)

// Decorative element (hidden from accessibility)
StyleSheet(
  accessible: false,
  pointerEvents: "none",
)

// Loading overlay (blocks interaction but accessible)
StyleSheet(
  accessible: true,
  accessibilityLabel: "Loading content, please wait",
  pointerEvents: "none",
)
```

## Gradient System

DCFlight provides a comprehensive gradient system through the `DCFGradient` class, supporting both linear and radial gradients with full iOS CAGradientLayer integration.

### DCFGradient Types

**Linear Gradients:** Color transitions along a straight line
**Radial Gradients:** Color transitions from a center point outward in a circular pattern

### Linear Gradients

```dart
// Horizontal gradient (left to right)
DCFGradient.linear(
  colors: [Colors.blue, Colors.purple],
  startX: 0.0, startY: 0.5,  // Left middle
  endX: 1.0, endY: 0.5,      // Right middle
)

// Vertical gradient (top to bottom)
DCFGradient.linear(
  colors: [Colors.white, Colors.grey],
  startX: 0.5, startY: 0.0,  // Top center
  endX: 0.5, endY: 1.0,      // Bottom center
)

// Diagonal gradient
DCFGradient.linear(
  colors: [Colors.red, Colors.yellow],
  startX: 0.0, startY: 0.0,  // Top-left
  endX: 1.0, endY: 1.0,      // Bottom-right
)

// Multi-color gradient with stops
DCFGradient.linear(
  colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
  stops: [0.0, 0.33, 0.66, 1.0],  // Even distribution
  startX: 0.0, startY: 0.0,
  endX: 1.0, endY: 0.0,
)
```

### Radial Gradients

```dart
// Center radial gradient
DCFGradient.radial(
  colors: [Colors.yellow, Colors.orange, Colors.red],
  centerX: 0.5, centerY: 0.5,  // Center of component
  radius: 0.8,                  // 80% of component radius
)

// Off-center radial gradient
DCFGradient.radial(
  colors: [Colors.white, Colors.blue],
  centerX: 0.3, centerY: 0.3,  // Top-left quadrant
  radius: 1.2,                  // Extends beyond component
)

// Radial gradient with stops
DCFGradient.radial(
  colors: [Colors.transparent, Colors.black],
  stops: [0.0, 0.7],  // Transparent center, black outer
  centerX: 0.5, centerY: 0.5,
  radius: 0.9,
)
```

### Coordinate System

**Linear Gradients:**
- `startX`, `startY`: Start point (0.0 to 1.0, relative to component size)
- `endX`, `endY`: End point (0.0 to 1.0, relative to component size)
- `(0.0, 0.0)` = top-left corner
- `(1.0, 1.0)` = bottom-right corner

**Radial Gradients:**
- `centerX`, `centerY`: Center point (0.0 to 1.0, relative to component size)
- `radius`: Gradient radius (0.0 to 1.0+, relative to component radius)
- `radius: 1.0` = gradient reaches component edges
- `radius: 0.5` = gradient covers half the component

### Color Stops

Control precise color placement within gradients:

```dart
// Without stops (even distribution)
DCFGradient.linear(
  colors: [Colors.red, Colors.green, Colors.blue],
  // Stops: [0.0, 0.5, 1.0] (automatic)
)

// With custom stops
DCFGradient.linear(
  colors: [Colors.red, Colors.green, Colors.blue],
  stops: [0.0, 0.2, 1.0],  // Green appears early
)

// Complex stop patterns
DCFGradient.linear(
  colors: [Colors.black, Colors.white, Colors.black],
  stops: [0.0, 0.1, 1.0],  // Thin white stripe
)
```

### Common Gradient Patterns

```dart
// Sunset gradient
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [
      Color(0xFFFF7E5F),  // Coral
      Color(0xFFFEB47B),  // Peach
    ],
    startX: 0.0, startY: 0.0,
    endX: 1.0, endY: 1.0,
  ),
)

// Glass morphism background
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [
      Colors.white.withOpacity(0.2),
      Colors.white.withOpacity(0.1),
    ],
    startX: 0.0, startY: 0.0,
    endX: 0.0, endY: 1.0,
  ),
)

// Spotlight effect
StyleSheet(
  backgroundGradient: DCFGradient.radial(
    colors: [
      Colors.white,
      Colors.grey.shade200,
      Colors.grey.shade800,
    ],
    stops: [0.0, 0.3, 1.0],
    centerX: 0.5, centerY: 0.3,  // Top center
    radius: 1.5,
  ),
)

// Button hover gradient
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [
      Color(0xFF667eea),
      Color(0xFF764ba2),
    ],
    startX: 0.0, startY: 0.0,
    endX: 0.0, endY: 1.0,
  ),
)
```

### iOS Integration

Gradients are implemented using native `CAGradientLayer` on iOS for optimal performance:

- **Linear gradients** use `CAGradientLayer` with `startPoint` and `endPoint`
- **Radial gradients** use `CAGradientLayer` with `type = .radial`
- **Color stops** map directly to `locations` array
- **Automatic clipping** to component bounds with `cornerRadius` support

### Performance Considerations

1. **Gradient caching**: Identical gradients are cached and reused
2. **Native rendering**: Uses hardware-accelerated Core Animation
3. **Memory efficiency**: Gradients are lightweight compared to image-based backgrounds
4. **Dynamic updates**: Gradients can be animated smoothly

### Color Formats
The framework supports multiple color formats and automatically preserves alpha channels:

```dart
// Standard Flutter Colors
StyleSheet(backgroundColor: Colors.blue)
StyleSheet(backgroundColor: Colors.red.shade400)

// Custom Colors with hex values
StyleSheet(backgroundColor: Color(0xFF1976D2))      // Opaque blue
StyleSheet(backgroundColor: Color(0x801976D2))      // Semi-transparent blue

// Transparent Colors
StyleSheet(backgroundColor: Colors.transparent)
StyleSheet(backgroundColor: Colors.blue.withOpacity(0.5))

// System colors (iOS integration)
// backgroundColor: null uses UIColor.systemBackground
```

### Adaptive Colors
When color properties are omitted (`null`), the framework uses iOS system colors that automatically adapt to light/dark mode:

```dart
// Adaptive background (systemBackground in iOS)
StyleSheet()  // No backgroundColor specified

// Adaptive border (separator color)
StyleSheet(borderWidth: 1.0)  // No borderColor specified

// Force specific color (overrides adaptive behavior)
StyleSheet(backgroundColor: Colors.white)  // Always white, regardless of theme
```

### Color Serialization
Colors are automatically serialized to appropriate string formats:

- **Transparent**: `"transparent"`
- **Opaque colors**: `"#RRGGBB"` (6-digit hex)
- **Semi-transparent**: `"#AARRGGBB"` (8-digit hex with alpha)

## Common Styling Patterns

This section covers practical applications and common styling patterns using StyleSheet properties.

### Button Styles

```dart
// Primary button with gradient
class ButtonStyles {
  static final primary = StyleSheet(
    backgroundColor: Colors.blue,
    borderRadius: 8.0,
    shadowOpacity: 0.2,
    shadowRadius: 4.0,
    shadowOffsetY: 2.0,
    hitSlop: DCFHitSlop.all(8.0),  // Easier to tap
  );
  
  // Secondary button with border
  static final secondary = StyleSheet(
    backgroundColor: Colors.transparent,
    borderColor: Colors.blue,
    borderWidth: 1.0,
    borderRadius: 8.0,
    hitSlop: DCFHitSlop.all(8.0),
  );
  
  // Danger button
  static final danger = StyleSheet(
    backgroundColor: Colors.red,
    borderRadius: 8.0,
    shadowOpacity: 0.15,
    shadowRadius: 3.0,
    shadowOffsetY: 1.0,
  );
  
  // Disabled button
  static final disabled = StyleSheet(
    backgroundColor: Colors.grey.shade300,
    borderRadius: 8.0,
    opacity: 0.6,
    pointerEvents: "none",  // Disable interactions
  );
}
```

### Card Styles

```dart
// Standard card with subtle shadow
class CardStyles {
  static final basic = StyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 12.0,
    shadowColor: Colors.black.withOpacity(0.1),
    shadowOpacity: 0.1,
    shadowRadius: 6.0,
    shadowOffsetY: 2.0,
  );
  
  // Elevated card (higher shadow)
  static final elevated = StyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 12.0,
    elevation: 8.0,  // Automatic shadow calculation
  );
  
  // Interactive card with hover effect
  static final interactive = StyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 12.0,
    shadowOpacity: 0.1,
    shadowRadius: 4.0,
    shadowOffsetY: 2.0,
    transform: DCFTransform.scale(1.0),  // Ready for animation
  );
  
  // Card with border accent
  static final accented = StyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 12.0,
    borderColor: Colors.blue.shade200,
    borderWidth: 1.0,
    shadowOpacity: 0.05,
    shadowRadius: 3.0,
  );
}
```

### Input Field Styles

```dart
class InputStyles {
  // Standard input with focus state
  static final standard = StyleSheet(
    backgroundColor: Colors.white,
    borderColor: Colors.grey.shade300,
    borderWidth: 1.0,
    borderRadius: 6.0,
    shadowOpacity: 0.05,
    shadowRadius: 2.0,
  );
  
  // Focused input
  static final focused = StyleSheet(
    backgroundColor: Colors.white,
    borderColor: Colors.blue,
    borderWidth: 2.0,
    borderRadius: 6.0,
    shadowOpacity: 0.1,
    shadowRadius: 4.0,
    shadowColor: Colors.blue.withOpacity(0.2),
  );
  
  // Error state
  static final error = StyleSheet(
    backgroundColor: Colors.red.shade50,
    borderColor: Colors.red,
    borderWidth: 1.0,
    borderRadius: 6.0,
  );
  
  // Disabled input
  static final disabled = StyleSheet(
    backgroundColor: Colors.grey.shade100,
    borderColor: Colors.grey.shade300,
    borderWidth: 1.0,
    borderRadius: 6.0,
    opacity: 0.7,
    pointerEvents: "none",
  );
}
```

### Modal and Overlay Styles

```dart
class OverlayStyles {
  // Semi-transparent background overlay
  static final backdrop = StyleSheet(
    backgroundColor: Colors.black.withOpacity(0.5),
    pointerEvents: "auto",  // Blocks touches to content behind
  );
  
  // Modal dialog
  static final modal = StyleSheet(
    backgroundColor: Colors.white,
    borderRadius: 16.0,
    shadowOpacity: 0.3,
    shadowRadius: 20.0,
    shadowOffsetY: 10.0,
    elevation: 16.0,
  );
  
  // Bottom sheet
  static final bottomSheet = StyleSheet(
    backgroundColor: Colors.white,
    borderTopLeftRadius: 20.0,
    borderTopRightRadius: 20.0,
    shadowOpacity: 0.2,
    shadowRadius: 15.0,
    shadowOffsetY: -5.0,
  );
  
  // Tooltip
  static final tooltip = StyleSheet(
    backgroundColor: Colors.black.withOpacity(0.8),
    borderRadius: 6.0,
    shadowOpacity: 0.2,
    shadowRadius: 8.0,
    shadowOffsetY: 2.0,
  );
}
```

### Navigation Styles

```dart
class NavigationStyles {
  // Tab bar item
  static final tabItem = StyleSheet(
    borderRadius: 8.0,
    hitSlop: DCFHitSlop.all(12.0),  // Larger touch target
  );
  
  // Active tab
  static final activeTab = StyleSheet(
    backgroundColor: Colors.blue.shade100,
    borderRadius: 8.0,
    borderColor: Colors.blue,
    borderWidth: 1.0,
  );
  
  // Navigation bar
  static final navBar = StyleSheet(
    backgroundColor: Colors.white,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.grey.shade300,
    shadowOpacity: 0.05,
    shadowRadius: 3.0,
    shadowOffsetY: 1.0,
  );
  
  // Breadcrumb item
  static final breadcrumb = StyleSheet(
    borderTopLeftRadius: 4.0,
    borderBottomLeftRadius: 4.0,
    borderTopRightRadius: 0.0,
    borderBottomRightRadius: 0.0,
    backgroundColor: Colors.grey.shade100,
  );
}
```

### Animation States

```dart
class AnimationStyles {
  // Initial state (before animation)
  static final initial = StyleSheet(
    opacity: 0.0,
    transform: DCFTransform(
      scaleX: 0.8,
      scaleY: 0.8,
      translateY: 20.0,
    ),
  );
  
  // Final state (after animation)
  static final final = StyleSheet(
    opacity: 1.0,
    transform: DCFTransform(
      scaleX: 1.0,
      scaleY: 1.0,
      translateY: 0.0,
    ),
  );
  
  // Hover/pressed state
  static final pressed = StyleSheet(
    transform: DCFTransform.scale(0.95),
    shadowOpacity: 0.1,
    shadowRadius: 2.0,
  );
  
  // Loading state
  static final loading = StyleSheet(
    opacity: 0.7,
    transform: DCFTransform.rotate(0.0),  // Will be animated
    pointerEvents: "none",
  );
}
```

### Accessibility-First Styles

```dart
class A11yStyles {
  // High contrast button
  static final highContrast = StyleSheet(
    backgroundColor: Colors.black,
    borderColor: Colors.white,
    borderWidth: 2.0,
    borderRadius: 8.0,
    hitSlop: DCFHitSlop.all(12.0),
    accessible: true,
    accessibilityLabel: "High contrast button",
  );
  
  // Focus indicator
  static final focused = StyleSheet(
    borderColor: Colors.blue,
    borderWidth: 3.0,
    borderRadius: 4.0,
    shadowColor: Colors.blue,
    shadowOpacity: 0.3,
    shadowRadius: 6.0,
  );
  
  // Hidden from accessibility (decorative)
  static final decorative = StyleSheet(
    accessible: false,
    pointerEvents: "none",
  );
  
  // Screen reader only (invisible but accessible)
  static final srOnly = StyleSheet(
    opacity: 0.0,
    accessible: true,
    pointerEvents: "none",
  );
}
```

### Responsive Design Patterns

```dart
class ResponsiveStyles {
  // Small screen (mobile)
  static final mobile = StyleSheet(
    borderRadius: 6.0,
    shadowRadius: 3.0,
    hitSlop: DCFHitSlop.all(12.0),  // Larger touch targets
  );
  
  // Large screen (tablet/desktop)
  static final desktop = StyleSheet(
    borderRadius: 8.0,
    shadowRadius: 6.0,
    hitSlop: DCFHitSlop.all(8.0),
    transform: DCFTransform.scale(1.1),  // Slightly larger
  );
  
  // Dense layout
  static final dense = StyleSheet(
    borderRadius: 4.0,
    shadowRadius: 2.0,
    hitSlop: DCFHitSlop.all(6.0),
  );
  
  // Spacious layout
  static final spacious = StyleSheet(
    borderRadius: 12.0,
    shadowRadius: 8.0,
    hitSlop: DCFHitSlop.all(16.0),
  );
}
```

### Theme-Aware Styles

```dart
class ThemedStyles {
  // Light theme styles
  static final light = StyleSheet(
    backgroundColor: Colors.white,
    borderColor: Colors.grey.shade300,
    shadowColor: Colors.black,
  );
  
  // Dark theme styles
  static final dark = StyleSheet(
    backgroundColor: Colors.grey.shade900,
    borderColor: Colors.grey.shade700,
    shadowColor: Colors.black,
  );
  
  // Auto-adaptive (uses system colors)
  static final adaptive = StyleSheet(
    // backgroundColor: null,  // Uses systemBackground
    // borderColor: null,      // Uses separator color
    borderWidth: 1.0,
    borderRadius: 8.0,
    shadowOpacity: 0.1,
    shadowRadius: 4.0,
  );
}
```

### Performance-Optimized Styles

```dart
class OptimizedStyles {
  // Cached gradient (reused across components)
  static final _gradientCache = DCFGradient.linear(
    colors: [Colors.blue, Colors.purple],
    startX: 0.0, startY: 0.0,
    endX: 1.0, endY: 0.0,
  );
  
  // Cached transform (reused for hover states)
  static final _hoverTransform = DCFTransform.scale(1.05);
  
  // Static styles (no runtime allocation)
  static const baseCard = StyleSheet(
    borderRadius: 8.0,
    shadowOpacity: 0.1,
    shadowRadius: 4.0,
  );
  
  // Composed styles using cached elements
  static final gradientCard = baseCard.copyWith(
    backgroundGradient: _gradientCache,
  );
  
  static final hoverCard = baseCard.copyWith(
    transform: _hoverTransform,
  );
}
```

## Visual Design Guidelines

Understanding when and how to use each StyleSheet property effectively for great user experiences.

### Border Design Principles

**When to use borders:**
- **Input fields**: Clearly define editable areas
- **Buttons**: Create button-like appearance, especially for secondary actions
- **Cards**: Subtle borders when shadows aren't appropriate
- **Active states**: Indicate selection or focus

**Border radius guidelines:**
- **0-2px**: Modern, sharp design (enterprise apps)
- **4-8px**: Standard, friendly design (most consumer apps)
- **12-16px**: Playful, modern design (gaming, social apps)
- **50%**: Circular elements (profile pictures, FABs)

```dart
// Sharp, professional design
StyleSheet(borderRadius: 2.0, borderWidth: 1.0, borderColor: Colors.grey.shade400)

// Standard modern design
StyleSheet(borderRadius: 8.0, borderWidth: 1.0, borderColor: Colors.blue.shade300)

// Playful, rounded design
StyleSheet(borderRadius: 16.0, borderWidth: 2.0, borderColor: Colors.orange)

// Circular profile picture
StyleSheet(borderRadius: "50%", borderWidth: 2.0, borderColor: Colors.white)
```

### Color Psychology and Usage

**Background colors convey meaning:**
- **White/Light grays**: Clean, minimal, professional
- **Blue**: Trust, reliability, technology
- **Green**: Success, growth, positive actions
- **Red**: Danger, errors, urgent actions
- **Purple**: Premium, creative, innovative
- **Orange**: Energy, warmth, calls-to-action

**Color accessibility:**
- Ensure sufficient contrast (4.5:1 for normal text, 3:1 for large text)
- Don't rely solely on color to convey information
- Test with color blindness simulators

```dart
// Semantic color usage
class SemanticColors {
  static final success = StyleSheet(
    backgroundColor: Colors.green.shade100,
    borderColor: Colors.green,
    borderWidth: 1.0,
  );
  
  static final warning = StyleSheet(
    backgroundColor: Colors.orange.shade100,
    borderColor: Colors.orange,
    borderWidth: 1.0,
  );
  
  static final error = StyleSheet(
    backgroundColor: Colors.red.shade100,
    borderColor: Colors.red,
    borderWidth: 1.0,
  );
  
  static final info = StyleSheet(
    backgroundColor: Colors.blue.shade100,
    borderColor: Colors.blue,
    borderWidth: 1.0,
  );
}
```

### Shadow Design Principles

**Shadow purposes:**
- **Elevation**: Show component hierarchy and layering
- **Depth**: Create 3D appearance and visual interest
- **Focus**: Draw attention to interactive elements
- **Separation**: Distinguish components from background

**Shadow elevation scale:**
- **0-2px**: Flat design, cards at rest
- **2-4px**: Slight elevation, buttons, input fields
- **4-8px**: Moderate elevation, dropdowns, tooltips
- **8-16px**: High elevation, modals, floating action buttons
- **16px+**: Maximum elevation, overlays, drag states

```dart
// Elevation hierarchy
class ElevationLevels {
  static final surface = StyleSheet(elevation: 0.0);      // Flat surface
  static final raised = StyleSheet(elevation: 2.0);       // Slightly raised
  static final floating = StyleSheet(elevation: 6.0);     // Floating elements
  static final modal = StyleSheet(elevation: 12.0);       // Modal dialogs
  static final overlay = StyleSheet(elevation: 24.0);     // Top-level overlays
}
```

### Transform Usage Guidelines

**Translation (movement):**
- **Hover effects**: Subtle upward movement (-2 to -4px)
- **Slide animations**: Moving content in/out of view
- **Parallax**: Creating depth with layered movement
- **Scroll effects**: Content following scroll position

**Scaling:**
- **Hover feedback**: Slight growth (1.02-1.05x)
- **Press feedback**: Slight shrink (0.95-0.98x)
- **Focus states**: Gentle emphasis (1.02x)
- **Loading states**: Pulsing effect (0.95-1.05x)

**Rotation:**
- **Loading spinners**: Continuous rotation
- **Icon states**: Toggle indicators (0° to 180°)
- **Playful interactions**: Slight rotation on hover (±5°)
- **Orientation changes**: Adapting to device rotation

```dart
// Interaction feedback transforms
class InteractionTransforms {
  static final hover = DCFTransform(
    scaleX: 1.02,
    scaleY: 1.02,
    translateY: -1.0,
  );
  
  static final press = DCFTransform.scale(0.98);
  
  static final focus = DCFTransform(
    scaleX: 1.01,
    scaleY: 1.01,
  );
  
  static final loading = DCFTransform.rotate(0.0); // Animated externally
}
```

### Accessibility Design Guidelines

**Minimum touch targets:**
- **44x44 points**: iOS Human Interface Guidelines minimum
- **48x48 dp**: Android Material Design minimum
- Use `hitSlop` to expand small visual elements

**Color contrast requirements:**
- **4.5:1**: Normal text on background
- **3:1**: Large text (18pt+ or 14pt+ bold)
- **3:1**: UI components and graphics

**Focus indicators:**
- Clear visual indication when components receive focus
- Usually thicker borders or glowing effects
- Should be visible against all background colors

```dart
// Accessibility-compliant styles
class AccessibleStyles {
  static final button = StyleSheet(
    hitSlop: DCFHitSlop.all(12.0),        // Ensures 44pt minimum
    accessible: true,
    borderWidth: 2.0,
    borderRadius: 8.0,
  );
  
  static final focusRing = StyleSheet(
    borderColor: Colors.blue,
    borderWidth: 3.0,
    borderRadius: 4.0,
    shadowColor: Colors.blue,
    shadowOpacity: 0.3,
    shadowRadius: 4.0,
  );
  
  static final highContrast = StyleSheet(
    backgroundColor: Colors.black,
    borderColor: Colors.white,
    borderWidth: 2.0,
  );
}
```

### Performance Design Guidelines

**Shadow optimization:**
- Use `elevation` for standard shadows (automatically optimized)
- Limit shadow radius to reasonable values (0-20px)
- Avoid animating shadow properties frequently

**Transform optimization:**
- Prefer `transform` over changing layout properties
- Use `scale` instead of changing width/height
- Batch transform operations in single DCFTransform

**Color optimization:**
- Use adaptive colors (null values) when possible
- Cache gradient instances for reuse
- Prefer solid colors over gradients for simple designs

**General optimization:**
- Reuse StyleSheet instances as static constants
- Use `copyWith()` instead of creating new instances
- Profile performance with many components

```dart
// Performance-optimized approach
class PerformantStyles {
  static const baseButton = StyleSheet(
    borderRadius: 8.0,
    borderWidth: 1.0,
  );
  
  static final primaryGradient = DCFGradient.linear(
    colors: [Colors.blue, Colors.purple],
    startX: 0.0, startY: 0.0,
    endX: 1.0, endY: 0.0,
  );
  
  static final hoverTransform = DCFTransform(
    scaleX: 1.02,
    scaleY: 1.02,
    translateY: -1.0,
  );
}
```

### Mobile-First Design Principles

**Touch-friendly design:**
- Minimum 44pt touch targets
- Adequate spacing between interactive elements
- Clear visual feedback for touches
- Consider thumb reach zones

**Platform conventions:**
- **iOS**: Rounded corners, subtle shadows, system colors
- **Android**: Material design, elevation, bold colors
- Use adaptive styling when possible

**Screen size considerations:**
- Larger hit areas on smaller screens
- Adjust border radius for screen density
- Scale shadows appropriately

```dart
// Mobile-optimized styles
class MobileStyles {
  static final touchFriendly = StyleSheet(
    hitSlop: DCFHitSlop.all(16.0),        // Extra large touch area
    borderRadius: 8.0,
    elevation: 2.0,
  );
  
  static final thumbReach = StyleSheet(
    borderRadius: 12.0,                   // Easy to see at thumb distance
    shadowOpacity: 0.15,                  // Visible in various lighting
    shadowRadius: 6.0,
  );
  
  static final adaptive = StyleSheet(
    // Uses system colors and conventions
    borderWidth: 1.0,
    borderRadius: 8.0,
    hitSlop: DCFHitSlop.all(12.0),
  );
}
```

## Troubleshooting Common Issues

Common styling problems and their solutions.

### Border Issues

**Problem: Border not appearing**
```dart
// ❌ Missing borderColor or borderWidth
StyleSheet(borderRadius: 8.0)

// ✅ Include both borderWidth and borderColor
StyleSheet(
  borderRadius: 8.0,
  borderWidth: 1.0,
  borderColor: Colors.grey,
)
```

**Problem: Border radius not working with gradient**
```dart
// ❌ iOS may not clip gradient to border radius properly
StyleSheet(
  backgroundGradient: DCFGradient.linear(...),
  borderRadius: 8.0,
)

// ✅ Ensure gradient coordinates stay within bounds
StyleSheet(
  backgroundGradient: DCFGradient.linear(
    colors: [Colors.blue, Colors.purple],
    startX: 0.0, startY: 0.0,  // Start at bounds
    endX: 1.0, endY: 1.0,      // End at bounds
  ),
  borderRadius: 8.0,
)
```

### Shadow Issues

**Problem: Shadows not visible**
```dart
// ❌ Missing shadowOpacity
StyleSheet(
  shadowColor: Colors.black,
  shadowRadius: 4.0,
  shadowOffsetY: 2.0,
)

// ✅ Include shadowOpacity
StyleSheet(
  shadowColor: Colors.black,
  shadowOpacity: 0.1,        // Required for visibility
  shadowRadius: 4.0,
  shadowOffsetY: 2.0,
)

// ✅ Or use elevation for automatic setup
StyleSheet(elevation: 4.0)
```

**Problem: Shadow appears too strong**
```dart
// ❌ High opacity creates harsh shadows
StyleSheet(shadowOpacity: 0.8)

// ✅ Use subtle opacity for realistic shadows
StyleSheet(shadowOpacity: 0.1)  // Start low, increase gradually
```

### Transform Issues

**Problem: Transform not working**
```dart
// ❌ Using Map instead of DCFTransform
StyleSheet(transform: {'scaleX': 1.1})

// ✅ Use DCFTransform class
StyleSheet(transform: DCFTransform.scale(1.1))
```

**Problem: Transform applied incorrectly**
```dart
// ❌ Wrong transform origin assumptions
StyleSheet(transform: DCFTransform.rotate(pi / 4))  // Rotates around center

// ✅ Understand that transforms use center as origin
// If you need different origin, use combination of translate + rotate + translate
StyleSheet(
  transform: DCFTransform(
    translateX: -10.0,    // Move to desired origin
    rotation: pi / 4,     // Rotate
    translateX: 10.0,     // Move back
  ),
)
```

### Color Issues

**Problem: Colors not adapting to dark mode**
```dart
// ❌ Hard-coded colors
StyleSheet(backgroundColor: Colors.white)

// ✅ Use adaptive colors
StyleSheet()  // backgroundColor: null uses system background

// ✅ Or implement theme-aware colors
StyleSheet(
  backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
)
```

**Problem: Poor contrast**
```dart
// ❌ Insufficient contrast
StyleSheet(
  backgroundColor: Colors.grey.shade200,
  // Text color would be grey.shade400 (poor contrast)
)

// ✅ Ensure sufficient contrast
StyleSheet(
  backgroundColor: Colors.white,
  // Text color would be black (good contrast)
)
```

### Gradient Issues

**Problem: Gradient not showing**
```dart
// ❌ Invalid coordinates or missing colors
DCFGradient.linear(
  colors: [Colors.blue],           // Need at least 2 colors
  startX: 2.0, startY: 0.0,        // Coordinates outside 0-1 range
  endX: 1.0, endY: 1.0,
)

// ✅ Valid gradient setup
DCFGradient.linear(
  colors: [Colors.blue, Colors.purple],  // Multiple colors
  startX: 0.0, startY: 0.0,              // Valid coordinates
  endX: 1.0, endY: 1.0,
)
```

**Problem: Gradient overrides backgroundColor**
```dart
// ❌ Both specified, gradient takes precedence
StyleSheet(
  backgroundColor: Colors.blue,     // This won't show
  backgroundGradient: DCFGradient.linear(...),
)

// ✅ Use one or the other
StyleSheet(
  backgroundGradient: DCFGradient.linear(...),
  // No backgroundColor needed
)
```

### Hit Area Issues

**Problem: Button hard to tap**
```dart
// ❌ Small visual size, no hit expansion
StyleSheet()  // Default hit area

// ✅ Expand hit area for easier tapping
StyleSheet(hitSlop: DCFHitSlop.all(12.0))  // 44pt minimum target
```

**Problem: Hit area conflicts**
```dart
// ❌ Overlapping hit areas cause conflicts
Container(
  children: [
    Button(style: StyleSheet(hitSlop: DCFHitSlop.all(20.0))),
    Button(style: StyleSheet(hitSlop: DCFHitSlop.all(20.0))),
  ],
)

// ✅ Careful hit area sizing or strategic placement
Container(
  children: [
    Button(style: StyleSheet(hitSlop: DCFHitSlop.all(8.0))),
    SizedBox(width: 16),  // Add spacing
    Button(style: StyleSheet(hitSlop: DCFHitSlop.all(8.0))),
  ],
)
```

### Accessibility Issues

**Problem: Missing accessibility labels**
```dart
// ❌ Icon button without label
IconButton(
  style: StyleSheet(accessible: true),
  // Missing accessibilityLabel
)

// ✅ Include descriptive label
IconButton(
  style: StyleSheet(
    accessible: true,
    accessibilityLabel: "Close dialog",
  ),
)
```

**Problem: Inaccessible disabled state**
```dart
// ❌ Disabled visually but not for screen readers
StyleSheet(
  opacity: 0.5,
  // Still accessible to screen readers
)

// ✅ Disable for assistive technologies too
StyleSheet(
  opacity: 0.5,
  pointerEvents: "none",
  accessibilityLabel: "Button disabled",
)
```

### Performance Issues

**Problem: Creating StyleSheet in build method**
```dart
// ❌ Creates new StyleSheet on every build
Widget build(BuildContext context) {
  return DCFView(
    style: StyleSheet(
      backgroundColor: Colors.blue,  // New instance every time
      borderRadius: 8.0,
    ),
  );
}

// ✅ Use static or cached styles
class _MyWidgetState extends State<MyWidget> {
  static final _cardStyle = StyleSheet(
    backgroundColor: Colors.blue,
    borderRadius: 8.0,
  );
  
  Widget build(BuildContext context) {
    return DCFView(style: _cardStyle);  // Reuses same instance
  }
}
```

**Problem: Complex gradients causing performance issues**
```dart
// ❌ Very complex gradient with many colors
DCFGradient.linear(
  colors: List.generate(50, (i) => Color.lerp(Colors.red, Colors.blue, i / 49.0)!),
  stops: List.generate(50, (i) => i / 49.0),
)

// ✅ Simplified gradient with key colors
DCFGradient.linear(
  colors: [Colors.red, Colors.purple, Colors.blue],
  stops: [0.0, 0.5, 1.0],
)
```

### Testing Issues

**Problem: Can't find component in tests**
```dart
// ❌ No test identifier
StyleSheet(accessible: true)

// ✅ Include testID for reliable testing
StyleSheet(
  accessible: true,
  testID: "submit_button",
)
```

**Problem: Style not applying in tests**
```dart
// ❌ Async style application not waited for
testWidgets('button has correct style', (tester) async {
  await tester.pumpWidget(MyButton());
  // Check style immediately - might not be applied yet
});

// ✅ Wait for style application
testWidgets('button has correct style', (tester) async {
  await tester.pumpWidget(MyButton());
  await tester.pumpAndSettle();  // Wait for all animations/updates
  // Now check style
});
```

### Common Debugging Steps

1. **Check property combinations**: Ensure all required properties are set
2. **Verify value ranges**: Coordinates (0-1), opacity (0-1), etc.
3. **Test on device**: Some issues only appear on physical devices
4. **Use type-safe classes**: DCFTransform, DCFHitSlop, DCFGradient
5. **Check iOS logs**: Look for styling warnings in device logs
6. **Profile performance**: Use Flutter Inspector for performance issues

### Quick Reference Checklist

**For borders:**
- [ ] Both borderWidth and borderColor specified
- [ ] borderRadius compatible with content

**For shadows:**
- [ ] shadowOpacity set (0.05-0.3 typical range)
- [ ] shadowRadius reasonable (2-20px typical)
- [ ] shadowOffsetY positive for realistic lighting

**For transforms:**
- [ ] Using DCFTransform class, not Map
- [ ] Rotation values in radians, not degrees
- [ ] Scale values around 1.0 (0.5-2.0 typical)

**For accessibility:**
- [ ] accessibilityLabel for interactive elements
- [ ] hitSlop for touch targets < 44pt
- [ ] testID for automated testing

**For performance:**
- [ ] Static StyleSheet instances where possible
- [ ] Cached gradients and transforms
- [ ] Reasonable shadow and gradient complexity
