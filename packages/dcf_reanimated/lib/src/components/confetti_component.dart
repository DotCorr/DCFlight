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

/// Confetti animation using Skia GPU rendering
class DCFConfetti extends DCFStatelessComponent {
  final int particleCount;
  final int duration;
  final DCFLayout layout;
  final void Function()? onComplete;
  final void Function()? onStart;
  final Map<String, dynamic>? events;

  const DCFConfetti({
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
            '#FF0000',
            '#00FF00',
            '#0000FF',
            '#FFFF00',
            '#FF00FF',
            '#00FFFF',
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

