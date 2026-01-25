/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import '../../renderer/interface/native_platform.dart';

/// Configuration options for the layout system
class LayoutConfig {
  /// Whether to use web defaults for cross-platform compatibility
  /// 
  /// When enabled, the layout system uses CSS-compatible defaults:
  /// - flex-direction: row (instead of column)
  /// - align-content: stretch (instead of flex-start)
  /// - flex-shrink: 1 (instead of 0)
  /// 
  /// Note: position still defaults to relative for compatibility
  static bool useWebDefaults = false;
  
  /// Enable web defaults for cross-platform CSS compatibility
  static Future<void> enableWebDefaults() async {
    useWebDefaults = true;
    print("✅ LayoutConfig: Web defaults enabled");
  }
  
  /// Disable web defaults (use Yoga native defaults)
  static Future<void> disableWebDefaults() async {
    useWebDefaults = false;
    print("✅ LayoutConfig: Web defaults disabled");
  }
  
  /// Check if web defaults are currently enabled
  static bool isWebDefaultsEnabled() {
    return useWebDefaults;
  }
  
  // ============================================================================
  // LAYOUT ANIMATION CONFIGURATION
  // ============================================================================
  
  /// Whether layout animations are enabled globally
  /// 
  /// When enabled, views will smoothly animate when their position/size changes
  /// due to layout recalculation (Yoga). This is useful for:
  /// - List items animating when added/removed
  /// - Views repositioning smoothly when layout changes
  /// 
  /// Note: This is for **layout-driven** animations (Yoga recalculates → views animate).
  /// For **gesture-driven** animations (drawers, bottom sheets), use GestureDetector + SharedValue.
  static bool layoutAnimationEnabled = false;
  
  /// Duration for layout animations in milliseconds
  static int layoutAnimationDuration = 300;
  
  /// Enable layout animations globally
  /// 
  /// This enables smooth animations when views change position/size due to
  /// layout recalculation. Perfect for list animations and layout transitions.
  /// 
  /// Example:
  /// ```dart
  /// await LayoutConfig.enableLayoutAnimations(duration: 300);
  /// ```
  static Future<void> enableLayoutAnimations({int duration = 300}) async {
    layoutAnimationEnabled = true;
    layoutAnimationDuration = duration;
    print("✅ LayoutConfig: Layout animations enabled (duration: ${duration}ms)");
  }
  
  /// Disable layout animations globally
  static Future<void> disableLayoutAnimations() async {
    layoutAnimationEnabled = false;
    print("✅ LayoutConfig: Layout animations disabled");
  }
  
  /// Check if layout animations are currently enabled
  static bool isLayoutAnimationEnabled() {
    return layoutAnimationEnabled;
  }
}

/// Default layout configuration values
class LayoutDefaults {
  static const yogaFlexDirection = 'column';
  static const yogaAlignContent = 'flex-start';
  static const yogaFlexShrink = 0.0;
  static const yogaPosition = 'relative';
  
  static const webFlexDirection = 'row';
  static const webAlignContent = 'stretch';
  static const webFlexShrink = 1.0;
  static const webPosition = 'relative';
}
