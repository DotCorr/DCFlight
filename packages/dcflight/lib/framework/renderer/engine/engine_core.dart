/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Engine — pure signals, no VDOM. Syncs component tree to native via bridge.
 */

import 'dart:async';

import '../interface/interface.dart';
import '../../events/event_registry.dart';
import '../../../src/components/component_node.dart';
import '../../../src/components/component.dart';
import '../../../src/components/dcf_element.dart';
import '../../../src/components/fragment.dart';
import '../../utils/widget_to_dcf_adaptor.dart' show WidgetToDCFAdaptor, widgetRegistry;
import '../../utils/flutter_widget_renderer.dart';

/// Pure-signals engine: no VDOM reconciliation, signal-driven sync to native.
class Engine {
  final PlatformInterface _bridge;
  final Completer<void> _readyCompleter = Completer<void>();
  int _viewIdCounter = 1;
  final Map<int, DCFComponentNode> _nodesByViewId = {};
  DCFComponentNode? rootComponent;
  final Map<String, DCFStatefulComponent> _statefulComponents = {};
  final Set<int> _nodesBeingRendered = {};
  final Set<String> _pendingUpdates = {};
  bool _batchUpdateInProgress = false;
  Timer? _updateTimer;

  Engine(this._bridge);

  Future<void> get isReady => _readyCompleter.future;

  Future<void> init() async {
    final ok = await _bridge.initialize();
    if (!ok) throw Exception('Failed to initialize native bridge');
    _bridge.setEventHandler(_handleNativeEvent);
    _readyCompleter.complete();
  }

  void _handleNativeEvent(int viewId, String eventType, Map<dynamic, dynamic> eventData) {
    EventRegistry().handleEvent(viewId, eventType, Map<String, dynamic>.from(eventData));
  }

  int _generateViewId() => _viewIdCounter++;

  void _registerComponent(DCFComponentNode component) {
    if (component is DCFStatefulComponent) {
      _statefulComponents[component.instanceId] = component;
      component.scheduleUpdate = () => _scheduleComponentUpdate(component);
    }
  }

  /// Collect all native view IDs in the subtree (for teardown on update).
  List<int> _collectViewIds(DCFComponentNode node) {
    final ids = <int>[];
    void walk(DCFComponentNode n) {
      if (n is DCFStatefulComponent || n is DCFStatelessComponent) {
        final r = n.renderedNode;
        if (r != null) {
          if (r is DCFElement && r.nativeViewId != null) {
            ids.add(r.nativeViewId!);
          }
          walk(r);
        }
      } else if (n is DCFFragment) {
        for (final c in n.children) {
          walk(c);
        }
      } else if (n is DCFElement) {
        if (n.nativeViewId != null) ids.add(n.nativeViewId!);
        for (final c in n.children) {
          walk(c);
        }
      }
    }
    walk(node);
    return ids;
  }

  void _scheduleComponentUpdate(DCFStatefulComponent component) {
    if (_pendingUpdates.contains(component.instanceId)) return;
    _pendingUpdates.add(component.instanceId);
    _updateTimer ??= Timer(Duration.zero, () {
      _updateTimer = null;
      _flushUpdates();
    });
  }

