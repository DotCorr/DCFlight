/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart' hide DCFCanvas;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'canvas_component.dart';

// Default layouts for confetti (registered for bridge efficiency)
// ignore: deprecated_member_use - Using DCFLayout() inside create() is the correct pattern
final _confettiLayouts = DCFLayout.create({
  'default': DCFLayout(
    // No flex needed with absolute positioning - top/left/right/bottom handle sizing
    position: DCFPositionType.absolute,
    absoluteLayout: AbsoluteLayout(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
    ),
  ),
  'canvasFill': DCFLayout(
    flex: 1,
    width: '100%',
    height: '100%',
    // No absolute positioning - just fill parent
  ),
});

/// Type-safe configuration for confetti particle effects
/// Based on flutter_confetti's ConfettiOptions but adapted for DCFlight
class ConfettiConfig {
  /// The number of confetti to launch
  final int particleCount;

  /// The angle in which to launch the confetti, in degrees. 90 is straight up.
  final double angle;

  /// How far off center the confetti can go, in degrees.
  /// 45 means the confetti will launch at the defined angle plus or minus 22.5 degrees.
  final double spread;

  /// How fast the confetti will start going, in pixels.
  final double startVelocity;

  /// How quickly the confetti will lose speed.
  /// Keep this number between 0 and 1, otherwise the confetti will gain speed.
  final double decay;

  /// How quickly the particles are pulled down.
  /// 1 is full gravity, 0.5 is half gravity, etc.
  final double gravity;

  /// How much to the side the confetti will drift.
  /// The default is 0, meaning that they will fall straight down.
  /// Use a negative number for left and positive number for right.
  final double drift;

  /// Optionally turns off the tilt and wobble that three dimensional confetti
  /// would have in the real world.
  final bool flat;

  /// How many times the confetti will move (ticks).
  final int ticks;

  /// The x position on the page, with 0 being the left edge and 1 being the right edge.
  final double x;

  /// The y position on the page, with 0 being the top edge and 1 being the bottom edge.
  final double y;

  /// An array of colors.
  final List<Color> colors;

  /// Scale factor for each confetti particle.
  /// Use decimals to make the confetti smaller.
  final double scalar;

  const ConfettiConfig({
    this.particleCount = 50,
    this.angle = 90,
    this.spread = 45,
    this.startVelocity = 45,
    this.decay = 0.9,
    this.gravity = 1,
    this.drift = 0,
    this.flat = false,
    this.scalar = 1,
    this.x = 0.5,
    this.y = 0.5,
    this.ticks = 200,
    this.colors = const [
      Color(0xFF26ccff),
      Color(0xFFa25afd),
      Color(0xFFff5e7e),
      Color(0xFFfcff42),
      Color(0xFFffa62d),
      Color(0xFFff36ff),
    ],
  }) : assert(decay >= 0 && decay <= 1),
       assert(ticks > 0);

  ConfettiConfig copyWith({
    int? particleCount,
    double? angle,
    double? spread,
    double? startVelocity,
    double? decay,
    double? gravity,
    double? drift,
    bool? flat,
    double? scalar,
    double? x,
    double? y,
    int? ticks,
    List<Color>? colors,
  }) {
    return ConfettiConfig(
      particleCount: particleCount ?? this.particleCount,
      angle: angle ?? this.angle,
      spread: spread ?? this.spread,
      startVelocity: startVelocity ?? this.startVelocity,
      decay: decay ?? this.decay,
      gravity: gravity ?? this.gravity,
      drift: drift ?? this.drift,
      flat: flat ?? this.flat,
      scalar: scalar ?? this.scalar,
      x: x ?? this.x,
      y: y ?? this.y,
      ticks: ticks ?? this.ticks,
      colors: colors ?? this.colors,
    );
  }
}

