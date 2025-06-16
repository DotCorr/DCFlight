/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */




import 'package:dcflight/dcflight.dart';

/// Utility functions for color conversion
class ColorUtils {
  /// Convert a Color to hex string
  /// Returns 'transparent' for transparent colors, otherwise returns '#RRGGBB'
  static String colorToHex(Color color) {
    // Check for transparency first (same pattern as in style_properties.dart)
    final alpha = (color.a * 255.0).round() & 0xff;
    if (alpha == 0) {
      return 'transparent';
    } else {
      final hexValue = color.toARGB32() & 0xFFFFFF;
      return '#${hexValue.toRadixString(16).padLeft(6, '0')}';
    }
  }
}
