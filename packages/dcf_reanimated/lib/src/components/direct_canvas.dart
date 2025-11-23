/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Render from paint callback and update pixels directly
  /// 
  /// Takes a paint callback (same as DCFCanvas.onPaint), renders it to
  /// dart:ui Canvas, converts to pixels, and sends directly to native.
  /// No VDOM involvement - pure pixel manipulation.
  /// 
  /// This is what DCFCanvas uses internally for all rendering.
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

