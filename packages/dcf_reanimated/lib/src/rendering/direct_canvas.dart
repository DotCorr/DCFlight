/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dcflight/dcflight.dart';
import 'command_canvas.dart';

/// Wrapper to make CommandCanvas compatible with ui.Canvas type
/// This allows us to use CommandCanvas where ui.Canvas is expected
class _CanvasWrapper implements ui.Canvas {
  final CommandCanvas _commandCanvas;
  
  _CanvasWrapper(this._commandCanvas);
  
  // Delegate all methods to CommandCanvas
  @override
  void save() => _commandCanvas.save();
  
  @override
  void restore() => _commandCanvas.restore();
  
  @override
  void translate(double dx, double dy) => _commandCanvas.translate(dx, dy);
  
  @override
  void rotate(double radians) => _commandCanvas.rotate(radians);
  
  @override
  void scale(double sx, [double? sy]) => _commandCanvas.scale(sx, sy);
  
  @override
  void skew(double sx, double sy) => _commandCanvas.skew(sx, sy);
  
  @override
  void transform(Float64List matrix4) => _commandCanvas.transform(matrix4);
  
  @override
  void clipRect(ui.Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) =>
      _commandCanvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  
  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) =>
      _commandCanvas.clipPath(path, doAntiAlias: doAntiAlias);
  
  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) =>
      _commandCanvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  
  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => _commandCanvas.drawRect(rect, paint);
  
  @override
  void drawCircle(ui.Offset center, double radius, ui.Paint paint) =>
      _commandCanvas.drawCircle(center, radius, paint);
  
  @override
  void drawOval(ui.Rect rect, ui.Paint paint) => _commandCanvas.drawOval(rect, paint);
  
  @override
  void drawArc(ui.Rect rect, double startAngle, double sweepAngle, bool useCenter, ui.Paint paint) =>
      _commandCanvas.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  
  @override
  void drawPath(ui.Path path, ui.Paint paint) => _commandCanvas.drawPath(path, paint);
  
  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) =>
      _commandCanvas.drawLine(p1, p2, paint);
  
  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) => _commandCanvas.drawRRect(rrect, paint);
  
  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) =>
      _commandCanvas.drawDRRect(outer, inner, paint);
  
  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) =>
      _commandCanvas.drawImage(image, offset, paint);
  
  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) =>
      _commandCanvas.drawImageRect(image, src, dst, paint);
  
  @override
  void drawImageNine(ui.Image image, ui.Rect center, ui.Rect dst, ui.Paint paint) =>
      _commandCanvas.drawImageNine(image, center, dst, paint);
  
  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) =>
      _commandCanvas.drawParagraph(paragraph, offset);
  
  @override
  void drawPoints(ui.PointMode pointMode, List<ui.Offset> points, ui.Paint paint) =>
      _commandCanvas.drawPoints(pointMode, points, paint);
  
  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, ui.Paint paint) =>
      _commandCanvas.drawRawPoints(pointMode, points, paint);
  
  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) =>
      _commandCanvas.drawColor(color, blendMode);
  
  @override
  void drawPaint(ui.Paint paint) => _commandCanvas.drawPaint(paint);
  
  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) => _commandCanvas.saveLayer(bounds, paint);
  
  @override
  int getSaveCount() => throw UnimplementedError('getSaveCount not implemented in CommandCanvas');
  
  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, ui.Paint paint) {
    throw UnimplementedError('drawVertices not implemented in CommandCanvas');
  }
  
  @override
  void drawAtlas(ui.Image atlas, List<ui.RSTransform> transforms, List<ui.Rect> rects,
      List<ui.Color>? colors, ui.BlendMode? blendMode, ui.Rect? cullRect, ui.Paint paint) {
    throw UnimplementedError('drawAtlas not implemented in CommandCanvas');
  }
  
  @override
  void drawShadow(ui.Path path, ui.Color color, double elevation, bool transparentOccluder) {
    throw UnimplementedError('drawShadow not implemented in CommandCanvas');
  }
  
  @override
  void clipRSuperellipse(ui.RSuperellipse rsuperellipse, {bool doAntiAlias = true}) {
    throw UnimplementedError('clipRSuperellipse not implemented in CommandCanvas');
  }
  
  @override
  void drawPicture(ui.Picture picture) {
    throw UnimplementedError('drawPicture not implemented in CommandCanvas');
  }
  
  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, ui.Paint paint) {
    throw UnimplementedError('drawRSuperellipse not implemented in CommandCanvas');
  }
  
  @override
  void drawRawAtlas(ui.Image atlas, Float32List rstTransforms, Float32List rects,
      Int32List? colors, ui.BlendMode? blendMode, ui.Rect? cullRect, ui.Paint paint) {
    throw UnimplementedError('drawRawAtlas not implemented in CommandCanvas');
  }
  
  @override
  ui.Rect getDestinationClipBounds() {
    throw UnimplementedError('getDestinationClipBounds not implemented in CommandCanvas');
  }
  
  @override
  ui.Rect getLocalClipBounds() {
    throw UnimplementedError('getLocalClipBounds not implemented in CommandCanvas');
  }
  
  @override
  Float64List getTransform() {
    throw UnimplementedError('getTransform not implemented in CommandCanvas');
  }
  
  @override
  void restoreToCount(int count) {
    throw UnimplementedError('restoreToCount not implemented in CommandCanvas');
  }
}