/// Physics engine for confetti particles
/// Based on flutter_confetti's ConfettiPhysics
class _ConfettiPhysics {
  double wobble;
  double wobbleSpeed;
  double velocity;
  double angle2D;
  double tiltAngle;
  Color color;
  double decay;
  double drift;
  double gravity;
  double scalar;
  double ovalScalar;
  double wobbleX;
  double wobbleY;
  double tiltSin;
  double tiltCos;
  double random;
  bool flat;
  int totalTicks;
  int ticket = 0;
  double progress = 0;

  bool get finished => ticket > totalTicks;

  double x = 0;
  double y = 0;
  double x1 = 0;
  double x2 = 0;
  double y1 = 0;
  double y2 = 0;

  _ConfettiPhysics({
    required this.wobble,
    required this.wobbleSpeed,
    required this.velocity,
    required this.angle2D,
    required this.tiltAngle,
    required this.color,
    required this.decay,
    required this.drift,
    required this.random,
    required this.tiltSin,
    required this.wobbleX,
    required this.wobbleY,
    required this.gravity,
    required this.ovalScalar,
    required this.scalar,
    required this.flat,
    required this.tiltCos,
    required this.totalTicks,
  });

  factory _ConfettiPhysics.fromOptions({
    required ConfettiConfig options,
    required Color color,
    required double startX,
    required double startY,
  }) {
    final random = math.Random();
    final radAngle = options.angle * (math.pi / 180);
    final radSpread = options.spread * (math.pi / 180);

    return _ConfettiPhysics(
      wobble: random.nextDouble() * 10,
      wobbleSpeed: math.min(0.11, random.nextDouble() * 0.1 + 0.05),
      velocity: options.startVelocity * 0.5 + random.nextDouble() * options.startVelocity,
      angle2D: -radAngle + (0.5 * radSpread - random.nextDouble() * radSpread),
      tiltAngle: (random.nextDouble() * (0.75 - 0.25) + 0.25) * math.pi,
      color: color,
      decay: options.decay,
      drift: options.drift,
      random: random.nextDouble() + 2,
      tiltSin: 0,
      tiltCos: 0,
      wobbleX: 0,
      wobbleY: 0,
      gravity: options.gravity * 3,
      ovalScalar: 0.6,
      scalar: options.scalar,
      flat: options.flat,
      totalTicks: options.ticks,
    )..x = startX..y = startY;
  }

  void update() {
    progress = ticket / totalTicks;
    ticket++;

    x += math.cos(angle2D) * velocity + drift;
    y += math.sin(angle2D) * velocity + gravity;
    velocity *= decay;

    if (flat) {
      wobble = 0;
      wobbleX = x + (10 * scalar);
      wobbleY = y + (10 * scalar);
      tiltSin = 0;
      tiltCos = 0;
      random = 1;
    } else {
      wobble += wobbleSpeed;
      wobbleX = x + 10 * scalar * math.cos(wobble);
      wobbleY = y + 10 * scalar * math.sin(wobble);
      tiltAngle += 0.1;
      tiltSin = math.sin(tiltAngle);
      tiltCos = math.cos(tiltAngle);
      random = math.Random().nextDouble() + 2;
    }

    x1 = x + random * tiltCos;
    y1 = y + random * tiltSin;
    x2 = wobbleX + random * tiltCos;
    y2 = wobbleY + random * tiltSin;
  }

  void kill() {
    ticket = totalTicks + 1;
  }
}

/// Abstract base class for confetti particles
/// Based on flutter_confetti's ConfettiParticle
abstract class _ConfettiParticle {
  void paint({
    required _ConfettiPhysics physics,
    required ui.Canvas canvas,
  });
}

/// Circle particle shape
class _CircleParticle extends _ConfettiParticle {
  @override
  void paint({
    required _ConfettiPhysics physics,
    required ui.Canvas canvas,
  }) {
    canvas.save();
    canvas.translate(physics.x, physics.y);
    canvas.rotate(math.pi / 10 * physics.wobble);
    canvas.scale(
      (physics.x2 - physics.x1).abs() * physics.ovalScalar,
      (physics.y2 - physics.y1).abs() * physics.ovalScalar,
    );

    final paint = Paint()
      ..color = physics.color.withOpacity(1 - physics.progress);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, 0), radius: 1),
      0,
      2 * math.pi,
      true,
      paint,
    );
    canvas.restore();
  }
}

