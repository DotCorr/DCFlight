/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'canvas_component.dart';

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

/// Particle data for confetti animation
class _ConfettiParticle {
  double x;
  double y;
  double vx; // velocity x
  double vy; // velocity y
  double rotation;
  double rotationSpeed;
  final double size;
  final int color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });
}

/// Confetti animation using Skia Canvas API with physics simulation
///
/// Built on top of DCFCanvas using the canvas drawing API.
/// Particles fall with gravity and spread out in all directions.
class DCFConfetti extends DCFStatefulComponent {
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
  })  : layout = layout,
        styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    // Initialize particles on first render
    final cfg = config ?? const ConfettiConfig();
    final colors = cfg.colors;
    final random = math.Random();
    final particleList = <_ConfettiParticle>[];

    // Start from center of screen
    const centerX = 540.0; // Half of 1080 (typical width)
    const centerY = 400.0; // Start from top-ish

    for (int i = 0; i < particleCount; i++) {
      // Random angle for spread
      final angle = random.nextDouble() * cfg.spread * (math.pi / 180);
      final speed =
          cfg.initialVelocity + random.nextDouble() * cfg.initialVelocity;

      particleList.add(_ConfettiParticle(
        x: centerX,
        y: centerY,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 100, // Initial upward velocity
        rotation: random.nextDouble() * 360,
        rotationSpeed:
            (random.nextDouble() - 0.5) * 10, // Random rotation speed
        size: cfg.minSize + random.nextDouble() * (cfg.maxSize - cfg.minSize),
        color: colors[random.nextInt(colors.length)].value,
      ));
    }

    final particles = useState<List<_ConfettiParticle>>(particleList);
    final startTime = useState<int>(DateTime.now().millisecondsSinceEpoch);
    final isComplete = useState<bool>(false);

    // Update particle positions on each frame
    useEffect(() {
      if (isComplete.state) return null;

      final timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime.state;

        if (elapsed >= duration) {
          timer.cancel();
          isComplete.setState(true);
          onComplete?.call();
          return;
        }

        // Update each particle
        final updatedParticles = particles.state.map((p) {
          // Apply gravity
          p.vy += cfg.gravity;

          // Update position
          p.x += p.vx * 0.016; // 16ms frame time
          p.y += p.vy * 0.016;

          // Update rotation
          p.rotation += p.rotationSpeed;

          return p;
        }).toList();

        particles.setState(updatedParticles);
      });

      // Cleanup
      return () => timer.cancel();
    }, dependencies: []);

    // Use DCFCanvas with onPaint callback
    return DCFCanvas(
      repaintOnFrame: true,
      layout: layout ?? _confettiLayouts['default'],
      styleSheet: styleSheet,
      onPaint: (canvas, size) {
        final paint = Paint()..style = PaintingStyle.fill;

        for (final p in particles.state) {
          paint.color = Color(p.color);
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rotation * math.pi / 180);
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          canvas.restore();
        }
      },
    );
  }
}
