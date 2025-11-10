/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// Gradient types supported by DCFlight
enum DCFGradientType {
  linear,
  radial,
}

/// Gradient definition for DCFlight styling
class DCFGradient extends Equatable {
  final DCFGradientType type;
  final List<Color> colors;
  final List<double>? stops;
  final double? startX;
  final double? startY;
  final double? endX;
  final double? endY;
  final double? centerX;
  final double? centerY;
  final double? radius;

  const DCFGradient({
    required this.type,
    required this.colors,
    this.stops,
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.centerX,
    this.centerY,
    this.radius,
  });

  /// Create a linear gradient
  factory DCFGradient.linear({
    required List<Color> colors,
    List<double>? stops,
    double startX = 0.0,
    double startY = 0.0,
    double endX = 1.0,
    double endY = 1.0,
  }) {
    return DCFGradient(
      type: DCFGradientType.linear,
      colors: colors,
      stops: stops,
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
    );
  }

  /// Create a radial gradient
  factory DCFGradient.radial({
    required List<Color> colors,
    List<double>? stops,
    double centerX = 0.5,
    double centerY = 0.5,
    double radius = 0.5,
  }) {
    return DCFGradient(
      type: DCFGradientType.radial,
      colors: colors,
      stops: stops,
      centerX: centerX,
      centerY: centerY,
      radius: radius,
    );
  }

  /// Convert gradient to map for serialization
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type.name,
      'colors': colors.map((color) {
        final alpha = (color.a * 255.0).round() & 0xff;
        if (alpha == 0) {
          return 'transparent';
        } else if (alpha == 255) {
          final hexValue = color.toARGB32() & 0xFFFFFF;
          return '#${hexValue.toRadixString(16).padLeft(6, '0')}';
        } else {
          final argbValue = color.toARGB32();
          return '#${argbValue.toRadixString(16).padLeft(8, '0')}';
        }
      }).toList(),
    };

    if (stops != null) map['stops'] = stops;
    if (startX != null) map['startX'] = startX;
    if (startY != null) map['startY'] = startY;
    if (endX != null) map['endX'] = endX;
    if (endY != null) map['endY'] = endY;
    if (centerX != null) map['centerX'] = centerX;
    if (centerY != null) map['centerY'] = centerY;
    if (radius != null) map['radius'] = radius;

    return map;
  }

  @override
  List<Object?> get props => [
        type,
        colors,
        stops,
        startX,
        startY,
        endX,
        endY,
        centerX,
        centerY,
        radius,
      ];
}
