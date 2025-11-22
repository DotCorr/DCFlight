/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Discrete Path Effect - breaks path into segments with random deviation
class SkiaDiscretePathEffect extends DCFStatelessComponent {
  final double length;
  final double deviation;
  final double? seed;
  
  SkiaDiscretePathEffect({
    required this.length,
    required this.deviation,
    this.seed,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaDiscretePathEffect',
      elementProps: {
        'length': length,
        'deviation': deviation,
        if (seed != null) 'seed': seed,
      },
      children: const [],
    );
  }
}

/// Dash Path Effect - creates dashed lines
class SkiaDashPathEffect extends DCFStatelessComponent {
  final List<double> intervals;
  final double? phase;
  
  SkiaDashPathEffect({
    required this.intervals,
    this.phase,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaDashPathEffect',
      elementProps: {
        'intervals': intervals,
        if (phase != null) 'phase': phase,
      },
      children: const [],
    );
  }
}

/// Corner Path Effect - rounds sharp corners
class SkiaCornerPathEffect extends DCFStatelessComponent {
  final double r;
  
  SkiaCornerPathEffect({
    required this.r,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaCornerPathEffect',
      elementProps: {
        'r': r,
      },
      children: const [],
    );
  }
}

/// Path 1D Path Effect - stamps a path along another path
class SkiaPath1DPathEffect extends DCFStatelessComponent {
  final String pathString; // SVG path string
  final double advance;
  final double? phase;
  final String? style; // translate, rotate, morph
  
  SkiaPath1DPathEffect({
    required this.pathString,
    required this.advance,
    this.phase,
    this.style,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaPath1DPathEffect',
      elementProps: {
        'pathString': pathString,
        'advance': advance,
        if (phase != null) 'phase': phase,
        if (style != null) 'style': style,
      },
      children: const [],
    );
  }
}

/// Path 2D Path Effect - stamps a path using a matrix
class SkiaPath2DPathEffect extends DCFStatelessComponent {
  final String pathString; // SVG path string
  final List<Map<String, dynamic>>? transform; // Transformation matrix
  
  SkiaPath2DPathEffect({
    required this.pathString,
    this.transform,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaPath2DPathEffect',
      elementProps: {
        'pathString': pathString,
        if (transform != null) 'transform': transform,
      },
      children: const [],
    );
  }
}

/// Line 2D Path Effect
class SkiaLine2DPathEffect extends DCFStatelessComponent {
  final double width;
  final List<Map<String, dynamic>>? transform; // Transformation matrix
  
  SkiaLine2DPathEffect({
    required this.width,
    this.transform,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaLine2DPathEffect',
      elementProps: {
        'width': width,
        if (transform != null) 'transform': transform,
      },
      children: const [],
    );
  }
}

