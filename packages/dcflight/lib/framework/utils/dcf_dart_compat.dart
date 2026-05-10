/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

/// Pure-Dart compatibility layer – replaces all package:flutter dependencies
/// that were previously used in DCFlight internals.
///
/// This file is the boundary between DCFlight's runtime and the Dart/dart:ui
/// SDK. No package:flutter import should exist anywhere in packages/dcflight
/// after this migration.
library dcf_dart_compat;

// ─────────────────────────────────────────────────────────────────────────────
// Color
// ─────────────────────────────────────────────────────────────────────────────
// A 32-bit ARGB color value, API-compatible with dart:ui's Color so that all
// existing DCFColor(0xFFRRGGBB) call sites continue to work unchanged.

class Color {
  final int value;

  const Color(int value) : value = value & 0xFFFFFFFF;

  int get alpha => (0xff000000 & value) >> 24;
  int get red => (0x00ff0000 & value) >> 16;
  int get green => (0x0000ff00 & value) >> 8;
  int get blue => (0x000000ff & value) >> 0;

  double get opacity => alpha / 0xFF;

  Color withOpacity(double opacity) {
    return withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
  }

  Color withAlpha(int a) {
    return Color((value & 0x00ffffff) | ((a & 0xff) << 24));
  }

  Color withRed(int r) => Color((value & 0xFF00FFFF) | ((r & 0xff) << 16));
  Color withGreen(int g) => Color((value & 0xFFFF00FF) | ((g & 0xff) << 8));
  Color withBlue(int b) => Color((value & 0xFFFFFF00) | (b & 0xff));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Color && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'Color(0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Debug / build-mode constants
// ─────────────────────────────────────────────────────────────────────────────

/// True when the application is compiled in debug mode (dart.vm.product=false).
const bool kDebugMode = !bool.fromEnvironment('dart.vm.product');

/// True when the application is compiled in profile mode.
const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');

/// True when the application is compiled in release mode.
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

/// True when running on the web.
const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

// ─────────────────────────────────────────────────────────────────────────────
// Utility functions
// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in replacement for Flutter's debugPrint.
void debugPrint(String? message, {int? wrapWidth}) {
  // ignore: avoid_print
  print(message);
}
