/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;
import 'skia_shapes.dart' show SkiaPaintStyle, SkiaPath;
import 'skia_image.dart' show SkiaImage;

/// Skia Canvas drawing callback - receives Skia Canvas and Size
/// This provides direct access to Skia's full 2D graphics API
typedef DCFCanvasPainter = void Function(SkiaCanvas canvas, Size size);

/// Skia Canvas wrapper for type-safe GPU rendering
/// 
/// Provides access to Skia's full 2D graphics API including:
/// - Paths, shapes, text
/// - Gradients, shaders, filters
/// - Transformations, clipping
/// - Image rendering
class SkiaCanvas {
  // ignore: unused_field
  final dynamic _nativeCanvas; // Native Skia canvas (C++ object) - placeholder for future native integration
  
  SkiaCanvas(this._nativeCanvas);
  
  /// Draw a path
  void drawPath(SkiaPath path, SkiaPaint paint) {
    // Native call to Skia canvas drawPath
  }
  
  /// Draw a rectangle
  void drawRect(double left, double top, double right, double bottom, SkiaPaint paint) {
    // Native call to Skia canvas drawRect
  }
  
  /// Draw a circle
  void drawCircle(double x, double y, double radius, SkiaPaint paint) {
    // Native call to Skia canvas drawCircle
  }
  
  /// Draw text
  void drawText(String text, double x, double y, SkiaPaint paint) {
    // Native call to Skia canvas drawText
  }
  
  /// Draw an image
  void drawImage(SkiaImage image, double x, double y, SkiaPaint? paint) {
    // Native call to Skia canvas drawImage
  }
  
  /// Save canvas state
  void save() {
    // Native call to Skia canvas save
  }
  
  /// Restore canvas state
  void restore() {
    // Native call to Skia canvas restore
  }
  
  /// Translate canvas
  void translate(double dx, double dy) {
    // Native call to Skia canvas translate
  }
  
  /// Rotate canvas
  void rotate(double degrees) {
    // Native call to Skia canvas rotate
  }
  
  /// Scale canvas
  void scale(double sx, double sy) {
    // Native call to Skia canvas scale
  }
  
  /// Clip path
  void clipPath(SkiaPath path) {
    // Native call to Skia canvas clipPath
  }
}

/// Skia Paint for styling
class SkiaPaint {
  // ignore: unused_field
  final dynamic _nativePaint; // Native Skia paint (C++ object) - placeholder for future native integration
  
  Color _color = const Color(0xFF000000); // Default black
  SkiaPaintStyle _style = SkiaPaintStyle.fill;
  double _strokeWidth = 1.0;
  SkiaShader? _shader;
  int _alpha = 255;
  
  SkiaPaint() : _nativePaint = null; // Will be created natively
  
  /// Get or set color
  Color get color => _color;
  set color(Color value) {
    _color = value;
    setColor(value.value);
  }
  
  /// Get or set style (fill or stroke)
  SkiaPaintStyle get style => _style;
  set style(SkiaPaintStyle value) {
    _style = value;
    setStyle(value);
  }
  
  /// Get or set stroke width
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    _strokeWidth = value;
    setStrokeWidth(value);
  }
  
  /// Get or set shader
  SkiaShader? get shader => _shader;
  set shader(SkiaShader? value) {
    _shader = value;
    setShader(value);
  }
  
  /// Get or set alpha (0-255)
  int get alpha => _alpha;
  set alpha(int value) {
    _alpha = value.clamp(0, 255);
    setAlpha(_alpha);
  }
  
  /// Set color (ARGB)
  void setColor(int color) {
    _color = Color(color);
  }
  
  /// Set stroke width
  void setStrokeWidth(double width) {
    _strokeWidth = width;
  }
  
  /// Set style (fill or stroke)
  void setStyle(SkiaPaintStyle style) {
    _style = style;
  }
  
  /// Set shader
  void setShader(SkiaShader? shader) {
    _shader = shader;
  }
  
  /// Set alpha
  void setAlpha(int alpha) {
    _alpha = alpha.clamp(0, 255);
  }
}

/// Skia Shader for gradients and effects
class SkiaShader {
  // ignore: unused_field
  final dynamic _nativeShader; // Native Skia shader (C++ object) - placeholder for future native integration
  
  SkiaShader(this._nativeShader);
  
  /// Create linear gradient
  factory SkiaShader.linearGradient(
    double x0, double y0,
    double x1, double y1,
    List<int> colors,
    List<double>? stops,
  ) {
    // Native call to create linear gradient
    return SkiaShader(null);
  }
  
  /// Create radial gradient
  factory SkiaShader.radialGradient(
    double cx, double cy, double radius,
    List<int> colors,
    List<double>? stops,
  ) {
    // Native call to create radial gradient
    return SkiaShader(null);
  }
}

/// Canvas size
class Size {
  final double width;
  final double height;
  
  const Size(this.width, this.height);
}

/// Canvas component for Skia-based GPU rendering
/// 
/// [DCFCanvas] provides direct access to Skia's full 2D graphics API
/// for high-performance GPU-accelerated rendering on both iOS and Android.
/// 
/// Uses Skia natively on both platforms for consistent, type-safe GPU rendering.
class DCFCanvas extends DCFStatelessComponent {
  /// Canvas painter callback
  final DCFCanvasPainter? onPaint;
  
