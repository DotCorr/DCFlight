/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


/// Direction for layout
enum YogaDirection {
  inherit,
  ltr,
  rtl,
}

/// Flex direction
enum YogaFlexDirection {
  column,
  columnReverse,
  row,
  rowReverse,
}

/// Justify content options
enum YogaJustifyContent {
  flexStart,
  center,
  flexEnd,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// Align options
enum YogaAlign {
  auto,
  flexStart,
  center,
  flexEnd,
  stretch,
  baseline,
  spaceBetween,
  spaceAround,
}

/// Flex wrap options
enum YogaWrap {
  nowrap,
  wrap,
  wrapReverse,
}

/// Display options
enum YogaDisplay {
  flex,
  none,
}

/// Position type options
enum YogaPositionType {
  relative,
  absolute,
}

/// Overflow options
enum YogaOverflow {
  visible,
  hidden,
  scroll,
}

/// Edge options for position, margin, padding and border
enum YogaEdge {
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
