/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import 'package:flutter/material.dart';

class DCFTheme {
  DCFTheme._();
  
  static DCFThemeData? _current;
  
  static DCFThemeData get current {
    return _current ?? DCFThemeData.light;
  }
  
  static void setTheme(DCFThemeData theme) {
    _current = theme;
  }
  
  static bool get isDarkMode => current.isDark;
  static Color get textColor => current.textColor;
  static Color get backgroundColor => current.backgroundColor;
  static Color get surfaceColor => current.surfaceColor;
  static Color get accentColor => current.accentColor;
}

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
  
  /// #000000, #FFFFFF, #F2F2F7, #007AFF, #8E8E93
  static const DCFThemeData light = DCFThemeData(
    isDark: false,
    textColor: Color(0xFF000000),
    backgroundColor: Color(0xFFFFFFFF),
    surfaceColor: Color(0xFFF2F2F7),
    accentColor: Color(0xFF007AFF),
    secondaryTextColor: Color(0xFF8E8E93),
  );
  
  /// #FFFFFF, #000000, #1C1C1E, #0A84FF, #8E8E93
  static const DCFThemeData dark = DCFThemeData(
    isDark: true,
    textColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF1C1C1E),
    accentColor: Color(0xFF0A84FF),
    secondaryTextColor: Color(0xFF8E8E93),
  );
  
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