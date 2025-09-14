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
    
    DCFLogger.debug('HOT_RELOAD', 'Initializing hot reload detection system');
    
    // Set up automatic hot reload detection using Flutter's reassembly callback
    WidgetsBinding.instance.addObserver(_HotReloadObserver(this));
    
    _isInitialized = true;
    
    DCFLogger.debug('HOT_RELOAD', 'Hot reload detection system initialized with automatic detection');
  }

  /// Cleanup the hot reload detection system
  void dispose() {
    if (!_isInitialized) return;
    
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isInitialized = false;
    
    DCFLogger.debug('HOT_RELOAD', 'Hot reload detection system disposed');
  }

  /// Handle hot reload - this is called when actual hot reload occurs
  Future<void> handleHotReload() async {
    if (!kDebugMode) return;
    
    print('🔥 DCFlight HotReloadDetector.handleHotReload() called');
    DCFLogger.debug('HOT_RELOAD', '🔥 REAL Hot reload detected! Triggering VDOM tree re-render...');
    
    try {
      // Add a small delay to ensure Flutter has finished its reassembly
      await Future.delayed(Duration(milliseconds: 50));
      
      // Trigger full VDOM tree re-render while preserving navigation state
      await _triggerVDOMHotReload();
      
      DCFLogger.debug('HOT_RELOAD', '✅ VDOM hot reload completed successfully');
    } catch (e) {
      DCFLogger.error('HOT_RELOAD', 'Failed to handle hot reload: $e');
    }
  }

  /// Trigger a complete VDOM tree re-render for hot reload
  Future<void> _triggerVDOMHotReload() async {
    final vdom = DCFEngineAPI.instance;
    
    // Wait for VDOM to be ready
    await vdom.isReady;
    
    // Get access to the internal engine to trigger hot reload
    await vdom.forceFullTreeReRender();
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
    // Initialize hot reload detection when this widget is created
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
    // This is called during hot reload
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
  print('🔥 triggerManualHotReload() called');
  if (kDebugMode) {
    print('🔥 Calling HotReloadDetector.instance.handleHotReload()');
    HotReloadDetector.instance.handleHotReload();
  } else {
    print('🔥 Not in debug mode, skipping hot reload');
  }
}

/// Observer to detect Flutter hot reload events
class _HotReloadObserver extends WidgetsBindingObserver {
  final HotReloadDetector _detector;
  
  _HotReloadObserver(this._detector);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Not used for hot reload detection
  }
  
  @override
  Future<bool> didPushRoute(String route) async {
    // Potential hot reload indicator
    if (kDebugMode) {
      _detector.handleHotReload();
    }
    return false;
  }
  
  @override
  void didHaveMemoryPressure() {
    // Not used for hot reload detection
  }
}

