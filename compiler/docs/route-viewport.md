# Routed content viewport

A route owns the available native content viewport after the platform's navigation bars, tabs, safe area and keyboard insets. Its root node is placed at the logical top-start of that viewport. The canonical RouteViewportAlignment.TOP_START value records this default independently of SwiftUI or Compose.

This fixes an earlier cross-platform mismatch: SwiftUI NavigationStack centered an intrinsically sized route root, while Compose placed it at top-start. Both now allocate the route viewport explicitly and place the root at top-start. SwiftUI uses an outer flexible frame; Compose uses a full-size Box with TopStart. Existing platform inset handling remains intact.

The outer viewport does not replace the node's authored width, height, padding or cross-axis alignment. Nested Column/Row nodes retain intrinsic main-axis sizing and existing start alignment defaults. Style.align still controls the node's documented internal/cross-axis alignment; it is not a route-position option. This version exposes one fixed route viewport default, not an authoring option for other placements.

The navigation appearance feature is separate. This fix does not change native theme colors, button shapes, field decoration, fonts or typography.
