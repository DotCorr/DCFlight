/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

// Type-safe enums for animation configuration
export 'src/enums/animation_enums.dart';

// Core animation values and configuration
export 'src/values/animation_values.dart';

// Canvas repaint notifier for efficient animations
export 'src/values/canvas_notifier.dart';

// Mutable animated values for React Native Skia-style animations (AnimatedValue)
export 'src/values/shared_value.dart';

// Animated styles and property management
export 'src/styles/animated_style.dart';

// Main animated view component
export 'src/components/reanimated_view.dart';

// Canvas and Confetti components
export 'src/components/canvas_component.dart';
export 'src/components/confetti_component.dart';

export 'src/hooks/skia_hooks.dart';

// Animation hooks for StatefulComponent
export 'src/hooks/animation_hooks.dart';

// Pre-configured animation presets
export 'src/presets/animation_presets.dart';

// Component dictionary for DCFlight registration
export 'src/dictionary/components.dart';

// Plugin registration
export 'src/dcf_reanimated_plugin.dart';

