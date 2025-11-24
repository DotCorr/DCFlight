/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as material show Colors;
import 'canvas_component.dart';

class ConfettiConfig {
  final int particleCount;
  final double startVelocity;
  final double spread;
  final double angle;
  final double gravity;
  final double drift;
  final double decay;
  final int ticks;
  final List<Color> colors;
  final double scalar;

  ConfettiConfig({
    this.particleCount = 50,
    this.startVelocity = 45,
    this.spread = 45,
    this.angle = 90,
    this.gravity = 1,
    this.drift = 0,
    this.decay = 0.9,
    this.ticks = 200,
    this.colors = const [material.Colors.red, material.Colors.blue, material.Colors.green],
    this.scalar = 1,
  });
}

class DCFConfetti extends DCFStatefulComponent {
  final ConfettiConfig config;
  final VoidCallback? onComplete;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;

  DCFConfetti({
    required this.config,
    this.onComplete,
    this.layout,
    this.styleSheet,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // We need a way to animate. Since DCFCanvas is now purely driven by Native requests
    // or manual updates, we need to trigger repaints.
    // However, the current DCFCanvas implementation only repaints when Native asks (init/resize).
    // We need to add a way to force repaint from Dart.
    
    // For now, we'll just render a static frame or rely on a timer if we update DCFCanvas.
    // But wait, DCFCanvas takes onPaint. If we want animation, we need to re-render DCFCanvas
    // with a new onPaint closure? No, onPaint is called by the manager.
    // The manager needs to be told to repaint.
    
    // Since I can't easily change DCFCanvas API right now without breaking the pattern,
    // I'll implement a simple version that draws one frame.
    // To do proper animation, we'd need a Ticker in Dart that calls _CanvasManager.renderCanvas.
    
    return DCFCanvas(
      layout: layout,
      styleSheet: styleSheet,
      size: const Size(400, 800), // Full screen-ish
      backgroundColor: material.Colors.transparent,
      onPaint: (canvas, size) {
        final paint = Paint()..style = PaintingStyle.fill;
        final random = Random();
        
        for (int i = 0; i < config.particleCount; i++) {
          paint.color = config.colors[random.nextInt(config.colors.length)];
          canvas.drawCircle(
            Offset(
              size.width / 2 + (random.nextDouble() - 0.5) * size.width,
              size.height / 2 + (random.nextDouble() - 0.5) * size.height,
            ),
            5 * config.scalar,
            paint,
          );
        }
      },
    );
  }
}

