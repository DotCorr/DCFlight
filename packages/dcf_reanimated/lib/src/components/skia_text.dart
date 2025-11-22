/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'skia_shapes.dart';

/// Text component for rendering text
class SkiaText extends SkiaShape {
  /// Text content
  final String text;
  
  /// Position
  final double x;
  final double y;
  
  /// Font properties
  final String? fontFamily;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  
  /// Text alignment
  final TextAlign? textAlign;
  
  /// Text decoration
  final TextDecoration? decoration;
  final Color? decorationColor;
  final double? decorationThickness;
  
  /// Text direction
  final TextDirection? textDirection;
  
  /// Maximum width for text wrapping
  final double? maxWidth;
  
   SkiaText({
    required this.text,
    required this.x,
    required this.y,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.textAlign,
    this.decoration,
    this.decorationColor,
    this.decorationThickness,
    this.textDirection,
    this.maxWidth,
    super.color,
    super.opacity,
    super.blendMode,
    super.antiAlias,
    super.zIndex,
    super.children,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaText',
      elementProps: {
        'text': text,
        'x': x,
        'y': y,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontSize != null) 'fontSize': fontSize,
        if (fontWeight != null) 'fontWeight': fontWeight!.index,
        if (fontStyle != null) 'fontStyle': fontStyle!.index,
        if (textAlign != null) 'textAlign': textAlign!.index,
        if (decoration != null) 'decoration': decoration.toString(),
        if (decorationColor != null) 'decorationColor': decorationColor!.value,
        if (decorationThickness != null) 'decorationThickness': decorationThickness,
        if (textDirection != null) 'textDirection': textDirection!.index,
        if (maxWidth != null) 'maxWidth': maxWidth,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

