/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math';
import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as material show Colors;
import 'canvas_component.dart';

/// Configuration for confetti particle animation
class ConfettiConfig {
  final int particleCount;
  final double startVelocity;
  final double spread;
  final double angle;
  final double gravity;
  final double drift;
  final double decay;
  final int duration; // in milliseconds
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
    this.duration = 3000,
    this.colors = const [
      material.Colors.red,
      material.Colors.blue,
      material.Colors.green,
      material.Colors.yellow,
      material.Colors.purple,
    ],
    this.scalar = 1,
  });
}

/// Particle state for physics simulation
class _ParticleState {
  double x, y, vx, vy;
  final Color color;
  final double radius;
  int life;

  _ParticleState({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    required this.life,
  });
}

/// Confetti component using Canvas with Skia rendering
/// 
/// TODO: Needs worklet/shared value support for 60fps animation
/// Current implementation is static demo
/// 
/// Proper architecture should be:
/// - AnimatedValue driven by native timer (60fps)
/// - Value changes trigger VDOM update → Canvas re-render
/// - Skia renders particles (cross-platform consistent)
/// - Native displays texture
class DCFConfetti extends DCFStatelessComponent {
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
    // Static particle demo (needs worklet for animation)
    final random = Random();
    final particles = List<_ParticleState>.generate(config.particleCount, (i) {
      final angleRad = (config.angle - config.spread / 2 + 
                        random.nextDouble() * config.spread) * (pi / 180);
      final speed = config.startVelocity * (0.5 + random.nextDouble() * 0.5);
      
      return _ParticleState(
        x: 0.5,
        y: 0.5,
        vx: cos(angleRad) * speed,
        vy: -sin(angleRad) * speed,
        color: config.colors[random.nextInt(config.colors.length)],
        radius: (3 + random.nextDouble() * 4) * config.scalar,
        life: (config.duration / 16).toInt(),
      );
    });

    return DCFCanvas(
      key: 'confetti-canvas',
      size: const Size(300, 300),
      layout: layout,
      styleSheet: styleSheet,
      onPaint: (ui.Canvas canvas, Size size) {
        // Draw initial particle positions (static)
        for (final particle in particles) {
          final paint = ui.Paint()
            ..color = particle.color
            ..style = ui.PaintingStyle.fill;
          
          canvas.drawCircle(
            Offset(particle.x * size.width, particle.y * size.height),
            particle.radius,
            paint,
          );
        }
      },
    );
  }
}