/// Direct pixel manipulation API - bypasses VDOM completely
/// 
/// Use this for direct pixel updates without any VDOM overhead.
/// All updates go directly to native via Flutter texture registry.
/// Perfect for hot reload and high-frequency updates (60fps).
/// 
/// This is the core rendering engine used by DCFCanvas behind the scenes.
class DirectCanvas {
  /// Update pixels directly - zero VDOM overhead, works with hot reload
  /// 
  /// This bypasses VDOM reconciliation entirely. The canvas view must
  /// already exist (created via DCFCanvas component for layout/positioning).
  /// All pixel updates go directly to native via tunnel.
  static Future<bool> updatePixels({
    required String canvasId,
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {
      'canvasId': canvasId,
      'pixels': pixels,
      'width': width,
      'height': height,
    });
    return result == true;
  }
  
  /// Update canvas with drawing commands - zero VDOM overhead
  /// 
  /// Sends drawing commands instead of pixels. Much smaller data transfer.
  /// Commands are executed on native Skia directly.
  static Future<bool> updateCommands({
    required String canvasId,
    required List<Map<String, dynamic>> commands,
    required int width,
    required int height,
  }) async {
    final result = await FrameworkTunnel.call('Canvas', 'updateCommands', {
      'canvasId': canvasId,
      'commands': commands,
      'width': width,
      'height': height,
    });
    return result == true;
  }

  /// Render from paint callback using COMMAND EXTRACTION (Phase 3)
  /// 
  /// Records drawing commands instead of converting to pixels.
  /// Commands are much smaller and can be executed on native Skia directly.
  /// 
  /// This is the new approach - eliminates pixel conversion overhead.
  static Future<bool> renderAndUpdateWithCommands({
    required String canvasId,
    required void Function(ui.Canvas canvas, Size size) onPaint,
    required Size size,
    Color? backgroundColor,
  }) async {
    try {
      // Create picture recorder and real canvas for validation
      final recorder = ui.PictureRecorder();
      final realCanvas = ui.Canvas(recorder);
      
      // Create command-recording canvas wrapper
      final commandCanvas = CommandCanvas(realCanvas);

      // Draw background if provided
      if (backgroundColor != null) {
        commandCanvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = backgroundColor,
        );
      }

      // Call user's paint function - commands are recorded automatically
      // CommandCanvas has the same interface as ui.Canvas, so we can use it directly
      // We use a wrapper to satisfy the type system while maintaining functionality
      final wrapper = _CanvasWrapper(commandCanvas);
      onPaint(wrapper, size);

      // Get recorded commands
      final commands = commandCanvas.getCommands();
      
      if (commands.isEmpty) {
        print('⚠️ DirectCanvas: No commands recorded');
        return false;
      }
      
      // Send commands directly to native via tunnel (bypasses VDOM)
      // Commands are tiny compared to pixels!
      return await updateCommands(
        canvasId: canvasId,
        commands: commands,
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
    } catch (e, stackTrace) {
      print('❌ DirectCanvas: Error rendering with commands: $e');
      print('❌ DirectCanvas: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Render from paint callback and update pixels directly (LEGACY - kept for compatibility)
  /// 
  /// Takes a paint callback (same as DCFCanvas.onPaint), renders it to
  /// dart:ui Canvas, converts to pixels, and sends directly to native.
  /// No VDOM involvement - pure pixel manipulation.
  /// 
  /// This is what DCFCanvas uses internally for all rendering.
  /// 
  /// NOTE: This is the old pixel-based approach. Use renderAndUpdateWithCommands() for better performance.
  static Future<bool> renderAndUpdate({
    required String canvasId,
    required void Function(ui.Canvas canvas, Size size) onPaint,
    required Size size,
    Color? backgroundColor,
  }) async {
    try {
      // Create picture recorder and canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw background if provided
      if (backgroundColor != null) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = backgroundColor,
        );
      }

      // Call user's paint function
      onPaint(canvas, size);

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      if (byteData == null) {
        print('⚠️ DirectCanvas: Failed to get byteData from image (size: ${size.width}x${size.height})');
        return false;
      }
      
      final expectedBytes = size.width.toInt() * size.height.toInt() * 4;
      if (byteData.lengthInBytes != expectedBytes) {
        print('⚠️ DirectCanvas: ByteData size mismatch - expected $expectedBytes, got ${byteData.lengthInBytes}');
        return false;
      }
      
      // Send pixels directly to native via tunnel (bypasses VDOM)
      return await updatePixels(
        canvasId: canvasId,
        pixels: byteData.buffer.asUint8List(),
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
    } catch (e, stackTrace) {
      print('❌ DirectCanvas: Error rendering: $e');
      print('❌ DirectCanvas: Stack trace: $stackTrace');
      return false;
    }
  }
}

