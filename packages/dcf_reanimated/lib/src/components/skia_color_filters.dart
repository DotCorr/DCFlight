/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Color Matrix filter
class SkiaColorMatrix extends DCFStatelessComponent {
  /// 5x4 color matrix (20 values)
  final List<double> matrix;
  
  SkiaColorMatrix({
    required this.matrix,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaColorMatrix',
      elementProps: {
        'matrix': matrix,
      },
      children: const [],
    );
  }
}

/// Blend Color filter
class SkiaBlendColor extends DCFStatelessComponent {
  final dynamic color; // ARGB int or CSS color string
  final String mode; // blend mode name
  
  SkiaBlendColor({
    required this.color,
    required this.mode,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaBlendColor',
      elementProps: {
        'color': color is int ? color : color.toString(),
        'mode': mode,
      },
      children: const [],
    );
  }
}

/// Lerp (linear interpolation) between two color filters
class SkiaLerp extends DCFStatelessComponent {
  final double t; // 0.0 to 1.0
  final List<DCFComponentNode> children; // Two color filters
  
  SkiaLerp({
    required this.t,
    this.children = const [],
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaLerp',
      elementProps: {
        't': t,
      },
      children: children,
    );
  }
}

/// Linear to sRGB gamma conversion
class SkiaLinearToSRGBGamma extends DCFStatelessComponent {
  final List<DCFComponentNode> children;
  
  SkiaLinearToSRGBGamma({
    this.children = const [],
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaLinearToSRGBGamma',
      elementProps: {},
      children: children,
    );
  }
}

/// sRGB to Linear gamma conversion
class SkiaSRGBToLinearGamma extends DCFStatelessComponent {
  final List<DCFComponentNode> children;
  
  SkiaSRGBToLinearGamma({
    this.children = const [],
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaSRGBToLinearGamma',
      elementProps: {},
      children: children,
    );
  }
}

