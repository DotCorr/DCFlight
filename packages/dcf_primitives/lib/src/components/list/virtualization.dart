/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library dcflight_virtualization;

/// 🚀 DCFlight Virtualization System - Exports
/// 
/// The fastest list virtualization system for cross-platform apps
/// Beats React Native FlatList and FlashList performance

// Virtualization engine and core types
export 'virtualization/virtualization_engine.dart'; 

// Performance monitoring
export 'virtualization/performance_monitor.dart';

// Core components (for advanced usage)
export 'virtualization/viewport_calculator.dart';
export 'virtualization/component_recycler.dart';
export 'virtualization/types.dart' show VirtualizationConfig;
export 'virtualization/layout_estimator.dart';
export 'virtualization/render_scheduler.dart' hide RenderTask;
