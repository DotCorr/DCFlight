/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/constants/layout/yoga_enums.dart';
import 'package:dcflight/framework/constants/layout/absolute_layout.dart';
import 'gpu_component.dart';

/// Confetti animation component using GPU rendering.
///
/// [DCFConfetti] renders a confetti animation directly on the GPU,
/// providing smooth 60fps performance with zero bridge calls during animation.
///
/// The component automatically unmounts when the animation completes.
///
/// Example:
/// ```dart
/// final showConfetti = useState(false);
///
/// DCFButton(
///   onPress: (_) => showConfetti.setState(true),
///   children: [DCFText(content: "Celebrate!")],
/// ),
///
/// if (showConfetti.state)
///   DCFConfetti(
///     particleCount: 50,
///     duration: 2000,
///     onComplete: () => showConfetti.setState(false),
///   ),
/// ```
class DCFConfetti extends DCFStatelessComponent {
  /// Number of confetti particles
  final int particleCount;
  
  /// Animation duration in milliseconds
  final int duration;
  
  /// Layout properties (typically absolute positioning)
  final DCFLayout layout;
  
  /// Called when confetti animation completes
  final void Function()? onComplete;
  
  /// Called when confetti animation starts
  final void Function()? onStart;
  
  /// Additional event handlers
  final Map<String, dynamic>? events;

  /// Creates a new confetti animation component.
  ///
  /// Defaults to 50 particles with a 2-second duration.
  /// The component will automatically unmount when animation completes.
  DCFConfetti({
    this.particleCount = 50,
    this.duration = 2000,
    this.layout = const DCFLayout(
      position: DCFPositionType.absolute,
      absoluteLayout: AbsoluteLayout(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
      ),
    ),
    this.onComplete,
    this.onStart,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFGPU(
      config: GPUConfig(
        renderMode: GPURenderMode.particles,
        particleCount: particleCount,
        shaderProgram: 'confetti',
        duration: duration,
        autoStart: true,
        parameters: {
          'gravity': 9.8,
          'initialVelocity': 50.0,
          'spread': 360.0,
          'colors': [
            '#FF0000', // Red
            '#00FF00', // Green
            '#0000FF', // Blue
            '#FFFF00', // Yellow
            '#FF00FF', // Magenta
            '#00FFFF', // Cyan
          ],
        },
      ),
      layout: layout,
      onComplete: onComplete,
      onStart: onStart,
      events: events,
    ).render();
  }
}

