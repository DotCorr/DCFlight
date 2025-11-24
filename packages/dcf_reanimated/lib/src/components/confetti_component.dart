/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

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

/// Confetti component using Canvas with Native Animation
///
/// Architecture:
/// - Dart sends configuration to Native
/// - Native runs physics loop on UI thread (60fps)
/// - Zero bridge traffic during animation
class DCFConfetti extends DCFCanvasWithAnimation {
  final ConfettiConfig config;
  final VoidCallback? onComplete;

  DCFConfetti({
    required this.config,
    this.onComplete,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    super.key,
  }) : super(
          layout: layout,
          styleSheet: styleSheet,
          size: const Size(300, 300), // Default size, overridden by layout
        );

  @override
  Map<String, dynamic>? get animationConfig => {
        'type': 'confetti',
        'particleCount': config.particleCount,
        'startVelocity': config.startVelocity,
        'spread': config.spread,
        'angle': config.angle,
        'gravity': config.gravity,
        'drift': config.drift,
        'decay': config.decay,
        'duration': config.duration,
        'colors': config.colors.map((c) => c.value).toList(),
        'scalar': config.scalar,
      };

  @override
  DCFComponentNode render() {
    // Just call super.render() which handles registration and animation start
    return super.render();
  }
}
