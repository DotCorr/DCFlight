/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Linear gradient shader
class SkiaLinearGradient extends DCFStatelessComponent {
  /// Start point
  final double x0;
  final double y0;
  
  /// End point
  final double x1;
  final double y1;
  
  /// Colors (ARGB ints or CSS color strings)
  final List<dynamic> colors;
  
  /// Color stops (0.0 to 1.0, optional)
  final List<double>? stops;
  
  /// Tile mode
  final String? tileMode; // clamp, repeat, mirror, decal
  
  SkiaLinearGradient({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.colors,
    this.stops,
    this.tileMode,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaLinearGradient',
      elementProps: {
        'x0': x0,
        'y0': y0,
        'x1': x1,
        'y1': y1,
        'colors': colors.map((c) => c is int ? c : c.toString()).toList(),
        if (stops != null) 'stops': stops,
        if (tileMode != null) 'tileMode': tileMode,
      },
      children: const [],
    );
  }
}

/// Radial gradient shader
class SkiaRadialGradient extends DCFStatelessComponent {
  /// Center point
  final double cx;
  final double cy;
  
  /// Radius
  final double r;
  
  /// Colors (ARGB ints or CSS color strings)
  final List<dynamic> colors;
  
  /// Color stops (0.0 to 1.0, optional)
  final List<double>? stops;
  
  /// Tile mode
  final String? tileMode; // clamp, repeat, mirror, decal
  
  SkiaRadialGradient({
    required this.cx,
    required this.cy,
    required this.r,
    required this.colors,
    this.stops,
    this.tileMode,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaRadialGradient',
      elementProps: {
        'cx': cx,
        'cy': cy,
        'r': r,
        'colors': colors.map((c) => c is int ? c : c.toString()).toList(),
        if (stops != null) 'stops': stops,
        if (tileMode != null) 'tileMode': tileMode,
      },
      children: const [],
    );
  }
}

/// Conic gradient shader (sweep gradient)
class SkiaConicGradient extends DCFStatelessComponent {
  /// Center point
  final double cx;
  final double cy;
  
  /// Start angle in degrees
  final double startAngle;
  
  /// Colors (ARGB ints or CSS color strings)
  final List<dynamic> colors;
  
  /// Color stops (0.0 to 1.0, optional)
  final List<double>? stops;
  
  /// Tile mode
  final String? tileMode; // clamp, repeat, mirror, decal
  
  SkiaConicGradient({
    required this.cx,
    required this.cy,
    this.startAngle = 0.0,
    required this.colors,
    this.stops,
    this.tileMode,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaConicGradient',
      elementProps: {
        'cx': cx,
        'cy': cy,
        'startAngle': startAngle,
        'colors': colors.map((c) => c is int ? c : c.toString()).toList(),
        if (stops != null) 'stops': stops,
        if (tileMode != null) 'tileMode': tileMode,
      },
      children: const [],
    );
  }
}

/// Custom shader (GLSL)
class SkiaCustomShader extends DCFStatelessComponent {
  /// GLSL source code
  final String source;
  
  /// Uniforms (shader parameters)
  final Map<String, dynamic>? uniforms;
  
  SkiaCustomShader({
    required this.source,
    this.uniforms,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaCustomShader',
      elementProps: {
        'source': source,
        if (uniforms != null) 'uniforms': uniforms,
      },
      children: const [],
    );
  }
}

