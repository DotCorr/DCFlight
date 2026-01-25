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
  /// 
  /// Hot reload behavior:
  /// - Flutter recompiles changed code and injects it into the running Dart VM
  /// - Native views are cleared (like hot restart) so VDOM can recreate them from updated code
  /// - VDOM then recreates all views from the new component tree
  /// 
  /// This is different from hot restart:
  /// - Hot restart: Restarts Dart VM, clears all state, VDOM recreates from scratch
  /// - Hot reload: Recompiles code, clears native views, VDOM recreates from updated code
  /// 
  /// Both clear native views, but hot reload preserves Dart VM state (variables, etc.)
  Future<void> handleHotReload() async {
    if (!kDebugMode) return;
    
    DCFLogger.debug('Hot reload detected! Clearing native views and triggering VDOM re-render...', 'HOT_RELOAD');
    
    try {
      // CRITICAL: Clear native views (like hot restart) so VDOM can recreate from updated code
      // Hot reload recompiles the code, so we need to clear views and let VDOM recreate them
      await _cleanupNativeViews();
      
      final vdom = DCFEngineAPI.instance;
      await vdom.isReady;
      await vdom.forceFullTreeReRender();
      DCFLogger.debug('VDOM hot reload completed successfully', 'HOT_RELOAD');
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
      DCFLogger.debug('Hot reload: Native views cleared', 'HOT_RELOAD');
    } catch (e) {
      DCFLogger.debug('Hot reload cleanup failed (non-critical): $e', 'HOT_RELOAD');
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


