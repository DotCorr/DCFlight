/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'screen_utilities.dart';

/// Global font scale normalization utility
/// Ensures consistent font sizes across Android and iOS
/// Similar to React Native's PixelRatio.getFontScale() approach
class FontScale {
  /// Normalize font size for cross-platform consistency
  /// 
  /// On Android: SP already includes system font scale, so we normalize it
  /// On iOS: Points don't include system font scale, so we apply it
  /// 
  /// This ensures both platforms render the same visual size
  static double normalizeFontSize(double fontSize) {
    final fontScale = ScreenUtilities.instance.fontScale;
    
    // For consistency: normalize by dividing by font scale
    // This ensures that at default font scale (1.0), sizes match
    // When user increases font scale, both platforms scale proportionally
    return fontSize / fontScale;
  }
  
  /// Get the current font scale factor
  /// Similar to React Native's PixelRatio.getFontScale()
  static double getFontScale() {
    return ScreenUtilities.instance.fontScale;
  }
  
  /// Normalize letter spacing for cross-platform consistency
  static double normalizeLetterSpacing(double letterSpacing) {
    // Letter spacing should scale with font size
    final fontScale = ScreenUtilities.instance.fontScale;
    return letterSpacing / fontScale;
  }
}


