/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart' show DCFlightJniWrapper;

class HotRestartDetector {
  static const String _tag = 'HotRestartDetector';
  
  static Future<bool> detectAndCleanup() async {
    if (!kDebugMode) {
      return false;
    }
    
    try {
      print('🔥 HotRestartDetector: Checking for hot restart...');
      String? sessionToken;
      
      if (Platform.isIOS) {
        final result = await DCFlightFfiWrapper.getSessionToken();
        sessionToken = result as String?;
        print('🔥 HotRestartDetector: iOS session token: $sessionToken');
      } else if (Platform.isAndroid) {
        sessionToken = await DCFlightJniWrapper.getSessionToken();
        print('🔥 HotRestartDetector: Android session token: $sessionToken');
      }
      
      if (sessionToken != null) {
        print('🔥 HotRestartDetector: Hot restart detected! Session token exists: $sessionToken');
        await _cleanupNativeViews();
        return true;
      } else {
        print('🔥 HotRestartDetector: First launch - no session token found');
        await _createSessionToken();
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ HotRestartDetector: Error detecting hot restart: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  static Future<void> _createSessionToken() async {
    try {
      print('🔥 HotRestartDetector: Creating session token...');
      if (Platform.isIOS) {
        final token = await DCFlightFfiWrapper.createSessionToken();
        print('🔥 HotRestartDetector: Created iOS session token: $token');
      } else if (Platform.isAndroid) {
        final token = await DCFlightJniWrapper.createSessionToken();
        print('🔥 HotRestartDetector: Created Android session token: $token');
      }
    } catch (e, stackTrace) {
      print('❌ HotRestartDetector: Error creating session token: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  static Future<void> _cleanupNativeViews() async {
    try {
      print('🔥 HotRestartDetector: Starting native views cleanup...');
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.cleanupViews();
        print('✅ HotRestartDetector: iOS cleanup completed');
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.cleanupViews();
        print('✅ HotRestartDetector: Android cleanup completed');
      }
    } catch (e, stackTrace) {
      print('❌ HotRestartDetector: Error during cleanup: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  static Future<void> clearSessionToken() async {
    if (!kDebugMode) return;
    
    try {
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.clearSessionToken();
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.clearSessionToken();
      }
    } catch (e) {
    }
  }
}
