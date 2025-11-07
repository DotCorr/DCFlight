/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';

import 'package:dcflight/framework/renderer/interface/interface.dart' show PlatformInterface;
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
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
      
      _vdom = DCFEngine(platformInterface);
      await _vdom!.isReady;
      
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
  Future<String?> renderToNative(DCFComponentNode node, {String? parentViewId, int? index}) async {
    await isReady;
    return _vdom!.renderToNative(node, parentViewId: parentViewId, index: index);
  }
  
  /// Create a portal with a target view ID
  Future<String> createPortal(String portalId,
      {required String parentViewId,
      Map<String, dynamic>? props,
      int? index}) async {
    await isReady;
    return _vdom!.createPortal(portalId,
        parentViewId: parentViewId, props: props, index: index);
  }
  
  /// Get current children of a view
  Future<List<String>> getCurrentChildren(String targetViewId) async {
    await isReady;
    return _vdom!.getCurrentChildren(targetViewId);
  }
  
  /// Update view children array directly
  Future<void> updateViewChildren(String targetViewId, List<String> childViewIds) async {
    await isReady;
    await _vdom!.updateViewChildren(targetViewId, childViewIds);
  }
  
  /// Delete orphaned views (for portal cleanup)
  Future<void> deleteViews(List<String> viewIds) async {
    await isReady;
    await _vdom!.deleteViews(viewIds);
  }
  
  /// Force a full tree re-render for debugging purposes
  Future<void> forceFullTreeReRender() async {
    await isReady;
    await _vdom!.forceFullTreeReRender();
  }
}


