/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hot restart detection and cleanup system for development
/// Only active when kDebugMode is true
class HotRestartDetector {
  static const MethodChannel _channel = MethodChannel('dcflight/hot_restart');
  
  /// Check if a hot restart occurred and cleanup if needed
  static Future<bool> detectAndCleanup() async {
    // Only run in debug mode
    if (!kDebugMode) {
      return false;
    }
    
    try {
      // Check if we have a persisted session token in native memory
      final sessionToken = await _channel.invokeMethod<String>('getSessionToken');
      
      if (sessionToken != null) {
        // Hot restart detected - native memory persisted while Dart was wiped
        
        // Trigger native cleanup
        await _cleanupNativeViews();
        
        return true;
      } else {
        // Fresh cold start - no session token found
        
        // Create new session token for future hot restart detection
        await _createSessionToken();
        return false;
      }
    } catch (e) {
      // Platform channel not available or other error
      return false;
    }
  }
  
  /// Create a new session token in native memory
  static Future<void> _createSessionToken() async {
    try {
      await _channel.invokeMethod('createSessionToken');
    } catch (e) {
    }
  }
  
  /// Trigger native view cleanup
  static Future<void> _cleanupNativeViews() async {
    try {
      await _channel.invokeMethod('cleanupViews');
    } catch (e) {
    }
  }
  
  /// Clear session token (useful for testing or full app shutdown)
  static Future<void> clearSessionToken() async {
    if (!kDebugMode) return;
    
    try {
      await _channel.invokeMethod('clearSessionToken');
    } catch (e) {
    }
  }
}
