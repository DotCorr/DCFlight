/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

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

/// Skia Path for drawing shapes
class SkiaPath {
  // ignore: unused_field
  final dynamic _nativePath; // Native Skia path (C++ object) - placeholder for future native integration
  
  SkiaPath() : _nativePath = null; // Will be created natively
  
  /// Move to point
  void moveTo(double x, double y) {}
  
  /// Line to point
  void lineTo(double x, double y) {}
  
  /// Quadratic bezier curve
  void quadTo(double x1, double y1, double x2, double y2) {}
  
  /// Cubic bezier curve
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {}
  
  /// Close path
  void close() {}
  
  /// Add rectangle
  void addRect(double left, double top, double right, double bottom) {}
  
  /// Add circle
  void addCircle(double x, double y, double radius) {}
}

/// Skia Paint for styling
class SkiaPaint {
  // ignore: unused_field
  final dynamic _nativePaint; // Native Skia paint (C++ object) - placeholder for future native integration
  
  SkiaPaint() : _nativePaint = null; // Will be created natively
  
  /// Set color (ARGB)
  void setColor(int color) {}
  
  /// Set stroke width
  void setStrokeWidth(double width) {}
  
  /// Set style (fill or stroke)
  void setStyle(SkiaPaintStyle style) {}
  
  /// Set shader
  void setShader(SkiaShader? shader) {}
  
  /// Set alpha
  void setAlpha(int alpha) {}
}

/// Skia Paint Style
enum SkiaPaintStyle {
  fill,
  stroke,
  strokeAndFill,
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

/// Skia Image
class SkiaImage {
  // ignore: unused_field
  final dynamic _nativeImage; // Native Skia image (C++ object) - placeholder for future native integration
  
  SkiaImage(this._nativeImage);
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
  
  /// Create a Skia canvas component
  DCFCanvas({
    this.onPaint,
    this.repaintOnFrame = false,
    this.backgroundColor,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    super.key,
  }) : layout = layout,
       styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      'onPaint': onPaint != null,
      'repaintOnFrame': repaintOnFrame,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!.value,
      ...(layout ?? _canvasLayouts['default'] as DCFLayout).toMap(),
      ...(styleSheet ?? _canvasStyles['default'] as DCFStyleSheet).toMap(),
    };

    return DCFElement(
      type: 'Canvas', // Native Skia canvas component
      elementProps: props,
      children: const [],
    );
  }
}