/// Square particle shape
class _SquareParticle extends _ConfettiParticle {
  @override
  void paint({
    required _ConfettiPhysics physics,
    required ui.Canvas canvas,
  }) {
    canvas.save();
    final path = Path()
      ..moveTo(physics.x.floor().toDouble(), physics.y.floor().toDouble());
    path.lineTo(physics.wobbleX, physics.y1.floor().toDouble());
    path.lineTo(physics.x2.floor().toDouble(), physics.y2.floor().toDouble());
    path.lineTo(physics.x1.floor().toDouble(), physics.wobbleY.floor().toDouble());
    path.close();

    final paint = Paint()
      ..color = physics.color.withOpacity(1 - physics.progress);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}

/// Triangle particle shape
class _TriangleParticle extends _ConfettiParticle {
  @override
  void paint({
    required _ConfettiPhysics physics,
    required ui.Canvas canvas,
  }) {
    canvas.save();
    final path = Path()
      ..moveTo(physics.x.floor().toDouble(), physics.y.floor().toDouble())
      ..lineTo(physics.wobbleX.ceil().toDouble(), physics.y1.floor().toDouble())
      ..lineTo(physics.x2.floor().toDouble(), physics.wobbleY.ceil().toDouble())
      ..close();

    final paint = Paint()
      ..color = physics.color.withOpacity(1 - physics.progress);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}

/// Star particle shape
class _StarParticle extends _ConfettiParticle {
  @override
  void paint({
    required _ConfettiPhysics physics,
    required ui.Canvas canvas,
  }) {
    canvas.save();
    final innerRadius = 4 * physics.scalar;
    final outerRadius = 8 * physics.scalar;
    double rot = math.pi / 2 * 3;
    double x = physics.x;
    double y = physics.y;
    int spikes = 5;
    final step = math.pi / spikes;

    final path = Path()..moveTo(x, y);
    while (spikes-- >= 0) {
      x = physics.x + math.cos(rot) * outerRadius;
      y = physics.y + math.sin(rot) * outerRadius;
      path.lineTo(x, y);
      rot += step;
      x = physics.x + math.cos(rot) * innerRadius;
      y = physics.y + math.sin(rot) * innerRadius;
      path.lineTo(x, y);
      rot += step;
    }
    path.close();

    final paint = Paint()
      ..color = physics.color.withOpacity(1 - physics.progress);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}

/// Glue class that binds a particle to its physics
class _ParticleGlue {
  final _ConfettiParticle particle;
  final _ConfettiPhysics physics;

  _ParticleGlue({
    required this.particle,
    required this.physics,
  });
}

/// Confetti animation using Dart-side particle logic with Flutter texture API
///
/// Particles are calculated and rendered in Dart using `dart:ui` Canvas API,
/// then sent to native via Flutter's texture registry for efficient GPU rendering.
/// Based on flutter_confetti's physics system but adapted for DCFlight.
class DCFConfetti extends DCFStatefulComponent {
  final ConfettiConfig? config;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;
  final void Function()? onComplete;
  final void Function()? onStart;
  final Map<String, dynamic>? events;
  
  /// Builder function to create custom particle shapes
  /// If not provided, defaults to Circle and Square
  final _ConfettiParticle Function(int index)? particleBuilder;

  DCFConfetti({
    this.config,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    this.onComplete,
    this.onStart,
    this.events,
    this.particleBuilder,
    super.key,
  })  : layout = layout,
        styleSheet = styleSheet;

