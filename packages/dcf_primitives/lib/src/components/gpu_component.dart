/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// GPU rendering configuration for direct GPU-accelerated rendering.
///
/// This class defines how content should be rendered directly on the GPU,
/// bypassing the normal view hierarchy for maximum performance.
///
/// Example:
/// ```dart
/// GPUConfig(
///   renderMode: GPURenderMode.particles,
///   particleCount: 50,
///   shaderProgram: 'confetti',
/// )
/// ```
class GPUConfig {
  /// Rendering mode (particles, canvas, custom)
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

  /// Convert to map for native bridge communication
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
  /// Particle system rendering (confetti, explosions, etc.)
  particles,
  
  /// Canvas-based rendering (custom drawing)
  canvas,
  
  /// Custom shader-based rendering
  custom,
}

/// GPU component for direct GPU-accelerated rendering and animations.
///
/// [DCFGPU] renders content directly on the GPU, providing maximum performance
/// for complex animations like confetti, particle effects, and custom shaders.
///
/// Key features:
/// - Direct GPU rendering (Metal/Vulkan)
/// - Type-safe configuration
/// - Zero bridge calls during rendering
/// - Automatic cleanup on unmount
///
/// Example:
/// ```dart
/// DCFGPU(
///   config: GPUConfig(
///     renderMode: GPURenderMode.particles,
///     particleCount: 50,
///     shaderProgram: 'confetti',
///     duration: 2000,
///   ),
///   onComplete: () => print("Animation done!"),
///   layout: DCFLayout(
///     position: DCFPosition.absolute,
///     top: 0,
///     left: 0,
///     right: 0,
///     bottom: 0,
///   ),
/// )
/// ```
class DCFGPU extends DCFStatelessComponent {
  /// GPU rendering configuration
  final GPUConfig config;
  
  /// Layout properties for positioning and sizing
  final DCFLayout layout;
  
  /// Static styling properties
  final DCFStyleSheet styleSheet;
  
  /// Called when GPU rendering completes
  final void Function()? onComplete;
  
  /// Called when GPU rendering starts
  final void Function()? onStart;
  
  /// Additional event handlers
  final Map<String, dynamic>? events;

  /// Creates a new GPU component.
  ///
  /// The [config] parameter is required and defines how the GPU rendering
  /// should work. All other parameters have sensible defaults.
  DCFGPU({
    required this.config,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.onComplete,
    this.onStart,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Prepare event handlers map
    Map<String, dynamic> eventHandlers = events ?? {};

    // Add lifecycle callbacks
    if (onStart != null) {
      eventHandlers['onGPUStart'] = onStart;
    }
    if (onComplete != null) {
      eventHandlers['onGPUComplete'] = onComplete;
    }

    // Build props map for native bridge communication
    Map<String, dynamic> props = {
      // GPU configuration
      'gpuConfig': config.toMap(),

      // Layout and styling
      ...layout.toMap(),
      ...styleSheet.toMap(),

      // Event handlers
      ...eventHandlers,
    };

    // Create DCF element that will be rendered by native GPU component
    return DCFElement(
      type: 'GPU', // Must match native component registration
      elementProps: props,
      children: const [], // GPU components don't have children
    );
  }
}

