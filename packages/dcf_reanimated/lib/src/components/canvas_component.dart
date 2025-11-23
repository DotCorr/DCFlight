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
    this.layout,
    this.styleSheet,
    super.key,
  });

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
          print('🎨 DCFCanvas: Setting up continuous rendering for canvasId: $canvasId, size: ${size.width}x${size.height}');
          Timer? frameTimer;
          bool isViewReady = false;
          int retryCount = 0;
          const maxRetries = 10;
          
          void renderFrame() {
            // Validate size before rendering
            if (size.width <= 0 || size.height <= 0) {
              if (retryCount < maxRetries) {
                retryCount++;
                print('⚠️ DCFCanvas: Size invalid (${size.width}x${size.height}), retrying... ($retryCount/$maxRetries)');
                return;
              } else {
                print('❌ DCFCanvas: Size invalid after $maxRetries retries, stopping');
                frameTimer?.cancel();
                return;
              }
            }
            
            if (!isViewReady) {
              // Try to render, and if successful, mark view as ready
              _renderToNative(canvasId).then((success) {
                if (success == true) {
                  isViewReady = true;
                  retryCount = 0; // Reset retry count on success
                  print('✅ DCFCanvas: View ready, starting continuous rendering for canvasId: $canvasId');
                } else {
                  retryCount++;
                  if (retryCount >= maxRetries) {
                    print('❌ DCFCanvas: View not ready after $maxRetries attempts, stopping for canvasId: $canvasId');
                    frameTimer?.cancel();
                  }
                }
              });
            } else {
              // View is ready, render normally (no logging to reduce spam)
              _renderToNative(canvasId);
            }
          }
          
          // Wait longer initially to ensure view is registered and laid out by Yoga
          Future.delayed(const Duration(milliseconds: 300), () {
            renderFrame();
            // Start periodic rendering at ~60fps (16ms per frame) after initial render
            frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
              renderFrame();
            });
          });
          
          // Cleanup
          return () {
            frameTimer?.cancel();
            print('🧹 DCFCanvas: Cleaned up continuous rendering for canvasId: $canvasId');
          };
        }, dependencies: [canvasId, repaintOnFrame, size.width, size.height]);
      } else {
        // For static rendering, render once after layout
        useEffect(() {
          print('🎨 DCFCanvas: Setting up static rendering for canvasId: $canvasId, size: ${size.width}x${size.height}');
          // Use a delay to ensure the native view is registered and laid out by Yoga
          Future.delayed(const Duration(milliseconds: 300), () async {
            // Validate size before rendering
            if (size.width <= 0 || size.height <= 0) {
              print('⚠️ DCFCanvas: Invalid size ${size.width}x${size.height}, retrying...');
              // Retry after Yoga layout completes
              Future.delayed(const Duration(milliseconds: 200), () async {
                final success = await _renderToNative(canvasId);
                if (success != true) {
                  print('⚠️ DCFCanvas: Static render failed, view may not be ready');
                }
              });
              return;
            }
            
            final success = await _renderToNative(canvasId);
            if (success != true) {
              // Retry once more if view wasn't ready
              Future.delayed(const Duration(milliseconds: 200), () async {
                await _renderToNative(canvasId);
              });
            }
          });
          return null;
        }, dependencies: [canvasId, size.width, size.height]);
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

    // Validate size - must be > 0
    if (size.width <= 0 || size.height <= 0) {
      print('⚠️ DCFCanvas: Invalid size ${size.width}x${size.height}, skipping render');
      return false;
    }

    // Use DirectCanvas for rendering - bypasses VDOM, direct pixel manipulation
    final success = await DirectCanvas.renderAndUpdate(
      canvasId: canvasId,
      onPaint: onPaint!,
      size: size,
      backgroundColor: backgroundColor,
    );
    
    // Only log failures to reduce log spam (success happens 60fps for animations)
    if (!success) {
      print('⚠️ DCFCanvas: Failed to render to native for canvasId: $canvasId (view may not be ready)');
    }
    
    // Return result: true = success, false = view not ready, null = error
    return success ? true : false;
  }
}
