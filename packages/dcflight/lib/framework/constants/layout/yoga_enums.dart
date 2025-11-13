/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Specifies the direction in which layout is calculated.
///
/// - [inherit]: Inherits the direction from the parent.
/// - [ltr]: Left-to-right layout direction.
/// - [rtl]: Right-to-left layout direction.
/// Direction for layout
enum DCFDirection {
  inherit,
  ltr,
  rtl,
}

/// Defines the main axis direction for flex layout.
///
/// - [column]: Vertical layout, top to bottom.
/// - [columnReverse]: Vertical layout, bottom to top.
/// - [row]: Horizontal layout, left to right.
/// - [rowReverse]: Horizontal layout, right to left.
/// Flex direction
enum DCFFlexDirection {
  column,
  columnReverse,
  row,
  rowReverse,
}

/// Determines how children are distributed along the main axis.
///
/// - [flexStart]: Items are packed toward the start.
/// - [center]: Items are centered.
/// - [flexEnd]: Items are packed toward the end.
/// - [spaceBetween]: Items are evenly distributed with the first at the start and last at the end.
/// - [spaceAround]: Items are evenly distributed with equal space around them.
/// - [spaceEvenly]: Items are distributed so that the spacing between any two items (and the space to the edges) is equal.
/// Justify content options
enum DCFJustifyContent {
  flexStart,
  center,
  flexEnd,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// Controls alignment of children along the cross axis.
///
/// - [auto]: Uses the parent's alignment.
/// - [flexStart]: Aligns items to the start of the cross axis.
/// - [center]: Centers items along the cross axis.
/// - [flexEnd]: Aligns items to the end of the cross axis.
/// - [stretch]: Stretches items to fill the cross axis.
/// - [baseline]: Aligns items along their baselines.
/// - [spaceBetween]: Evenly distributes items with the first at the start and last at the end.
/// - [spaceAround]: Evenly distributes items with equal space around them.
/// Align options
enum DCFAlign {
  auto,
  flexStart,
  center,
  flexEnd,
  stretch,
  baseline,
  spaceBetween,
  spaceAround,
}

/// Specifies whether and how flex items wrap onto multiple lines.
///
/// - [nowrap]: All items are on a single line.
/// - [wrap]: Items wrap onto multiple lines from top to bottom or left to right.
/// - [wrapReverse]: Items wrap onto multiple lines from bottom to top or right to left.
/// Flex wrap options
enum DCFWrap {
  nowrap,
  wrap,
  wrapReverse,
}

/// Controls the display behavior of an element.
///
/// - [flex]: The element is rendered as a flex container.
/// - [none]: The element is not rendered.
/// Display options
enum DCFDisplay {
  flex,
  none,
}

/// Specifies how an element is positioned within its parent.
///
/// - [relative]: Positioned relative to its normal position.
/// - [absolute]: Positioned absolutely within its parent.
/// - [static]: Positioned according to normal flow, ignores insets and doesn't form containing blocks.
/// Position type options
enum DCFPositionType {
  relative,
  absolute,
  static, // ENHANCEMENT: Added static position support
}

/// Controls how content is clipped or scrolled when it overflows its container.
///
/// - [visible]: Content is not clipped and may be rendered outside the container.
/// - [hidden]: Content is clipped and not visible outside the container.
/// - [scroll]: Content is clipped, but can be scrolled into view.
/// Overflow options
enum DCFOverflow {
  visible,
  hidden,
  scroll,
}

/// Represents the edges of a rectangle for position, margin, padding, and border.
///
/// - [left]: Left edge.
/// - [top]: Top edge.
/// - [right]: Right edge.
/// - [bottom]: Bottom edge.
/// - [start]: Logical start edge (depends on direction).
/// - [end]: Logical end edge (depends on direction).
/// - [horizontal]: Both left and right edges.
/// - [vertical]: Both top and bottom edges.
/// - [all]: All edges.
/// Edge options for position, margin, padding and border
enum DCFEdge {
  left,
  top,
  right,
  bottom,
  start,
  end,
  horizontal,
  vertical,
  all,
}
