/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Blur filter
class SkiaBlur extends DCFStatelessComponent {
  /// Blur radius
  final double blur;
  
  /// Blur style
  final String? style; // normal, solid, outer, inner
  
  SkiaBlur({
    required this.blur,
    this.style,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaBlur',
      elementProps: {
        'blur': blur,
        if (style != null) 'style': style,
      },
      children: const [],
    );
  }
}

/// Drop shadow filter
class SkiaDropShadow extends DCFStatelessComponent {
  final double dx;
  final double dy;
  final double blur;
  final dynamic color; // ARGB int or CSS color string
  
  SkiaDropShadow({
    required this.dx,
    required this.dy,
    required this.blur,
    required this.color,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaDropShadow',
      elementProps: {
        'dx': dx,
        'dy': dy,
        'blur': blur,
        'color': color is int ? color : color.toString(),
      },
      children: const [],
    );
  }
}

/// Displacement map filter
class SkiaDisplacementMap extends DCFStatelessComponent {
  final double scale;
  final String? channelX; // r, g, b, a
  final String? channelY; // r, g, b, a
  
  SkiaDisplacementMap({
    required this.scale,
    this.channelX,
    this.channelY,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaDisplacementMap',
      elementProps: {
        'scale': scale,
        if (channelX != null) 'channelX': channelX,
        if (channelY != null) 'channelY': channelY,
      },
      children: const [],
    );
  }
}

/// Morphology filter (dilate/erode)
class SkiaMorphology extends DCFStatelessComponent {
  final double radius;
  final String operator; // dilate, erode
  
  SkiaMorphology({
    required this.radius,
    this.operator = 'dilate',
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaMorphology',
      elementProps: {
        'radius': radius,
        'operator': operator,
      },
      children: const [],
    );
  }
}