  /// Whether to repaint on every frame (for animations)
  final bool repaintOnFrame;
  
  /// Background color
  final Color? backgroundColor;
  
  /// Layout properties
  final DCFLayout? layout;
  
  /// Style properties
  final DCFStyleSheet? styleSheet;
  
  
  // Default layouts and styles for canvas (registered for bridge efficiency)
  // ignore: deprecated_member_use - Using DCFLayout()/DCFStyleSheet() inside create() is the correct pattern
  static final _canvasLayouts = DCFLayout.create({
    'default': DCFLayout(),
  });
  
  static final _canvasStyles = DCFStyleSheet.create({
    'default': DCFStyleSheet(),
  });
  
  /// Children components to render (Rect, Circle, Path, etc.)
  final List<DCFComponentNode> children;
  
  /// Create a Skia canvas component
  DCFCanvas({
    this.onPaint,
    this.repaintOnFrame = false,
    this.backgroundColor,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    this.children = const [],
    super.key,
  }) : layout = layout,
       styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    // Collect shape data from children
    final shapeData = _collectShapeData(children);
    
    Map<String, dynamic> props = {
      'onPaint': onPaint != null,
      'repaintOnFrame': repaintOnFrame,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!.value,
      if (shapeData.isNotEmpty) 'shapes': shapeData,
      ...(layout ?? _canvasLayouts['default'] as DCFLayout).toMap(),
      ...(styleSheet ?? _canvasStyles['default'] as DCFStyleSheet).toMap(),
    };

    return DCFElement(
      type: 'Canvas', // Native Skia canvas component
      elementProps: props,
      children: children,
    );
  }
  
  /// Collect shape data from children recursively, preserving group hierarchy
  List<Map<String, dynamic>> _collectShapeData(List<DCFComponentNode> children) {
    final shapes = <Map<String, dynamic>>[];
    
    for (final child in children) {
      if (child is DCFElement) {
        final type = child.type;
        
        if (type == 'SkiaGroup') {
          // Handle Group - collect its children and add group metadata
          final groupData = Map<String, dynamic>.from(child.elementProps);
          groupData['_type'] = type;
          
          // Collect children shapes
          final groupChildren = _collectShapeData(child.children);
          if (groupChildren.isNotEmpty) {
            groupData['_children'] = groupChildren;
          }
          
          shapes.add(groupData);
        } else if (type == 'SkiaMask') {
          // Mask component - first child is mask, rest are content
          final maskData = Map<String, dynamic>.from(child.elementProps);
          maskData['_type'] = 'SkiaGroup';
          maskData['_maskMode'] = maskData['mode'] ?? 'alpha';
          maskData['_maskClip'] = maskData['clip'] ?? false;
          
          final allChildren = child.children;
          if (allChildren.isNotEmpty) {
            // First child is the mask
            maskData['_maskContent'] = _collectShapeData([allChildren[0]]);
            // Rest are content to be masked
            if (allChildren.length > 1) {
              maskData['_children'] = _collectShapeData(allChildren.sublist(1));
            }
          }
          
          shapes.add(maskData);
        } else if (type.startsWith('Skia')) {
          // Regular shape
          final shapeData = Map<String, dynamic>.from(child.elementProps);
          shapeData['_type'] = type;
          
          // Check if shape has shader/filter children
          final shaderChildren = child.children.where((c) => 
            c is DCFElement && c.type.startsWith('Skia') && 
            (c.type.contains('Gradient') || c.type.contains('Shader'))
          ).toList();
          
          if (shaderChildren.isNotEmpty) {
            shapeData['_shader'] = _collectShapeData(shaderChildren).firstOrNull;
          }
          
          final filterChildren = child.children.where((c) => 
            c is DCFElement && c.type.startsWith('Skia') && 
            (c.type.contains('Filter') || c.type.contains('Blur') || c.type.contains('Shadow'))
          ).toList();
          
          if (filterChildren.isNotEmpty) {
            shapeData['_filters'] = _collectShapeData(filterChildren);
          }
          
          final pathEffectChildren = child.children.where((c) => 
            c is DCFElement && c.type.startsWith('Skia') && 
            c.type.contains('PathEffect')
          ).toList();
          
          if (pathEffectChildren.isNotEmpty) {
            shapeData['_pathEffect'] = _collectShapeData(pathEffectChildren).firstOrNull;
          }
          
          final colorFilterChildren = child.children.where((c) => 
            c is DCFElement && c.type.startsWith('Skia') && 
            (c.type.contains('ColorFilter') || c.type.contains('ColorMatrix') || c.type.contains('BlendColor'))
          ).toList();
          
          if (colorFilterChildren.isNotEmpty) {
            shapeData['_colorFilter'] = _collectShapeData(colorFilterChildren).firstOrNull;
          }
          
          final backdropFilterChildren = child.children.where((c) => 
            c is DCFElement && c.type.startsWith('Skia') && 
            c.type.contains('Backdrop')
          ).toList();
          
          if (backdropFilterChildren.isNotEmpty) {
            shapeData['_backdropFilters'] = _collectShapeData(backdropFilterChildren);
          }
          
          shapes.add(shapeData);
        } else {
          // Recursively collect from nested children
          if (child.children.isNotEmpty) {
            shapes.addAll(_collectShapeData(child.children));
          }
        }
      }
    }
    
    return shapes;
  }
}

