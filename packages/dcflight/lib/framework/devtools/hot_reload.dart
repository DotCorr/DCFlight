/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dcflight/framework/renderer/engine/engine_api.dart';
import 'package:dcflight/framework/utils/dcf_logger.dart';

/// Hot reload detection and handling system for development
/// Uses a code change detection mechanism since DCFlight diverges from Flutter widgets
class HotReloadDetector {
  static HotReloadDetector? _instance;
  static HotReloadDetector get instance {
    _instance ??= HotReloadDetector._();
    return _instance!;
  }

  bool _isInitialized = false;
  Timer? _monitorTimer;
  
  HotReloadDetector._();

  /// Initialize hot reload detection system
  void initialize() {
    if (!kDebugMode || _isInitialized) return;
    
    DCFLogger.debug('Initializing hot reload detection system', 'HOT_RELOAD');
    
    WidgetsBinding.instance.addObserver(_HotReloadObserver(this));
    
    _isInitialized = true;
    
    DCFLogger.debug('Hot reload detection system initialized with automatic detection', 'HOT_RELOAD');
  }

  /// Cleanup the hot reload detection system
  void dispose() {
    if (!_isInitialized) return;
    
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isInitialized = false;
    
    DCFLogger.debug('Hot reload detection system disposed', 'HOT_RELOAD');
  }

  /// Handle hot reload - this is called when actual hot reload occurs
  Future<void> handleHotReload() async {
    if (!kDebugMode) {
      debugPrint('⚠️ Hot reload called but not in debug mode');
      print('⚠️ Hot reload called but not in debug mode');
      return;
    }
    
    debugPrint('🔥🔥🔥 DCFlight HotReloadDetector.handleHotReload() called 🔥🔥🔥');
    print('🔥 DCFlight HotReloadDetector.handleHotReload() called');
    DCFLogger.debug('🔥 REAL Hot reload detected! Triggering VDOM tree re-render...', 'HOT_RELOAD');
    
    try {
      // Small delay to ensure any pending operations complete
      await Future.delayed(Duration(milliseconds: 100));
      
      debugPrint('🔥 Calling _triggerVDOMHotReload()...');
      print('🔥 Calling _triggerVDOMHotReload()...');
      await _triggerVDOMHotReload();
      
      debugPrint('✅✅✅ VDOM hot reload completed successfully ✅✅✅');
      print('✅ VDOM hot reload completed successfully');
      DCFLogger.debug('✅ VDOM hot reload completed successfully', 'HOT_RELOAD');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Failed to handle hot reload: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      print('❌ Failed to handle hot reload: $e');
      print('❌ Stack trace: $stackTrace');
      DCFLogger.error('Failed to handle hot reload: $e', tag: 'HOT_RELOAD');
    }
  }

  /// Trigger a complete VDOM tree re-render for hot reload
  Future<void> _triggerVDOMHotReload() async {
    debugPrint('🔥 _triggerVDOMHotReload() called');
    print('🔥 _triggerVDOMHotReload() called');
    
    try {
      final vdom = DCFEngineAPI.instance;
      debugPrint('🔥 Got DCFEngineAPI instance');
      print('🔥 Got DCFEngineAPI instance');
      
      debugPrint('🔥 Waiting for engine to be ready...');
      print('🔥 Waiting for engine to be ready...');
      await vdom.isReady;
      debugPrint('✅ Engine is ready');
      print('✅ Engine is ready');
      
      debugPrint('🔥🔥🔥 Calling forceFullTreeReRender()... 🔥🔥🔥');
      print('🔥 Calling forceFullTreeReRender()...');
      await vdom.forceFullTreeReRender();
      debugPrint('✅✅✅ forceFullTreeReRender() completed ✅✅✅');
      print('✅ forceFullTreeReRender() completed');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Error in _triggerVDOMHotReload(): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      print('❌ Error in _triggerVDOMHotReload(): $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// A Flutter widget wrapper that can detect hot reloads 
/// Use this if you need to wrap any Flutter widgets in your DCFlight app
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
/// Call this from your development tools or debug console
void triggerManualHotReload() {
  // Use debugPrint for better visibility on iOS
  debugPrint('🔥🔥🔥 triggerManualHotReload() called 🔥🔥🔥');
  print('🔥 triggerManualHotReload() called');
  if (kDebugMode) {
    debugPrint('🔥 Calling HotReloadDetector.instance.handleHotReload()');
    print('🔥 Calling HotReloadDetector.instance.handleHotReload()');
    // Don't await - fire and forget to avoid blocking HTTP response
    HotReloadDetector.instance.handleHotReload().catchError((e, stackTrace) {
      debugPrint('❌❌❌ Hot reload error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      print('❌ Hot reload error: $e');
      print('❌ Stack trace: $stackTrace');
    });
  } else {
    debugPrint('🔥 Not in debug mode, skipping hot reload');
    print('🔥 Not in debug mode, skipping hot reload');
  }
}

/// Observer to detect Flutter hot reload events
class _HotReloadObserver extends WidgetsBindingObserver {
  final HotReloadDetector _detector;
  
  _HotReloadObserver(this._detector);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
  }
  
  @override
  Future<bool> didPushRoute(String route) async {
    if (kDebugMode) {
      _detector.handleHotReload();
    }
    return false;
  }
  
  @override
  void didHaveMemoryPressure() {
  }
}

