/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:dcflight/framework/utils/widget_to_dcf_adaptor.dart';

/// Canvas drawing callback - receives Flutter's Canvas and Size
/// This uses dart:ui Canvas API (Impeller/Skia) directly
typedef DCFCanvasPainter = void Function(ui.Canvas canvas, ui.Size size);

/// Canvas component properties
class DCFCanvasProps {
  /// Custom painter function that receives Canvas and Size
  /// Use this to draw directly using Flutter's rendering engine
  final DCFCanvasPainter? onPaint;
  
  /// Whether to repaint on every frame (for animations)
  final bool repaintOnFrame;
  
  /// Background color
  final Color? backgroundColor;
  
  /// Create canvas component props
  const DCFCanvasProps({
    this.onPaint,
    this.repaintOnFrame = false,
    this.backgroundColor,
  });
}

/// Canvas component for direct drawing using Flutter's rendering engine
/// 
/// Uses dart:ui Canvas API (Impeller on iOS/Android, Skia elsewhere).
/// Provides direct access to Flutter's graphics primitives for custom rendering.
/// 
/// This component uses Flutter's CustomPaint widget internally to access
/// the underlying Impeller/Skia rendering engine.
class DCFCanvas extends DCFStatelessComponent {
  /// Canvas properties
  final DCFCanvasProps props;
  
  /// Layout properties
  final DCFLayout layout;
  
  /// Style properties
  final DCFStyleSheet styleSheet;
  
  /// Create a canvas component
  DCFCanvas({
    required this.props,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Use WidgetToDCFAdaptor to embed CustomPaint directly
    // This directly embeds Flutter's rendering pipeline (Impeller/Skia)
    return WidgetToDCFAdaptor(
      widget: CustomPaint(
        painter: props.onPaint != null
            ? _CanvasPainter(
                painter: props.onPaint!,
                repaintOnFrame: props.repaintOnFrame,
              )
            : null, // Empty painter if none provided
        child: props.backgroundColor != null
            ? Container(color: props.backgroundColor)
            : null,
      ),
      layout: layout,
      styleSheet: styleSheet,
    ).render();
  }
}

/// Custom painter that wraps the DCF canvas painter
class _CanvasPainter extends CustomPainter {
  final DCFCanvasPainter painter;
  final bool repaintOnFrame;
  
  _CanvasPainter({
    required this.painter,
    required this.repaintOnFrame,
  });
  
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    painter(canvas, size);
  }
  
  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) {
    return repaintOnFrame || oldDelegate.painter != painter;
  }
}

/// Canvas tunnel methods for direct drawing operations
class DCFCanvasTunnel {
  /// Request a repaint of the canvas
  static Future<bool> requestRepaint(String viewId) async {
    final result = await FrameworkTunnel.call(
      "Canvas",
      "requestRepaint",
      {"viewId": viewId},
    );
    return result == true;
  }
  
  /// Get canvas size
  static Future<Map<String, dynamic>?> getSize(String viewId) async {
    final result = await FrameworkTunnel.call(
      "Canvas",
      "getSize",
      {"viewId": viewId},
    );
    return result as Map<String, dynamic>?;
  }
}

