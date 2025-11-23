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
import 'direct_canvas.dart';

/// Canvas component that renders using dart:ui via Flutter's CustomPaint
/// Users can use Flutter's Canvas APIs directly (Paint, Path, Shader, etc.)
/// 
/// Also supports native particle system rendering via particleConfig prop.
/// When particleConfig is provided, native side handles all rendering
/// with zero bridge calls during animation.
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
    // and send the pixels to the native side via Flutter's texture registry.
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

  /// Render to native using DirectCanvas - bypasses VDOM completely
  /// 
  /// Uses DirectCanvas.renderAndUpdate internally, which handles all
  /// the pixel conversion and tunnel communication. Zero VDOM overhead.
  Future<bool?> _renderToNative(String canvasId) async {
    if (onPaint == null) {
      print('⚠️ DCFCanvas: _renderToNative called but onPaint is null');
      return false;
    }

    // Use DirectCanvas for rendering - bypasses VDOM, direct pixel manipulation
    final success = await DirectCanvas.renderAndUpdate(
      canvasId: canvasId,
      onPaint: onPaint!,
      size: size,
      backgroundColor: backgroundColor,
    );
    
    // Return result: true = success, false = view not ready, null = error
    return success ? true : false;
  }
}
