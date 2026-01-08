/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Manages system-level state changes (font scale, language, theme, etc.)
/// and provides a version counter that components can use to trigger updates
/// when system settings change without prop changes.
/// 
/// This enables signal-inspired reconciliation to detect system changes
/// by including the system version in component props.
class SystemStateManager {
  /// Global version counter - increments on any system change
  static int _version = 0;
  
  /// Get the current system state version
  /// Components can include this in props to trigger updates on system changes
  static int get version => _version;
  
  /// Notify that a system change occurred
  /// 
  /// This increments the global version counter, which will cause any component
  /// that includes `_systemVersion` in its props to be updated during reconciliation.
  /// 
  /// Examples of system changes:
  /// - Font scale changes (user adjusts system font size)
  /// - Language changes (user switches language)
  /// - Theme changes (dark/light mode)
  /// - Accessibility settings (reduced motion, high contrast, etc.)
  /// 
  /// Parameters:
  /// - [fontScale]: Set to true if font scale changed
  /// - [language]: Set to true if language/locale changed
  /// - [theme]: Set to true if theme/brightness changed
  /// - [accessibility]: Set to true if accessibility settings changed
  static void onSystemChange({
    bool fontScale = false,
    bool language = false,
    bool theme = false,
    bool accessibility = false,
  }) {
    _version++;
    
    // Log the change type for debugging
    final changeTypes = <String>[];
    if (fontScale) changeTypes.add('fontScale');
    if (language) changeTypes.add('language');
    if (theme) changeTypes.add('theme');
    if (accessibility) changeTypes.add('accessibility');
    
    if (changeTypes.isNotEmpty) {
      print('🔄 SystemStateManager: System change detected (version: $_version) - ${changeTypes.join(', ')}');
    }
  }
  
  /// Reset the version counter (useful for testing or hot restart)
  static void reset() {
    _version = 0;
  }
}

