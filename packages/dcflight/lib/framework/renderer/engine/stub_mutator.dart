/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Stub VDOM extension registry for the engine — no VDOM reconciliation.
 * Same API as engine_mutator_extension_reg so component layer keeps working.
 */

import '../../../src/components/component_node.dart';
import '../../../src/components/component.dart';
import '../../hooks/state_hook.dart';
import 'prop_diff_interceptor.dart';

class VDomExtensionRegistry {
  static final VDomExtensionRegistry _instance = VDomExtensionRegistry._();
  static VDomExtensionRegistry get instance => _instance;
  VDomExtensionRegistry._();

  final Map<Type, VDomReconciliationHandler> _reconciliationHandlers = {};
  final Map<Type, VDomLifecycleInterceptor> _lifecycleInterceptors = {};
  final Map<Type, VDomStateChangeHandler> _stateChangeHandlers = {};
  final Map<String, VDomHookFactory> _hookFactories = {};
  final List<PropDiffInterceptor> _propDiffInterceptors = [];

  void registerPropDiffInterceptor(PropDiffInterceptor interceptor) {
    _propDiffInterceptors.add(interceptor);
  }

  List<PropDiffInterceptor> getPropDiffInterceptors() =>
      List.unmodifiable(_propDiffInterceptors);

  void unregisterPropDiffInterceptor(PropDiffInterceptor interceptor) {
    _propDiffInterceptors.remove(interceptor);
  }

  void registerReconciliationHandler<T extends DCFComponentNode>(
      VDomReconciliationHandler handler) {
    _reconciliationHandlers[T] = handler;
  }

  void registerLifecycleInterceptor<T extends DCFComponentNode>(
      VDomLifecycleInterceptor interceptor) {
    _lifecycleInterceptors[T] = interceptor;
  }

  void registerStateChangeHandler<T extends DCFStatefulComponent>(
      VDomStateChangeHandler handler) {
    _stateChangeHandlers[T] = handler;
  }

  void registerHookFactory(String hookName, VDomHookFactory factory) {
    _hookFactories[hookName] = factory;
  }

  VDomReconciliationHandler? getReconciliationHandler(Type componentType) =>
      _reconciliationHandlers[componentType];

  VDomLifecycleInterceptor? getLifecycleInterceptor(Type componentType) =>
      _lifecycleInterceptors[componentType];

  VDomStateChangeHandler? getStateChangeHandler(Type componentType) =>
      _stateChangeHandlers[componentType];

  VDomHookFactory? getHookFactory(String hookName) =>
      _hookFactories[hookName];

  void clear() {
    _reconciliationHandlers.clear();
    _lifecycleInterceptors.clear();
    _stateChangeHandlers.clear();
    _hookFactories.clear();
    _propDiffInterceptors.clear();
  }
}

abstract class VDomReconciliationHandler {
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode);
  Future<void> reconcile(
    DCFComponentNode oldNode,
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  );
}

abstract class VDomLifecycleInterceptor {
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {}
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {}
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {}
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {}
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {}
  void afterUnmount(DCFComponentNode node, VDomLifecycleContext context) {}
}

abstract class VDomStateChangeHandler {
  bool shouldHandle(DCFStatefulComponent component, dynamic newState);
  void handleStateChange(
    DCFStatefulComponent component,
    dynamic oldState,
    dynamic newState,
    VDomStateChangeContext context,
  );
}

abstract class VDomHookFactory {
  Hook createHook(DCFStatefulComponent component, List<dynamic> args);
}

class VDomReconciliationContext {
  final Function(DCFComponentNode, DCFComponentNode) defaultReconcile;
  final Function(DCFComponentNode, DCFComponentNode) replaceNode;
  final Function(DCFComponentNode) mountNode;
  final Function(DCFComponentNode) unmountNode;

  VDomReconciliationContext({
    required this.defaultReconcile,
    required this.replaceNode,
    required this.mountNode,
    required this.unmountNode,
  });
}

class VDomLifecycleContext {
  final Function() scheduleUpdate;
  final Function(DCFComponentNode) forceUpdate;
  final Map<String, dynamic> vdomState;

  VDomLifecycleContext({
    required this.scheduleUpdate,
    required this.forceUpdate,
    required this.vdomState,
  });
}

class VDomStateChangeContext {
  final Function() scheduleUpdate;
  final Function() skipUpdate;
  final Function(DCFComponentNode) partialUpdate;

  VDomStateChangeContext({
    required this.scheduleUpdate,
    required this.skipUpdate,
    required this.partialUpdate,
  });
}
