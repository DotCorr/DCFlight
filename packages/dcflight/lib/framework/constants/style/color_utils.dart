/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */




import 'package:dcflight/dcflight.dart';

/// Utility functions for color conversion
class ColorUtils {
  /// Convert a Color to hex string
  /// Returns 'transparent' for transparent colors, otherwise returns '#RRGGBB'
  static String colorToHex(Color color) {
    final alpha = (color.a * 255.0).round() & 0xff;
    if (alpha == 0) {
      return 'transparent';
    } else {
      final hexValue = color.toARGB32() & 0xFFFFFF;
      return '#${hexValue.toRadixString(16).padLeft(6, '0')}';
    }
  }
}
