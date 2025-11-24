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

/// Particle data structure for confetti
class _ConfettiParticle {
  final double initialX;
  final double initialY;
  final double vx;
  final double vy;
  final int color;
  final double radius;
  final int life; // total frames

  _ConfettiParticle({
    required this.initialX,
    required this.initialY,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    required this.life,
  });

  Map<String, dynamic> toMap() {
    return {
      'initialX': initialX,
      'initialY': initialY,
      'vx': vx,
      'vy': vy,
      'color': color,
      'radius': radius,
      'life': life,
    };
  }
}

/// Confetti component using declarative Canvas API
/// 
/// Describes particle configurations in Dart, native renders at 60fps.
/// Uses AnimatedValue for time-based animations on UI thread.
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
    // Generate particle configurations (static descriptions)
    final random = Random();
    final particles = List.generate(config.particleCount, (i) {
      final angleRad = (config.angle - config.spread / 2 + random.nextDouble() * config.spread) * (pi / 180);
      final speed = config.startVelocity * (0.5 + random.nextDouble() * 0.5);

      return _ConfettiParticle(
        initialX: 0.5, // Normalized center (0-1)
        initialY: 0.5,
        vx: cos(angleRad) * speed + (random.nextDouble() - 0.5) * config.drift,
        vy: -sin(angleRad) * speed,
        color: config.colors[random.nextInt(config.colors.length)].value,
        radius: (3 + random.nextDouble() * 4) * config.scalar,
        life: (config.duration / 16).toInt(), // Convert ms to frames
      );
    });

    // Build props with particle descriptions and physics config
    final props = <String, dynamic>{
      'animationType': 'confetti',
      'autoStart': true,
      'particles': particles.map((p) => p.toMap()).toList(),
      'physics': {
        'gravity': config.gravity,
        'decay': config.decay,
      },
      'duration': config.duration,
      ...?layout?.toMap(),
      ...?styleSheet?.toMap(),
    };

    // Add event handler if provided
    if (onComplete != null) {
      props['onAnimationComplete'] = (dynamic data) => onComplete?.call();
    }

    // Send to Canvas component - native will render particles at 60fps
    // using the descriptions with physics simulation
    return DCFElement(
      type: 'Canvas',
      elementProps: props,
      children: const [],
    );
  }
}

