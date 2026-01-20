/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dcflight/framework/renderer/engine/engine_api.dart';
import 'package:dcflight/framework/utils/dcf_logger.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart' show DCFlightJniWrapper;

/// Hot reload detection and handling system for development
/// Uses a code change detection mechanism since DCFlight diverges from Flutter widgets
class HotReloadDetector {
  static HotReloadDetector? _instance;
  static HotReloadDetector get instance {
    _instance ??= HotReloadDetector._();
    return _instance!;
  }

  bool _isInitialized = false;
  
  HotReloadDetector._();

  /// Initialize hot reload detection system
  /// Hot reload is detected via reassemble() in HotReloadDetectorWidget
  /// Flutter automatically calls reassemble() on all State objects during hot reload
  void initialize() {
    if (!kDebugMode || _isInitialized) return;
    
    DCFLogger.debug('Hot reload detection ready - will be triggered via reassemble() on hot reload', 'HOT_RELOAD');
    _isInitialized = true;
  }

  /// Cleanup the hot reload detection system
  void dispose() {
    if (!_isInitialized) return;
    
    _isInitialized = false;
    
    DCFLogger.debug('Hot reload detection system disposed', 'HOT_RELOAD');
  }

  /// Handle hot reload - this is called when actual hot reload occurs
  Future<void> handleHotReload() async {
    if (!kDebugMode) return;
    
    DCFLogger.debug('Hot reload detected! Triggering VDOM tree re-render...', 'HOT_RELOAD');
    
    try {
      final vdom = DCFEngineAPI.instance;
      await vdom.isReady;
      await vdom.forceFullTreeReRender();
      DCFLogger.debug('VDOM hot reload completed successfully', 'HOT_RELOAD');
    } catch (e, stackTrace) {
      DCFLogger.error('Failed to handle hot reload: $e', tag: 'HOT_RELOAD');
      debugPrint('Hot reload error: $e\n$stackTrace');
    }
  }
}

/// A Flutter widget wrapper that detects hot reloads via reassemble()
/// Flutter automatically calls reassemble() on all State objects during hot reload
/// This is the standard way to detect hot reload in Flutter apps
class HotReloadDetectorWidget extends StatefulWidget {
  final Widget child;
  
  const HotReloadDetectorWidget({super.key, required this.child});
  
  @override
  State<HotReloadDetectorWidget> createState() => _HotReloadDetectorWidgetState();
}

class _HotReloadDetectorWidgetState extends State<HotReloadDetectorWidget> {
  @override
  void initState() {
    super.initState();
    HotReloadDetector.instance.initialize();
  }
  
  @override
  void dispose() {
    HotReloadDetector.instance.dispose();
    super.dispose();
  }
  
  /// Flutter calls this automatically on hot reload
  /// This is the standard Flutter hot reload detection mechanism
  @override
  void reassemble() {
    super.reassemble();
    // Flutter's hot reload detected - notify VDOM to update
    HotReloadDetector.instance.handleHotReload();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Global function to manually trigger hot reload for testing
void triggerManualHotReload() {
  if (kDebugMode) {
    HotReloadDetector.instance.handleHotReload().catchError((e) {
      debugPrint('Hot reload error: $e');
    });
  }
}


