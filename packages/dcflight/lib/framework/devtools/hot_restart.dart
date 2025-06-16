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
        debugPrint('🔥 Hot Restart detected! Session token found: $sessionToken');
        
        // Trigger native cleanup
        await _cleanupNativeViews();
        
        debugPrint('🧹 Native views cleaned up successfully');
        return true;
      } else {
        // Fresh cold start - no session token found
        debugPrint('❄️ Cold start detected - no session token found');
        
        // Create new session token for future hot restart detection
        await _createSessionToken();
        return false;
      }
    } catch (e) {
      // Platform channel not available or other error
      debugPrint('⚠️ Hot restart detection failed: $e');
      return false;
    }
  }
  
  /// Create a new session token in native memory
  static Future<void> _createSessionToken() async {
    try {
      await _channel.invokeMethod('createSessionToken');
      debugPrint('🎫 Session token created for hot restart detection');
    } catch (e) {
      debugPrint('⚠️ Failed to create session token: $e');
    }
  }
  
  /// Trigger native view cleanup
  static Future<void> _cleanupNativeViews() async {
    try {
      await _channel.invokeMethod('cleanupViews');
      debugPrint('🧹 Native cleanup command sent');
    } catch (e) {
      debugPrint('⚠️ Native cleanup failed: $e');
    }
  }
  
  /// Clear session token (useful for testing or full app shutdown)
  static Future<void> clearSessionToken() async {
    if (!kDebugMode) return;
    
    try {
      await _channel.invokeMethod('clearSessionToken');
      debugPrint('🗑️ Session token cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear session token: $e');
    }
  }
}
