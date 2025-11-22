/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

// ============================================================================
// PAINT PROPERTIES
// ============================================================================

/// Paint style for shapes
enum SkiaPaintStyle {
  fill,
  stroke,
}

/// Blend mode for compositing
enum SkiaBlendMode {
  clear,
  src,
  dst,
  srcOver,
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcATop,
  dstATop,
  xor,
  plus,
  modulate,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  multiply,
  hue,
  saturation,
  color,
  luminosity,
}

/// Stroke join style
enum SkiaStrokeJoin {
  miter,
  round,
  bevel,
}

/// Stroke cap style
enum SkiaStrokeCap {
  butt,
  round,
  square,
}

// ============================================================================
// BASE SHAPE COMPONENT
// ============================================================================

/// Base class for all Skia shape components
abstract class SkiaShape extends DCFStatelessComponent {
  /// Paint color (ARGB int or CSS color string)
  final dynamic color;
  
  /// Paint opacity (0.0 to 1.0)
  final double? opacity;
  
  /// Blend mode
  final SkiaBlendMode? blendMode;
  
  /// Paint style (fill or stroke)
  final SkiaPaintStyle? style;
  
  /// Stroke width
  final double? strokeWidth;
  
  /// Stroke join
  final SkiaStrokeJoin? strokeJoin;
  
  /// Stroke cap
  final SkiaStrokeCap? strokeCap;
  
  /// Stroke miter limit
  final double? strokeMiter;
  
  /// Anti-aliasing
  final bool? antiAlias;
  
  /// Z-index for drawing order
  final int? zIndex;
  
  /// Children (for shaders, filters, path effects, etc.)
  final List<DCFComponentNode> children;
  
  SkiaShape({
    this.color,
    this.opacity,
    this.blendMode,
    this.style,
    this.strokeWidth,
    this.strokeJoin,
    this.strokeCap,
    this.strokeMiter,
    this.antiAlias,
    this.zIndex,
    this.children = const [],
    super.key,
  });
  
  /// Convert paint properties to map
  Map<String, dynamic> getPaintProps() {
    return {
      if (color != null) 'color': color is int ? color : color.toString(),
      if (opacity != null) 'opacity': opacity,
      if (blendMode != null) 'blendMode': blendMode!.name,
      if (style != null) 'style': style!.name,
      if (strokeWidth != null) 'strokeWidth': strokeWidth,
      if (strokeJoin != null) 'strokeJoin': strokeJoin!.name,
      if (strokeCap != null) 'strokeCap': strokeCap!.name,
      if (strokeMiter != null) 'strokeMiter': strokeMiter,
      if (antiAlias != null) 'antiAlias': antiAlias,
      if (zIndex != null) 'zIndex': zIndex,
    };
  }
}

// ============================================================================
// SHAPES
// ============================================================================

/// Rectangle shape
class SkiaRect extends SkiaShape {
  final double x;
  final double y;
  final double width;
  final double height;
  
  SkiaRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    super.color,
    super.opacity,
    super.blendMode,
    super.style,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaRect',
      elementProps: {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        ...getPaintProps(),
      },
      children: const [],
    );
  }
}

/// Rounded rectangle shape
class SkiaRoundedRect extends SkiaShape {
  final double x;
  final double y;
  final double width;
  final double height;
  final double? r; // Corner radius (uniform)
  final double? rx; // X corner radius
  final double? ry; // Y corner radius
  
  SkiaRoundedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.r,
    this.rx,
    this.ry,
    super.color,
    super.opacity,
    super.blendMode,
    super.style,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaRoundedRect',
      elementProps: {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        if (r != null) 'r': r,
        if (rx != null) 'rx': rx,
        if (ry != null) 'ry': ry,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

/// Circle shape
class SkiaCircle extends SkiaShape {
  final double cx;
  final double cy;
  final double r;
  
  SkiaCircle({
    required this.cx,
    required this.cy,
    required this.r,
    super.color,
    super.opacity,
    super.blendMode,
    super.style,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaCircle',
      elementProps: {
        'cx': cx,
        'cy': cy,
        'r': r,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

/// Oval shape
class SkiaOval extends SkiaShape {
  final double x;
  final double y;
  final double width;
  final double height;
  
  SkiaOval({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    super.color,
    super.opacity,
    super.blendMode,
    super.style,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaOval',
      elementProps: {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

/// Line shape
class SkiaLine extends SkiaShape {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  
  SkiaLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    super.color,
    super.opacity,
    super.blendMode,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  }) : super(style: SkiaPaintStyle.stroke);
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaLine',
      elementProps: {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

/// Path shape (SVG path string or path object)
class SkiaPath extends SkiaShape {
  final String? pathString;
  final dynamic pathObject; // For future native path object support
  
  /// Trim start (0.0 to 1.0)
  final double? start;
  
  /// Trim end (0.0 to 1.0)
  final double? end;
  
  /// Fill type (winding, evenOdd, etc.)
  final String? fillType;
  
  SkiaPath({
    this.pathString,
    this.pathObject,
    this.start,
    this.end,
    this.fillType,
    super.color,
    super.opacity,
    super.blendMode,
    super.style,
    super.strokeWidth,
    super.strokeJoin,
    super.strokeCap,
    super.strokeMiter,
    super.antiAlias,
    super.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaPath',
      elementProps: {
        if (pathString != null) 'pathString': pathString,
        if (pathObject != null) 'pathObject': pathObject,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
        if (fillType != null) 'fillType': fillType,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

/// Fill component (fills entire canvas)
class SkiaFill extends SkiaShape {
  SkiaFill({
    super.color,
    super.opacity,
    super.blendMode,
    super.antiAlias,
    super.key,
  }) : super(style: SkiaPaintStyle.fill);
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaFill',
      elementProps: getPaintProps(),
      children: children,
    );
  }
}

