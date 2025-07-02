/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:equatable/equatable.dart';

/// Hit area expansion for touch targets(this feature is experimental, not much has been done to ensure it works before pre-release)
class DCFHitSlop extends Equatable {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  const DCFHitSlop({
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  /// Create uniform hit slop expansion
  factory DCFHitSlop.all(double value) {
    return DCFHitSlop(
      top: value,
      bottom: value,
      left: value,
      right: value,
    );
  }

  /// Create symmetric hit slop expansion
  factory DCFHitSlop.symmetric({double? vertical, double? horizontal}) {
    return DCFHitSlop(
      top: vertical,
      bottom: vertical,
      left: horizontal,
      right: horizontal,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (top != null) map['top'] = top;
    if (bottom != null) map['bottom'] = bottom;
    if (left != null) map['left'] = left;
    if (right != null) map['right'] = right;
    
    return map;
  }

  /// Create from map
  factory DCFHitSlop.fromMap(Map<String, dynamic> map) {
    return DCFHitSlop(
      top: map['top']?.toDouble(),
      bottom: map['bottom']?.toDouble(),
      left: map['left']?.toDouble(),
      right: map['right']?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [top, bottom, left, right];
}
