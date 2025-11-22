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

// Animated styles and property management
export 'src/styles/animated_style.dart';

// Main animated view component
export 'src/components/reanimated_view.dart';

// Canvas component (unified - handles both 2D drawing and confetti)
export 'src/components/canvas_component.dart';
export 'src/components/confetti_component.dart';
export 'src/components/skia_shapes.dart';
export 'src/components/skia_group.dart';
export 'src/components/skia_shaders.dart';
export 'src/components/skia_filters.dart';
export 'src/components/skia_image.dart';
export 'src/components/skia_text.dart';
export 'src/components/skia_path_effects.dart';
export 'src/components/skia_mask.dart';
export 'src/components/skia_color_filters.dart';
export 'src/components/skia_backdrop_filters.dart';
export 'src/hooks/skia_hooks.dart';

// Animation hooks for StatefulComponent
export 'src/hooks/animation_hooks.dart';

// Pre-configured animation presets
export 'src/presets/animation_presets.dart';

// Component dictionary for DCFlight registration
export 'src/dictionary/components.dart';

// Plugin registration
export 'src/dcf_reanimated_plugin.dart';