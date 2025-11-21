/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart';
import 'gpu_component.dart';

// Default layouts for confetti (registered for bridge efficiency)
// ignore: deprecated_member_use - Using DCFLayout() inside create() is the correct pattern
final _confettiLayouts = DCFLayout.create({
  'default': DCFLayout(
    position: DCFPositionType.absolute,
    absoluteLayout: AbsoluteLayout(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
    ),
  ),
});

/// Type-safe configuration for confetti particle effects
class ConfettiConfig {
  /// Gravity force applied to particles (default: 9.8 m/s²)
  final double gravity;
  
  /// Initial velocity of particles in pixels per second (default: 50.0)
  final double initialVelocity;
  
  /// Spread angle in degrees (0-360, default: 360.0 for full circle)
  final double spread;
  
  /// Colors for confetti particles
  final List<Color> colors;
  
  /// Minimum particle size in pixels (default: 4.0)
  final double minSize;
  
  /// Maximum particle size in pixels (default: 8.0)
  final double maxSize;
  
  const ConfettiConfig({
    this.gravity = 9.8,
    this.initialVelocity = 50.0,
    this.spread = 360.0,
    this.colors = const [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.cyan,
    ],
    this.minSize = 4.0,
    this.maxSize = 8.0,
  });
  
  /// Convert to map for GPU parameters
  Map<String, dynamic> toMap() => {
    'gravity': gravity,
    'initialVelocity': initialVelocity,
    'spread': spread,
    'colors': colors.map((c) {
      // Convert Color to hex string (RRGGBB format)
      final hex = c.value.toRadixString(16).padLeft(8, '0');
      return '#${hex.substring(2)}'; // Skip alpha channel
    }).toList(),
    'minSize': minSize,
    'maxSize': maxSize,
  };
}

/// Confetti animation using Skia GPU rendering
class DCFConfetti extends DCFStatelessComponent {
  final int particleCount;
  final int duration;
  final ConfettiConfig? config;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;
  final void Function()? onComplete;
  final void Function()? onStart;
  final Map<String, dynamic>? events;

  DCFConfetti({
    this.particleCount = 50,
    this.duration = 2000,
    this.config,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    this.onComplete,
    this.onStart,
    this.events,
    super.key,
  }) : layout = layout,
       styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    final confettiConfig = config ?? const ConfettiConfig();
    
    return DCFGPU(
      config: GPUConfig(
        renderMode: GPURenderMode.particles,
        particleCount: particleCount,
        shaderProgram: 'confetti',
        duration: duration,
        autoStart: true,
        parameters: confettiConfig.toMap(),
      ),
      layout: layout ?? _confettiLayouts['default'] as DCFLayout,
      styleSheet: styleSheet,
      onComplete: onComplete,
      onStart: onStart,
      events: events,
    ).render();
  }
}

