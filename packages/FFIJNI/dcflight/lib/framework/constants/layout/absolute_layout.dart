/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


/// Absolute layout properties for positioning elements
/// When using absolute positioning, these properties work together to precisely position elements
class AbsoluteLayout {
  final dynamic left;
  final dynamic top; 
  final dynamic right;
  final dynamic bottom;
  
  final dynamic translateX;       // Translation offset on X axis
  final dynamic translateY;       // Translation offset on Y axis

  const AbsoluteLayout({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.translateX,
    this.translateY,
  });

  /// Helper constructor for centering an element absolutely
  /// This is a common pattern: position at 50% and translate back by 50%
  const AbsoluteLayout.centered()
      : left = "50%",
        top = "50%",
        right = null, 
        bottom = null,
        translateX = "-50%",
        translateY = "-50%";

  /// Helper constructor for centering horizontally only
  const AbsoluteLayout.centeredHorizontally({
    this.top,
    this.bottom,
  }) : left = "50%",
       right = null,
       translateX = "-50%",
       translateY = null;

  /// Helper constructor for centering vertically only  
  const AbsoluteLayout.centeredVertically({
    this.left,
    this.right,
  }) : top = "50%",
       bottom = null,
       translateX = null,
       translateY = "-50%";

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (left != null) map['left'] = left;
    if (top != null) map['top'] = top;
    if (right != null) map['right'] = right;
    if (bottom != null) map['bottom'] = bottom;
    if (translateX != null) map['translateX'] = translateX;
    if (translateY != null) map['translateY'] = translateY;
    
    return map;
  }

  /// Check if any absolute layout properties are set
  bool get isNotEmpty {
    return left != null ||
        top != null ||
        right != null ||
        bottom != null ||
        translateX != null ||
        translateY != null;
  }

  /// Create a copy with modified properties
  AbsoluteLayout copyWith({
    dynamic left,
    dynamic top,
    dynamic right,
    dynamic bottom,
    dynamic translateX,
    dynamic translateY,
  }) {
    return AbsoluteLayout(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
    );
  }
}
