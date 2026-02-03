/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Public API for the engine — same surface as DCFEngineAPI (pure signals, no VDOM).
 */

import 'dart:async';

import '../interface/interface.dart';
import '../../../src/components/component_node.dart';
import 'engine_core.dart';

/// Engine API: pure signals, no VDOM. Same interface as previous engine.
class DCFEngineAPI {
  static final DCFEngineAPI _instance = DCFEngineAPI._();
  static DCFEngineAPI get instance => _instance;

  Engine? _engine;
  Completer<void> _readyCompleter = Completer<void>();

  DCFEngineAPI._();

  Future<void> init(PlatformInterface platformInterface) async {
    try {
      if (_engine != null) {
        await _resetForHotRestart();
      }
      final bridge = PlatformInterface.instance;
      _engine = Engine(bridge);
      await _engine!.init();
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

  Future<void> _resetForHotRestart() async {
    if (_engine != null) {
      try {
        await _engine!.forceFullTreeReRender();
        _engine = null;
        if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      } catch (e) {
        _engine = null;
        if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      }
    }
  }

  Future<void> get isReady => _readyCompleter.future;

  Future<void> createRoot(DCFComponentNode component) async {
    await isReady;
    return _engine!.createRoot(component);
  }

  Future<int?> renderToNative(DCFComponentNode node,
      {int? parentViewId, int? index}) async {
    await isReady;
    return _engine!.renderToNative(node,
        parentViewId: parentViewId, index: index);
  }

  Future<void> deleteView(int viewId) async {
    await isReady;
    return _engine!.deleteView(viewId);
  }

  Future<void> startBatchUpdate() async {
    await isReady;
    return _engine!.startBatchUpdate();
  }

  Future<void> commitBatchUpdate() async {
    await isReady;
    return _engine!.commitBatchUpdate();
  }

  Future<void> forceFullTreeReRender() async {
    await isReady;
    await _engine!.forceFullTreeReRender();
  }

  Map<String, dynamic> getPerformanceMetrics() =>
      _engine?.getPerformanceMetrics() ?? {};

  void resetPerformanceMetrics() {
    _engine?.resetPerformanceMetrics();
  }
}
