/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
      String? sessionToken;
      
      if (Platform.isIOS) {
        final result = await DCFlightFfiWrapper.getSessionToken();
        sessionToken = result as String?;
      } else if (Platform.isAndroid) {
        sessionToken = await DCFlightJniWrapper.getSessionToken();
      }
      
      if (sessionToken != null) {
        await _cleanupNativeViews();
        return true;
      } else {
        await _createSessionToken();
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> _createSessionToken() async {
    try {
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.createSessionToken();
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.createSessionToken();
      }
    } catch (e) {
    }
  }
  
  static Future<void> _cleanupNativeViews() async {
    try {
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.cleanupViews();
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.cleanupViews();
      }
    } catch (e) {
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
