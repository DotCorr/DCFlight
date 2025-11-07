/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/material.dart';

/// Cross-platform theme system for DCFlight
/// Provides unified API for theme access (like React Native)
class DCFTheme {
  DCFTheme._();

  /// Get the current theme instance
  /// This will be set by the framework based on platform theme
  static DCFThemeData? _current;

  /// Get current theme data
  static DCFThemeData get current {
    return _current ?? DCFThemeData.light;
  }

  /// Set the current theme (called by framework)
  static void setTheme(DCFThemeData theme) {
    _current = theme;
  }

  /// Check if current theme is dark mode
  static bool get isDarkMode => current.isDark;

  /// Get text color for current theme
  static Color get textColor => current.textColor;

  /// Get background color for current theme
  static Color get backgroundColor => current.backgroundColor;

  /// Get surface color for current theme
  static Color get surfaceColor => current.surfaceColor;

  /// Get accent color for current theme
  static Color get accentColor => current.accentColor;
}

/// Theme data class - cross-platform theme values
class DCFThemeData {
  final bool isDark;
  final Color textColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color secondaryTextColor;

  const DCFThemeData({
    required this.isDark,
    required this.textColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.secondaryTextColor,
  });

  /// Light theme (default)
  static const DCFThemeData light = DCFThemeData(
    isDark: false,
    textColor: Color(0xFF000000), // Black
    backgroundColor: Color(0xFFFFFFFF), // White
    surfaceColor: Color(0xFFFFFFFF), // White
    accentColor: Color(0xFF2196F3), // Material Blue
    secondaryTextColor: Color(0x8A000000), // 54% opacity black
  );

  /// Dark theme
  static const DCFThemeData dark = DCFThemeData(
    isDark: true,
    textColor: Color(0xFFFFFFFF), // White
    backgroundColor: Color(0xFF000000), // Black
    surfaceColor: Color(0xFF121212), // Material dark surface
    accentColor: Color(0xFF2196F3), // Material Blue
    secondaryTextColor: Color(0xB3FFFFFF), // 70% opacity white
  );

  /// Create theme from platform values
  factory DCFThemeData.fromPlatform({
    required bool isDark,
    required Color textColor,
    required Color backgroundColor,
    Color? surfaceColor,
    Color? accentColor,
    Color? secondaryTextColor,
  }) {
    return DCFThemeData(
      isDark: isDark,
      textColor: textColor,
      backgroundColor: backgroundColor,
      surfaceColor: surfaceColor ?? (isDark ? dark.surfaceColor : light.surfaceColor),
      accentColor: accentColor ?? light.accentColor,
      secondaryTextColor: secondaryTextColor ??
          (isDark ? dark.secondaryTextColor : light.secondaryTextColor),
    );
  }
}

