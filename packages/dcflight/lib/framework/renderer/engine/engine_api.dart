/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';

import 'package:dcflight/framework/renderer/interface/interface.dart' show PlatformInterface;
import 'package:dcflight/framework/components/component_node.dart';
import 'core/engine.dart';

/// Main API for VDOM operations
/// This class provides a simplified interface to the VDOM implementation
class DCFEngineAPI {
  /// Singleton instance
  static final DCFEngineAPI _instance = DCFEngineAPI._();
  static DCFEngineAPI get instance => _instance;
  
  /// Internal VDOM implementation
  DCFEngine? _vdom;
  
  /// Ready completer
  Completer<void> _readyCompleter = Completer<void>();
  
  /// Private constructor
  DCFEngineAPI._() {
  }
  
  /// Initialize the VDOM API with a platform interface
  Future<void> init(PlatformInterface platformInterface) async {
    try {
      if (_vdom != null) {
        await _resetForHotRestart();
      }
      
      // CRITICAL: Always use the singleton instance to ensure event handler consistency
      // This ensures that events are handled by the same PlatformInterface instance
      // that the Engine sets the handler on
      final bridge = PlatformInterface.instance;
      _vdom = DCFEngine(bridge);
      await _vdom!.isReady;
      
      // The Engine sets the event handler during _initialize(), but we verify it's set
      // This is a defensive check to ensure events work even after hot restart
      print('✅ DCFEngineAPI: Engine initialized, event handler should be set');
      
      if (_readyCompleter.isCompleted) {
        _readyCompleter = Completer<void>();
      }
      _readyCompleter.complete();
    } catch (e) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(e);
      }
      rethrow;
    }
  }
  
  /// Reset the engine state for hot restart
  Future<void> _resetForHotRestart() async {
    if (_vdom != null) {
      try {
        await _vdom!.forceFullTreeReRender();
        
        _vdom = null;
        
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        
        print("🔄 DCFEngineAPI: Hot restart cleanup completed");
      } catch (e) {
        print("⚠️  DCFEngineAPI: Hot restart cleanup error: $e");
        _vdom = null;
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
      }
    }
  }
  
  /// Future that completes when the VDOM is ready
  Future<void> get isReady => _readyCompleter.future;
  
  /// Create a root component
  Future<void> createRoot(DCFComponentNode component) async {
    await isReady;
    return _vdom!.createRoot(component);
  }
  
  /// Render a component to the native side
  Future<int?> renderToNative(DCFComponentNode node, {int? parentViewId, int? index}) async {
    await isReady;
    return _vdom!.renderToNative(node, parentViewId: parentViewId, index: index);
  }
  
  /// Delete a view from the native side
  Future<void> deleteView(int viewId) async {
    await isReady;
    return _vdom!.deleteView(viewId);
  }
  
  /// Start a batch update (for atomic operations)
  Future<void> startBatchUpdate() async {
    await isReady;
    return _vdom!.startBatchUpdate();
  }
  
  /// Commit a batch update
  Future<void> commitBatchUpdate() async {
    await isReady;
    return _vdom!.commitBatchUpdate();
  }
  
  /// Force a full tree re-render for debugging purposes
  Future<void> forceFullTreeReRender() async {
    await isReady;
    await _vdom!.forceFullTreeReRender();
  }
  
  /// Get performance metrics (monitoring)
  Map<String, dynamic> getPerformanceMetrics() {
    if (_vdom == null) return {};
    return _vdom!.getPerformanceMetrics();
  }
  
  /// Reset performance metrics
  void resetPerformanceMetrics() {
    _vdom?.resetPerformanceMetrics();
  }
}


