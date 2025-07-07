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
  late final DCFEngine _vdom;
  
  /// Ready completer
  final Completer<void> _readyCompleter = Completer<void>();
  
  /// Private constructor
  DCFEngineAPI._() {
    // Will be initialized explicitly with init()
  }
  
  /// Initialize the VDOM API with a platform interface
  Future<void> init(PlatformInterface platformInterface) async {
    try {
      _vdom = DCFEngine(platformInterface);
      await _vdom.isReady;
      _readyCompleter.complete();
    } catch (e) {
      _readyCompleter.completeError(e);
      rethrow;
    }
  }
  
  /// Future that completes when the VDOM is ready
  Future<void> get isReady => _readyCompleter.future;
  
  /// Create a root component
  Future<void> createRoot(DCFComponentNode component) async {
    await isReady;
    return _vdom.createRoot(component);
  }
  
  /// Render a node to native UI
  Future<String?> renderToNative(DCFComponentNode node,
      {String? parentViewId, int? index}) async {
    await isReady;
    return _vdom.renderToNative(node, parentViewId: parentViewId, index: index);
  }
  
  /// Create a portal container with the specified ID and properties
  Future<String> createPortal(String portalId, {
    String? parentViewId,
    Map<String, dynamic>? props,
    int? index,
  }) async {
    await isReady;
    return _vdom.createPortal(portalId, 
      parentViewId: parentViewId ?? 'root',
      props: props ?? {},
      index: index ?? 0);
  }
  
  /// Get the current child view IDs of a target container
  /// This allows portal content to be appended rather than replaced
  List<String> getCurrentChildren(String targetViewId) {
    return _vdom.getCurrentChildren(targetViewId);
  }

  /// Update a target container's children (for portal content)
  /// This ensures the native bridge call goes through the VDOM system
  Future<void> updateTargetChildren(String targetViewId, List<String> childViewIds) async {
    await isReady;
    // Use the VDOM's public method to maintain proper integration
    await _vdom.updateViewChildren(targetViewId, childViewIds);
  }
  
  /// Delete orphaned views (for portal cleanup)
  Future<void> deleteViews(List<String> viewIds) async {
    await isReady;
    await _vdom.deleteViews(viewIds);
  }
}
