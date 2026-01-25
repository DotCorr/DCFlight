/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


enum Platform {
  ios('iOS'),
  android('Android'),
  web('Web'),
  macos('macOS'),
  windows('Windows'),
  linux('Linux');

  const Platform(this.displayName);
  
  final String displayName;

  /// Get platform from string input
  static Platform? fromString(String input) {
    switch (input.toLowerCase()) {
      case 'ios':
        return Platform.ios;
      case 'android':
        return Platform.android;
      case 'web':
        return Platform.web;
      case 'macos':
        return Platform.macos;
      case 'windows':
        return Platform.windows;
      case 'linux':
        return Platform.linux;
      default:
        return null;
    }
  }

  /// Get all available platforms as a list
  static List<Platform> get all => Platform.values;

  /// Get default platforms (iOS and Android)
  static List<Platform> get defaults => [Platform.ios, Platform.android];

  /// Check if platform is mobile
  bool get isMobile => this == Platform.ios || this == Platform.android;

  /// Check if platform is desktop
  bool get isDesktop => this == Platform.macos || this == Platform.windows || this == Platform.linux;

  /// Check if platform is web
  bool get isWeb => this == Platform.web;

  @override
  String toString() => displayName;
}