  @override
  DCFComponentNode render() {
    final cfg = config ?? const ConfettiConfig();
    final colors = cfg.colors;
    final colorsCount = colors.length;
    final particlesInitialized = useRef<bool>(false);
    
    // Get screen dimensions for proper positioning
    final screenWidth = ScreenUtilities.instance.screenWidth;
    final screenHeight = ScreenUtilities.instance.screenHeight;
    final containerWidth = screenWidth > 0 ? screenWidth : 400.0;
    final containerHeight = screenHeight > 0 ? screenHeight : 800.0;
    
    final startX = cfg.x * containerWidth;
    final startY = cfg.y * containerHeight;

    // Use refs for everything - no state updates = no VDOM reconciliation
    final particlesRef = useRef<List<_ParticleGlue>>([]);
    final isCompleteRef = useRef<bool>(false);
    
    // Initialize particles only once
    if (particlesInitialized.current != true) {
      final random = math.Random();
      final particleList = <_ParticleGlue>[];

      // Default particle builder (Circle and Square)
      final defaultParticleBuilder = particleBuilder ?? (int index) {
        return [_CircleParticle(), _SquareParticle(), _TriangleParticle(), _StarParticle()][random.nextInt(4)];
      };

      for (int i = 0; i < cfg.particleCount; i++) {
        final color = colors[i % colorsCount];
        final physics = _ConfettiPhysics.fromOptions(
          options: cfg,
          color: color,
          startX: startX,
          startY: startY,
        );
        final particle = defaultParticleBuilder(i);
        particleList.add(_ParticleGlue(particle: particle, physics: physics));
      }
      
      particlesRef.current = particleList;
      particlesInitialized.current = true;
      onStart?.call();
      print('🎉 DCFConfetti: Initialized ${particleList.length} particles at ($startX, $startY)');
    }

    // Update particles directly in ref - no state = no VDOM reconciliation
    // Canvas rendering happens via tunnel (also bypasses VDOM)
    useEffect(() {
      if (isCompleteRef.current == true) return null;

      final timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        final currentParticles = particlesRef.current;
        if (currentParticles == null || currentParticles.isEmpty) return;

        // Update all particles
        bool allFinished = true;
        for (final glue in currentParticles) {
          if (!glue.physics.finished) {
            glue.physics.update();
            allFinished = false;
          }
        }

        if (allFinished) {
          timer.cancel();
          isCompleteRef.current = true;
          onComplete?.call();
        }
      });

      return () => timer.cancel();
    }, dependencies: []);
    
    // Wrap canvas in a DCFView - use provided layout and styleSheet directly
    // The canvas itself is transparent so the background shows through
    return DCFView(
      layout: layout ?? DCFLayout(
        position: DCFPositionType.absolute,
        width: containerWidth,
        height: containerHeight,
        absoluteLayout: AbsoluteLayout(
          top: 0,
          left: 0,
        ),
      ),
      styleSheet: styleSheet ?? const DCFStyleSheet(backgroundColor: DCFColors.transparent),
      children: [
        DCFCanvas(
          key: 'confetti-canvas',
          size: Size(containerWidth, containerHeight),
          repaintOnFrame: true,
          backgroundColor: Colors.transparent,
          layout: _confettiLayouts['canvasFill'], // Canvas fills the container (no absolute positioning)
          onPaint: (canvas, size) {
            // This onPaint callback renders to dart:ui Canvas
            // Then _renderToNative converts to pixels and sends via tunnel
            // Tunnel updates bypass VDOM completely - direct to native texture
            // Always read from ref to get latest particles (ref is stable, value changes)
            final currentParticles = particlesRef.current;
            if (currentParticles == null || currentParticles.isEmpty) {
              return; // No particles to render yet
            }

            // Count active particles
            int activeCount = 0;
            for (final glue in currentParticles) {
              if (!glue.physics.finished) {
                activeCount++;
              }
            }

            if (activeCount == 0) {
              return; // All particles finished
            }

            // Draw all particles
            for (final glue in currentParticles) {
              final physics = glue.physics;
              if (!physics.finished) {
                glue.particle.paint(physics: physics, canvas: canvas);
              }
            }
          },
        ),
      ],
    );
  }
}
