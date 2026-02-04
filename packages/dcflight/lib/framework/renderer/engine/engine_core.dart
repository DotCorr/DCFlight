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
import '../../constants/style/style_wrapper_util.dart';

/// Pure-signals engine: smart reconciliation, only update what changed.
class Engine {
  static const bool _kReconciliationLogs = true; // Set to false to disable logs
  
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
    final contentParentViewId = component.contentParentViewId;
    final contentIndex = component.contentIndex;
    if (contentViewId == null || contentParentViewId == null) return;

    if (_kReconciliationLogs) print('\n🔄 RECONCILING: ${component.runtimeType}');
    
    final oldRendered = component.renderedNode;

    component.prepareForRender();
    final newRendered = component.render();
    component.renderedNode = newRendered;
    newRendered.parent = component;

    await _bridge.startBatchUpdate();
    // SMART UPDATE: Only update what changed, keep unchanged views mounted
    await _reconcileNode(oldRendered, newRendered, contentParentViewId, contentIndex ?? 0);
    await _bridge.commitBatchUpdate();
    
    if (_kReconciliationLogs) print('✅ RECONCILIATION COMPLETE\n');
  }

  /// Reconcile old and new nodes - only update what changed
  /// This is TRUE signals behavior: unchanged views stay mounted
  Future<void> _reconcileNode(DCFComponentNode? oldNode, DCFComponentNode newNode, int parentViewId, int index) async {
    // Case 1: No old node - create new
    if (oldNode == null) {
      if (_kReconciliationLogs) print('🆕 CREATE: ${_nodeType(newNode)}');
      await renderToNative(newNode, parentViewId: parentViewId, index: index);
      return;
    }

    // Case 2: Both are elements - try to reuse view
    if (oldNode is DCFElement && newNode is DCFElement) {
      // Can reuse if type and key match
      if (oldNode.type == newNode.type && oldNode.key == newNode.key) {
        final viewId = oldNode.nativeViewId;
        if (viewId != null) {
          if (_kReconciliationLogs) print('♻️  REUSE: ${oldNode.type}#$viewId (view stays mounted)');
          
          // REUSE the native view - just update props if needed
          newNode.nativeViewId = viewId;
          _nodesByViewId[viewId] = newNode;
          
          // Update props if they changed
          final newProps = StyleWrapperUtil.wrapIfNeeded(newNode.elementProps);
          await _bridge.updateView(viewId, newProps);
          
          // Update event handlers
          EventRegistry().unregister(viewId);
          if (newNode.eventHandlers.isNotEmpty) {
            EventRegistry().register(viewId, newNode.eventHandlers);
          }
          
          // Reconcile children
          await _reconcileChildren(oldNode.children, newNode.children, viewId);
          return;
        }
      }
    }

    // Case 3: Both are stateful components - update in place
    if (oldNode is DCFStatefulComponent && newNode is DCFStatefulComponent) {
      if (oldNode.runtimeType == newNode.runtimeType && oldNode.key == newNode.key) {
        if (_kReconciliationLogs) print('♻️  REUSE: ${oldNode.runtimeType} (component stays mounted)');
        // Reuse the component instance - transfer state
        newNode.transferStateFrom(oldNode);
        // Don't need to do anything else - the component keeps its views
        return;
      }
    }

    // Case 4: Both are stateless components - check if we can reuse
    if (oldNode is DCFStatelessComponent && newNode is DCFStatelessComponent) {
      if (oldNode.runtimeType == newNode.runtimeType && oldNode.key == newNode.key) {
        if (_kReconciliationLogs) print('🔄 UPDATE: ${oldNode.runtimeType} (reconciling children)');
        // Check if props changed - for stateless, we need to check the component's fields
        // For now, be conservative and assume props changed - re-render
        final oldRendered = oldNode.renderedNode;
        final newRendered = newNode.render();
        newNode.renderedNode = newRendered;
        newRendered.parent = newNode;
        
        await _reconcileNode(oldRendered, newRendered, parentViewId, index);
        return;
      }
    }

    // Case 5: Types don't match or can't reconcile - replace
    // Delete old and create new
    if (_kReconciliationLogs) print('🔥 REPLACE: ${_nodeType(oldNode)} → ${_nodeType(newNode)}');
    final oldViewIds = _collectViewIds(oldNode);
    for (final vid in oldViewIds.reversed) {
      EventRegistry().unregister(vid);
      await _bridge.deleteView(vid);
      _nodesByViewId.remove(vid);
    }
    await renderToNative(newNode, parentViewId: parentViewId, index: index);
  }
  
  String _nodeType(DCFComponentNode node) {
    if (node is DCFElement) return node.type;
    return node.runtimeType.toString();
  }

  /// Reconcile children arrays
  Future<void> _reconcileChildren(List<DCFComponentNode> oldChildren, List<DCFComponentNode> newChildren, int parentViewId) async {
    final oldLen = oldChildren.length;
    final newLen = newChildren.length;
    final minLen = oldLen < newLen ? oldLen : newLen;

    if (_kReconciliationLogs && oldLen != newLen) {
      print('  📦 Children: $oldLen → $newLen (${newLen > oldLen ? "+${newLen - oldLen}" : newLen - oldLen})');
    }

    // Update existing children
    for (int i = 0; i < minLen; i++) {
      await _reconcileNode(oldChildren[i], newChildren[i], parentViewId, i);
    }

    // Add new children
    if (newLen > oldLen) {
      if (_kReconciliationLogs) print('  ➕ Adding ${newLen - oldLen} new children');
      for (int i = oldLen; i < newLen; i++) {
        await renderToNative(newChildren[i], parentViewId: parentViewId, index: i);
      }
    }

    // Remove extra old children
    if (oldLen > newLen) {
      if (_kReconciliationLogs) print('  ➖ Removing ${oldLen - newLen} old children');
      for (int i = newLen; i < oldLen; i++) {
        final oldViewIds = _collectViewIds(oldChildren[i]);
        for (final vid in oldViewIds.reversed) {
          EventRegistry().unregister(vid);
          await _bridge.deleteView(vid);
          _nodesByViewId.remove(vid);
        }
      }
    }

    // Update native children list
    final childIds = <int>[];
    for (final child in newChildren) {
      if (child is DCFElement && child.nativeViewId != null) {
        childIds.add(child.nativeViewId!);
      }
    }
    if (childIds.isNotEmpty) {
      await _bridge.setChildren(parentViewId, childIds);
    }
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
        node.contentParentViewId = parentViewId;
        node.contentIndex = index;

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

    final props = StyleWrapperUtil.wrapIfNeeded(element.elementProps);
    final ok = await _bridge
        .createView(viewId, element.type, props)
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

  /// Re-sync root to native without clearing engine state (for hot reload).
  /// Native views are assumed already cleared by caller (e.g. cleanupViews).
  Future<void> recreateRootNativeViews() async {
    await isReady;
    final root = rootComponent;
    if (root == null) return;
    
    DCFComponentNode newRendered;
    if (root is DCFStatefulComponent) {
      root.prepareForRender();
      newRendered = root.render();
    } else if (root is DCFStatelessComponent) {
      newRendered = root.render();
    } else {
      return;
    }
    
    EventRegistry().clear();
    _nodesByViewId.clear();
    root.renderedNode = newRendered;
    newRendered.parent = root;
    
    await _bridge.startBatchUpdate();
    await renderToNative(newRendered, parentViewId: 0);
    await _bridge.commitBatchUpdate();
  }

  Map<String, dynamic> getPerformanceMetrics() => {};
  void resetPerformanceMetrics() {}
}
