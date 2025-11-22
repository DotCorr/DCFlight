/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/services.dart';

/// Canvas component that renders using dart:ui via Flutter's CustomPaint
/// Users can use Flutter's Canvas APIs directly (Paint, Path, Shader, etc.)
class DCFCanvas extends DCFStatefulComponent {
  /// Paint callback - users draw using Flutter's Canvas
  final void Function(ui.Canvas canvas, Size size)? onPaint;

  /// Whether to repaint on every frame (for animations)
  final bool repaintOnFrame;

  /// Background color
  final Color? backgroundColor;

  /// Layout properties
  final DCFLayout? layout;

  /// Style properties
  final DCFStyleSheet? styleSheet;

  /// Canvas size
  final Size size;

  DCFCanvas({
    this.onPaint,
    this.repaintOnFrame = false,
    this.backgroundColor,
    this.size = const Size(300, 300),
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    super.key,
  })  : layout = layout,
        styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    // Generate a unique ID for this canvas instance to allow pixel transfer
    final canvasId = useMemo(() => UniqueKey().toString(), dependencies: []);

    // Build props map for native component
    final props = <String, dynamic>{
      'canvasId': canvasId,
      'repaintOnFrame': repaintOnFrame,
      'width': size.width,
      'height': size.height,
      'hasOnPaint': onPaint != null,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!.value,
      ...?layout?.toMap(),
      ...?styleSheet?.toMap(),
    };

    // If we have an onPaint callback, we need to render it to an image
    // and send the pixels to the native side.
    // We use a post-frame callback to do this rendering to avoid blocking the build.
    if (onPaint != null) {
      // Schedule rendering after layout
      _renderToNative(canvasId);
    }

    // Create DCF element that will be rendered by native component
    return DCFElement(
      type: 'Canvas',
      elementProps: props,
      children: const [],
    );
  }

  void _renderToNative(String canvasId) async {
    if (onPaint == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw background
    if (backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor!,
      );
    }

    // Call user's paint function
    onPaint!(canvas, size);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData != null) {
      // Send pixels to native via Tunnel
      await FrameworkTunnel.call('Canvas', 'updateTexture', {
        'canvasId': canvasId,
        'pixels': byteData.buffer.asUint8List(),
        'width': size.width.toInt(),
        'height': size.height.toInt(),
      });
    }
  }
}
