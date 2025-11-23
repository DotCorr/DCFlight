/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/utils/screen_utilities.dart';
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

/// Confetti animation using Dart-side particle logic with Flutter texture API
///
/// Particles are calculated and rendered in Dart using `dart:ui` Canvas API,
/// then sent to native via Flutter's texture registry for efficient GPU rendering.
/// Users can customize particle behavior in Dart without writing native glue code.
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
    final cfg = config ?? const ConfettiConfig();
    final colors = cfg.colors;
    final particlesInitialized = useRef<bool>(false);
    
    // Get screen dimensions for proper centering
    final screenWidth = ScreenUtilities.instance.screenWidth;
    final screenHeight = ScreenUtilities.instance.screenHeight;
    final centerX = screenWidth > 0 ? screenWidth / 2 : 200.0;
    final centerY = screenHeight > 0 ? screenHeight * 0.2 : 200.0;

    // Use refs for everything - no state updates = no VDOM reconciliation
    final particlesRef = useRef<List<_ConfettiParticle>>([]);
    final isCompleteRef = useRef<bool>(false);
    
    // Initialize particles only once
    if (particlesInitialized.current != true) {
      final random = math.Random();
      final particleList = <_ConfettiParticle>[];

      for (int i = 0; i < particleCount; i++) {
        final angle = random.nextDouble() * cfg.spread * (math.pi / 180);
        final speed = cfg.initialVelocity + random.nextDouble() * cfg.initialVelocity;

        particleList.add(_ConfettiParticle(
          x: centerX,
          y: centerY,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 100, // Initial upward velocity
          rotation: random.nextDouble() * 360,
          rotationSpeed: (random.nextDouble() - 0.5) * 10,
          size: cfg.minSize + random.nextDouble() * (cfg.maxSize - cfg.minSize),
          color: colors[random.nextInt(colors.length)].value,
        ));
      }
      
      particlesRef.current = particleList;
      particlesInitialized.current = true;
      print('🎉 DCFConfetti: Initialized ${particleList.length} particles at ($centerX, $centerY)');
    }

    // Initialize startTime only once
    final startTimeRef = useRef<int?>(null);
    if (startTimeRef.current == null) {
      startTimeRef.current = DateTime.now().millisecondsSinceEpoch;
    }
    final startTime = startTimeRef.current!;

    // Update particles directly in ref - no state = no VDOM reconciliation
    // Canvas rendering happens via tunnel (also bypasses VDOM)
    useEffect(() {
      if (isCompleteRef.current == true) return null;

      final timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;

        if (elapsed >= duration) {
          timer.cancel();
          isCompleteRef.current = true;
          onComplete?.call();
          return;
        }

        // Update particles directly in ref - no setState = no VDOM reconciliation
        final currentParticles = particlesRef.current ?? <_ConfettiParticle>[];
        final updatedParticles = currentParticles.map((p) {
          return _ConfettiParticle(
            x: p.x + p.vx * 0.016, // 16ms frame time
            y: p.y + (p.vy + cfg.gravity) * 0.016,
            vx: p.vx,
            vy: p.vy + cfg.gravity,
            rotation: p.rotation + p.rotationSpeed,
            rotationSpeed: p.rotationSpeed,
            size: p.size,
            color: p.color,
          );
        }).toList();

        particlesRef.current = updatedParticles;
        // No setState - particles update directly, rendering happens via tunnel
      });

      return () => timer.cancel();
    }, dependencies: []);

    // Use actual screen size for canvas
    final canvasWidth = screenWidth > 0 ? screenWidth : 400.0;
    final canvasHeight = screenHeight > 0 ? screenHeight : 800.0;
    
    // Use DCFCanvas for layout/positioning (goes through VDOM)
    // But all pixel updates go directly via tunnel (bypasses VDOM)
    return DCFCanvas(
      key: 'confetti-canvas',
      size: Size(canvasWidth, canvasHeight),
      repaintOnFrame: true,
      backgroundColor: Colors.transparent,
      layout: layout ?? _confettiLayouts['default'],
      styleSheet: styleSheet,
      onPaint: (canvas, size) {
        // This onPaint callback renders to dart:ui Canvas
        // Then _renderToNative converts to pixels and sends via tunnel
        // Tunnel updates bypass VDOM completely - direct to native texture
        final paint = Paint()..style = PaintingStyle.fill;
        final currentParticles = particlesRef.current ?? <_ConfettiParticle>[];

        for (final p in currentParticles) {
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
