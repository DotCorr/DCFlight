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
import 'dart:async';

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
    // Generate a stable unique ID for this canvas instance
    // Use useRef to ensure it persists across reconciliation without triggering re-renders
    final canvasIdRef = useRef<String?>(null);
    if (canvasIdRef.current == null) {
      // Initialize once - use key if available, otherwise generate a new one
      final id = key != null
          ? (key is ValueKey
              ? (key as ValueKey).value.toString()
              : key.toString())
          : UniqueKey().toString();
      canvasIdRef.current = id;
    }
    final canvasId = canvasIdRef.current!;

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
    if (onPaint != null) {
      if (repaintOnFrame) {
        // For animations, set up continuous rendering on every frame (~60fps)
        // Include onPaint in dependencies to ensure timer uses latest callback
        useEffect(() {
          print('🎨 DCFCanvas: Setting up continuous rendering for canvasId: $canvasId');
          Timer? frameTimer;
          bool isViewReady = false;
          
          void renderFrame() {
            if (!isViewReady) {
              // Try to render, and if successful, mark view as ready
              _renderToNative(canvasId).then((success) {
                if (success == true) {
                  isViewReady = true;
                }
              });
            } else {
              // View is ready, render normally
              _renderToNative(canvasId);
            }
          }
          
          // Wait longer initially to ensure view is registered
          Future.delayed(const Duration(milliseconds: 200), () {
            renderFrame();
            // Start periodic rendering at ~60fps (16ms per frame) after initial render
            frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
              renderFrame();
            });
          });
          
          // Cleanup
          return () {
            frameTimer?.cancel();
          };
        }, dependencies: [canvasId, repaintOnFrame]);
      } else {
        // For static rendering, render once after layout
        useEffect(() {
          print('🎨 DCFCanvas: Setting up static rendering for canvasId: $canvasId');
          // Use a delay to ensure the native view is registered
          Future.delayed(const Duration(milliseconds: 200), () async {
            final success = await _renderToNative(canvasId);
            if (success != true) {
              // Retry once more if view wasn't ready
              Future.delayed(const Duration(milliseconds: 100), () {
                _renderToNative(canvasId);
              });
            }
          });
          return null;
        }, dependencies: [canvasId]);
      }
    }

    // Create DCF element that will be rendered by native component
    return DCFElement(
      type: 'Canvas',
      elementProps: props,
      children: const [],
    );
  }

  Future<bool?> _renderToNative(String canvasId) async {
    if (onPaint == null) {
      print('⚠️ DCFCanvas: _renderToNative called but onPaint is null');
      return false;
    }

    try {
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
        // Note: Native side will convert RGBA to BGRA (iOS) or ARGB (Android)
        final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {
          'canvasId': canvasId,
          'pixels': byteData.buffer.asUint8List(),
          'width': size.width.toInt(),
          'height': size.height.toInt(),
        });
        
        // Return result: true = success, false = view not ready, null = error
        return result == true ? true : (result == false ? false : null);
      } else {
        print('⚠️ DCFCanvas: Failed to get byteData from image');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ DCFCanvas: Error rendering: $e');
      print('❌ DCFCanvas: Stack trace: $stackTrace');
      return false;
    }
  }
}
