/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

// Default layouts and styles for GPU component (registered for bridge efficiency)
// ignore: deprecated_member_use - Using DCFLayout()/DCFStyleSheet() inside create() is the correct pattern
final _gpuLayouts = DCFLayout.create({
  'default': DCFLayout(),
});

final _gpuStyles = DCFStyleSheet.create({
  'default': DCFStyleSheet(),
});

/// GPU rendering configuration for Skia-based GPU rendering
class GPUConfig {
  /// Rendering mode
  final GPURenderMode renderMode;
  
  /// Number of particles (for particle systems)
  final int? particleCount;
  
  /// Shader program identifier
  final String? shaderProgram;
  
  /// Custom GPU rendering parameters
  final Map<String, dynamic>? parameters;
  
  /// Duration in milliseconds (for animations)
  final int? duration;
  
  /// Whether to auto-start rendering
  final bool autoStart;
  
  const GPUConfig({
    required this.renderMode,
    this.particleCount,
    this.shaderProgram,
    this.parameters,
    this.duration,
    this.autoStart = true,
  });

  Map<String, dynamic> toMap() => {
        'renderMode': renderMode.name,
        if (particleCount != null) 'particleCount': particleCount,
        if (shaderProgram != null) 'shaderProgram': shaderProgram,
        if (parameters != null) 'parameters': parameters,
        if (duration != null) 'duration': duration,
        'autoStart': autoStart,
      };
}

/// GPU rendering modes
enum GPURenderMode {
  particles,
  canvas,
  custom,
}

/// GPU component for Skia-based GPU rendering
/// 
/// Uses Skia for consistent GPU-accelerated rendering on iOS and Android
class DCFGPU extends DCFStatelessComponent {
  final GPUConfig config;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;
  final void Function()? onComplete;
  final void Function()? onStart;
  final Map<String, dynamic>? events;

  DCFGPU({
    required this.config,
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
    Map<String, dynamic> eventHandlers = events ?? {};
    if (onStart != null) {
      eventHandlers['onGPUStart'] = onStart;
    }
    if (onComplete != null) {
      eventHandlers['onGPUComplete'] = onComplete;
    }

    Map<String, dynamic> props = {
      'gpuConfig': config.toMap(),
      ...(layout ?? _gpuLayouts['default'] as DCFLayout).toMap(),
      ...(styleSheet ?? _gpuStyles['default'] as DCFStyleSheet).toMap(),
      ...eventHandlers,
    };

    return DCFElement(
      type: 'GPU',
      elementProps: props,
      children: const [],
    );
  }
}

