/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;

/// Base class for all canvas commands
sealed class CanvasCommand {
  const CanvasCommand();
  Map<String, dynamic> toMap();
}

/// Command to clear/stop any active animation
class ClearCommand extends CanvasCommand {
  const ClearCommand();

  @override
  Map<String, dynamic> toMap() => {'type': 'clear'};
}

/// Command to start/update confetti animation
class ConfettiCommand extends CanvasCommand {
  final double scalar;
  final double spread;
  final double startVelocity;
  final List<Color> colors;
  final int elementCount;

  const ConfettiCommand({
    required this.scalar,
    required this.spread,
    required this.startVelocity,
    required this.colors,
    required this.elementCount,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'confetti',
        'scalar': scalar,
        'spread': spread,
        'startVelocity': startVelocity,
        'colors': colors
            .map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}')
            .toList(),
        'elementCount': elementCount,
      };
}

/// Canvas component - pure Skia/Flutter texture container
///
/// Architecture:
/// - Static rendering: Dart renders once with Skia → sends texture to native
/// - For animations: Use shared values or describe animations at app layer
///
/// Dart thread: Describes what to render
/// UI thread: Displays the Flutter texture
///
/// For 60fps animations on UI thread, use native animation components
/// (particles, shaders, etc.) - Canvas is for Skia rendering
class DCFCanvas extends DCFStatefulComponent {
  /// Paint callback - users draw using Flutter's Canvas API
  final void Function(ui.Canvas canvas, Size size)? onPaint;

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
    this.backgroundColor,
    this.size = const Size(300, 300),
    this.layout,
    this.styleSheet,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Use a unique ID based on key
    final canvasId = key?.toString() ?? UniqueKey().toString();

    // Register with manager and trigger initial render after first frame
    _CanvasManager.instance.registerCanvas(canvasId, this);

    // Build props map for native component
    final props = <String, dynamic>{
      'canvasId': canvasId,
      'width': size.width,
      'height': size.height,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!.value,
      ...?layout?.toMap(),
      ...?styleSheet?.toMap(),
    };

    // Command Pattern: Send animation config via prop
    if (this is DCFCanvasWithAnimation) {
      final command = (this as DCFCanvasWithAnimation).animationConfig;
      if (command != null) {
        props['canvasCommand'] = command.toMap();
      } else {
        props['canvasCommand'] = const ClearCommand().toMap();
      }
    }

    return DCFElement(
      type: 'Canvas',
      elementProps: props,
      children: const [],
    );
  }
}

/// Manages Canvas rendering and communication with Native via tunnels
/// Renders static content using Flutter/Skia, sends texture to native
class _CanvasManager {
  static final _CanvasManager instance = _CanvasManager._();

  final Map<String, DCFCanvas> _canvases = {};
  final Map<String, Timer?> _renderTimers = {};

  _CanvasManager._();

  void registerCanvas(String id, DCFCanvas canvas) {
    _canvases[id] = canvas;

    // Schedule render after frame is built
    _renderTimers[id]?.cancel();
    _renderTimers[id] = Timer(const Duration(milliseconds: 100), () {
      _renderCanvas(id, canvas.size);
    });
  }

  Future<void> _renderCanvas(String canvasId, Size size) async {
    final canvasComponent = _canvases[canvasId];

    // If we have an animation config, we assume native side handles it via props
    // so we don't need to do anything here for animation.
    if (canvasComponent is DCFCanvasWithAnimation &&
        canvasComponent.animationConfig != null) {
      return;
    }

    if (canvasComponent?.onPaint == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw background if needed
    if (canvasComponent!.backgroundColor != null) {
      canvas.drawColor(canvasComponent.backgroundColor!, ui.BlendMode.src);
    }

    // User drawing
    canvasComponent.onPaint!(canvas, size);

    await _sendPixelsToNative(canvasId, recorder, size);
  }

  Future<void> _sendPixelsToNative(
      String canvasId, ui.PictureRecorder recorder, Size size) async {
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData != null) {
      // Use tunnel to send pixels to native
      final result = await FrameworkTunnel.call('Canvas', 'updatePixels', {
        'canvasId': canvasId,
        'pixels': byteData.buffer.asUint8List(),
        'width': size.width.toInt(),
        'height': size.height.toInt(),
      });

      if (result == false) {
        // View not ready yet, retry
        final canvas = _canvases[canvasId];
        if (canvas != null) {
          Timer(const Duration(milliseconds: 100), () {
            _renderCanvas(canvasId, size);
          });
        }
      }
    }
  }

  void unregisterCanvas(String id) {
    _renderTimers[id]?.cancel();
    _renderTimers.remove(id);
    _canvases.remove(id);
  }
}

/// Extended Canvas interface for components that support native animation
abstract class DCFCanvasWithAnimation extends DCFCanvas {
  CanvasCommand? get animationConfig;

  DCFCanvasWithAnimation({
    super.key,
    super.onPaint,
    super.backgroundColor,
    super.size,
    super.layout,
    super.styleSheet,
  });
}
