/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
    
    // Hot reload detection ready; no log by default to avoid console noise.
    _isInitialized = true;
  }

  /// Cleanup the hot reload detection system
  void dispose() {
    if (!_isInitialized) return;
    
    _isInitialized = false;
  }

  /// Handle hot reload - called when Flutter triggers reassemble().
  /// Clears native views and re-syncs the engine root (signals, no VDOM).
  Future<void> handleHotReload() async {
    if (!kDebugMode) return;

    try {
      // CRITICAL: Clear native views so we can recreate from updated code
      await _cleanupNativeViews();

      final engine = DCFEngineAPI.instance;
      await engine.isReady;
      await engine.recreateRootNativeViews();
    } catch (e, stackTrace) {
      DCFLogger.error('Failed to handle hot reload: $e', tag: 'HOT_RELOAD');
      debugPrint('Hot reload error: $e\n$stackTrace');
    }
  }
  
  /// Cleanup native views for hot reload (same as hot restart)
  Future<void> _cleanupNativeViews() async {
    try {
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.cleanupViews();
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.cleanupViews();
      }
    } catch (e) {
      // Non-critical; native views may already be cleared
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
  
  @override
  void reassemble() {
    super.reassemble();
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