  Future<void> _flushUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    final ids = _pendingUpdates.toList();
    _pendingUpdates.clear();
    for (final id in ids) {
      final c = _statefulComponents[id];
      if (c == null || !c.isMounted) continue;
      await _syncComponentSubtree(c);
    }
  }

  Future<void> _syncComponentSubtree(DCFStatefulComponent component) async {
    final contentViewId = component.contentViewId;
    if (contentViewId == null) return;

    final oldRendered = component.renderedNode;
    final oldViewIds = _collectViewIds(oldRendered);

    component.prepareForRender();
    final newRendered = component.render();
    component.renderedNode = newRendered;
    newRendered.parent = component;

    await _bridge.startBatchUpdate();
    for (final vid in oldViewIds.reversed) {
      EventRegistry().unregister(vid);
      await _bridge.deleteView(vid);
      _nodesByViewId.remove(vid);
    }
    await renderToNative(newRendered, parentViewId: contentViewId, index: 0);
    await _bridge.commitBatchUpdate();
  }

  Future<void> createRoot(DCFComponentNode component) async {
    await isReady;
    rootComponent = component;
    if (component is DCFStatefulComponent) _registerComponent(component);
    await _bridge.startBatchUpdate();
    final rootNode = component.renderedNode;
    if (rootNode == null) throw StateError('Root component rendered null');
    await renderToNative(rootNode, parentViewId: 0);
    await _bridge.commitBatchUpdate();
  }

  Future<int?> renderToNative(DCFComponentNode node,
      {int? parentViewId, int? index}) async {
    await isReady;

    final nodeIdentity = identityHashCode(node);
    if (_nodesBeingRendered.contains(nodeIdentity)) {
      throw Exception('Render loop: ${node.runtimeType}');
    }
    _nodesBeingRendered.add(nodeIdentity);

    try {
      if (node is DCFFragment) {
        if (!node.isMounted) node.mount(node.parent);
        int i = index ?? 0;
        for (final child in node.children) {
          await renderToNative(child, parentViewId: parentViewId, index: i++);
        }
        return null;
      }

      if (node is DCFStatefulComponent || node is DCFStatelessComponent) {
        final renderedNode = node.renderedNode;
        if (renderedNode == null) throw Exception('Component rendered null');
        renderedNode.parent = node;
        _registerComponent(node);

        final viewId = await renderToNative(renderedNode,
            parentViewId: parentViewId, index: index);
        node.contentViewId = viewId;

        if (renderedNode is DCFElement && viewId != null) {
          _nodesByViewId[viewId] = renderedNode;
        }

        if (node is DCFStatefulComponent && !node.isMounted) {
          node.resetEffectsForFirstMount();
          node.componentDidMount();
          node.runEffectsAfterRender();
        } else if (node is DCFStatelessComponent && !node.isMounted) {
          node.componentDidMount();
        }
        return viewId;
      }

      if (node is DCFElement) {
        return await _renderElementToNative(node,
            parentViewId: parentViewId, index: index);
      }

      if (node is EmptyVDomNode) return null;

      return null;
    } finally {
      _nodesBeingRendered.remove(nodeIdentity);
    }
  }

  Future<int?> _renderElementToNative(DCFElement element,
      {int? parentViewId, int? index}) async {
    final viewId = element.nativeViewId ?? _generateViewId();
    _nodesByViewId[viewId] = element;
    element.nativeViewId = viewId;

    final ok = await _bridge
        .createView(viewId, element.type, element.elementProps)
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    if (!ok) return null;

    if (parentViewId != null) {
      await _bridge.attachView(viewId, parentViewId, index ?? 0);
    }

    final eventTypes = element.eventTypes;
    if (eventTypes.isNotEmpty) {
      await _bridge.addEventListeners(viewId, eventTypes);
      final handlers = element.eventHandlers;
      if (handlers.isNotEmpty) {
        EventRegistry().register(viewId, handlers);
      }
    }

    final childIds = <int>[];
    for (var i = 0; i < element.children.length; i++) {
      final childId = await renderToNative(element.children[i],
          parentViewId: viewId, index: i);
      if (childId != null) childIds.add(childId);
    }
    if (childIds.isNotEmpty) {
      await _bridge.setChildren(viewId, childIds);
    }
    return viewId;
  }

  Future<void> deleteView(int viewId) async {
    EventRegistry().unregister(viewId);
    await _bridge.deleteView(viewId);
    _nodesByViewId.remove(viewId);
  }

  Future<void> startBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      _batchUpdateInProgress = true;
      await _bridge.startBatchUpdate();
    }
  }

  Future<void> commitBatchUpdate() async {
    if (_batchUpdateInProgress) {
      _batchUpdateInProgress = false;
      await _bridge.commitBatchUpdate();
    }
  }

  Future<void> forceFullTreeReRender() async {
    await isReady;
    if (rootComponent == null) return;
    try {
      FlutterWidgetRenderer.instance.clearAllForHotRestart();
      WidgetToDCFAdaptor.clearAllForHotRestart();
      widgetRegistry.clearAll();
    } catch (_) {}
    _statefulComponents.clear();
    _nodesByViewId.clear();
    _pendingUpdates.clear();
    rootComponent = null;
    // Caller will createRoot again after this
  }

  Map<String, dynamic> getPerformanceMetrics() => {};
  void resetPerformanceMetrics() {}
}
