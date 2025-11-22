/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'skia_shapes.dart';

/// Group component for applying transformations, clipping, and paint to children
/// Similar to React Native Skia's Group component
class SkiaGroup extends DCFStatelessComponent {
  /// Children shapes/components
  final List<DCFComponentNode> children;
  
  /// Paint properties (inherited by children)
  final dynamic color;
  final double? opacity;
  final SkiaBlendMode? blendMode;
  final SkiaPaintStyle? style;
  final double? strokeWidth;
  final SkiaStrokeJoin? strokeJoin;
  final SkiaStrokeCap? strokeCap;
  final double? strokeMiter;
  final bool? antiAlias;
  
  /// Transformations
  final List<Map<String, dynamic>>? transform; // [{translateX: 10}, {rotate: 45}, etc.]
  final Map<String, double>? origin; // {x: 0, y: 0} - transformation origin
  
  /// Clipping
  final Map<String, dynamic>? clip; // Rect, RRect, or Path
  final bool? invertClip;
  
  /// Layer effects (for applying filters to group)
  final Map<String, dynamic>? layer; // Paint with filters
  
  /// Z-index for drawing order
  final int? zIndex;
  
   SkiaGroup({
    this.children = const [],
    this.color,
    this.opacity,
    this.blendMode,
    this.style,
    this.strokeWidth,
    this.strokeJoin,
    this.strokeCap,
    this.strokeMiter,
    this.antiAlias,
    this.transform,
    this.origin,
    this.clip,
    this.invertClip,
    this.layer,
    this.zIndex,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    final props = <String, dynamic>{
      if (color != null) 'color': color is int ? color : color.toString(),
      if (opacity != null) 'opacity': opacity,
      if (blendMode != null) 'blendMode': blendMode!.name,
      if (style != null) 'style': style!.name,
      if (strokeWidth != null) 'strokeWidth': strokeWidth,
      if (strokeJoin != null) 'strokeJoin': strokeJoin!.name,
      if (strokeCap != null) 'strokeCap': strokeCap!.name,
      if (strokeMiter != null) 'strokeMiter': strokeMiter,
      if (antiAlias != null) 'antiAlias': antiAlias,
      if (transform != null) 'transform': transform,
      if (origin != null) 'origin': origin,
      if (clip != null) 'clip': clip,
      if (invertClip != null) 'invertClip': invertClip,
      if (layer != null) 'layer': layer,
      if (zIndex != null) 'zIndex': zIndex,
    };
    
    return DCFElement(
      type: 'SkiaGroup',
      elementProps: props,
      children: children,
    );
  }
}

