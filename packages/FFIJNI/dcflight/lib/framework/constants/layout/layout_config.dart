/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import '../../renderer/interface/interface_impl.dart';

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
    
    try {
      await PlatformInterfaceImpl.layoutChannel.invokeMethod('setUseWebDefaults', {
        'enabled': true
      });
      print("✅ LayoutConfig: Web defaults enabled successfully");
    } catch (e) {
      print("❌ LayoutConfig: Failed to enable web defaults - $e");
    }
  }
  
  /// Disable web defaults (use Yoga native defaults)
  static Future<void> disableWebDefaults() async {
    useWebDefaults = false;
    
    try {
      await PlatformInterfaceImpl.layoutChannel.invokeMethod('setUseWebDefaults', {
        'enabled': false
      });
      print("✅ LayoutConfig: Web defaults disabled successfully");
    } catch (e) {
      print("❌ LayoutConfig: Failed to disable web defaults - $e");
    }
  }
  
  /// Check if web defaults are currently enabled
  static bool isWebDefaultsEnabled() {
    return useWebDefaults;
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
