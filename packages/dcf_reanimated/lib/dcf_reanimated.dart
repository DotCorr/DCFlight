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

// Mutable animated values for React Native Skia-style animations (AnimatedValue)
export 'src/values/shared_value.dart';

// Animated styles and property management
export 'src/styles/animated_style.dart';

// Main animated view component
export 'src/components/reanimated_view.dart';

// Framer Motion-style declarative animation component
export 'src/components/motion.dart';

export 'src/hooks/skia_hooks.dart';

// Animation hooks for StatefulComponent
export 'src/hooks/animation_hooks.dart';

// Pre-configured animation presets
export 'src/presets/animation_presets.dart';

// Stagger utilities for sequential animations
export 'src/utils/stagger.dart';

// Component dictionary for DCFlight registration
export 'src/dictionary/components.dart';

// Plugin registration
export 'src/dcf_reanimated_plugin.dart';

