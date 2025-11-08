/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
import 'package:dcflight/framework/renderer/engine/component/component.dart';
import 'package:dcflight/framework/renderer/engine/component/hooks/state_hook.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/prop_diff_interceptor.dart';

/// VDOM Extension Registry - allows module devs to hook into VDOM internals
class VDomExtensionRegistry {
  static final VDomExtensionRegistry _instance = VDomExtensionRegistry._();
  static VDomExtensionRegistry get instance => _instance;
  VDomExtensionRegistry._();

  /// Custom reconciliation handlers for specific component types
  final Map<Type, VDomReconciliationHandler> _reconciliationHandlers = {};

  /// Custom lifecycle interceptors
  final Map<Type, VDomLifecycleInterceptor> _lifecycleInterceptors = {};

  /// Custom state change handlers
  final Map<Type, VDomStateChangeHandler> _stateChangeHandlers = {};

  /// Custom hook factories
  final Map<String, VDomHookFactory> _hookFactories = {};


 final List<PropDiffInterceptor> _propDiffInterceptors = [];
  
  /// Register a prop diff interceptor
  void registerPropDiffInterceptor(PropDiffInterceptor interceptor) {
    _propDiffInterceptors.add(interceptor);
  }
  
  /// Get all registered prop diff interceptors
  List<PropDiffInterceptor> getPropDiffInterceptors() {
    return List.unmodifiable(_propDiffInterceptors);
  }
  
  /// Unregister a prop diff interceptor
  void unregisterPropDiffInterceptor(PropDiffInterceptor interceptor) {
    _propDiffInterceptors.remove(interceptor);
  }


  /// Register custom reconciliation for a component type
  void registerReconciliationHandler<T extends DCFComponentNode>(
    VDomReconciliationHandler handler
  ) {
    _reconciliationHandlers[T] = handler;
  }

  /// Register lifecycle interceptor for a component type
  void registerLifecycleInterceptor<T extends DCFComponentNode>(
    VDomLifecycleInterceptor interceptor
  ) {
    _lifecycleInterceptors[T] = interceptor;
  }

  /// Register custom state change handler for a component type
  void registerStateChangeHandler<T extends DCFStatefulComponent>(
    VDomStateChangeHandler handler
  ) {
    _stateChangeHandlers[T] = handler;
  }

  /// Register custom hook factory
  void registerHookFactory(String hookName, VDomHookFactory factory) {
    _hookFactories[hookName] = factory;
  }

  /// Get handlers
  VDomReconciliationHandler? getReconciliationHandler(Type componentType) {
    return _reconciliationHandlers[componentType];
  }

  VDomLifecycleInterceptor? getLifecycleInterceptor(Type componentType) {
    return _lifecycleInterceptors[componentType];
  }

  VDomStateChangeHandler? getStateChangeHandler(Type componentType) {
    return _stateChangeHandlers[componentType];
  }

  VDomHookFactory? getHookFactory(String hookName) {
    return _hookFactories[hookName];
  }

  /// Clear all (for testing)
  void clear() {
    _reconciliationHandlers.clear();
    _lifecycleInterceptors.clear();
    _stateChangeHandlers.clear();
    _hookFactories.clear();
  }
}

/// Custom reconciliation handler - allows module devs to override reconciliation
abstract class VDomReconciliationHandler {
  /// Whether this handler should process the reconciliation
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode);

  /// Custom reconciliation logic
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  );
}

/// Custom lifecycle interceptor - allows hooking into VDOM lifecycle
abstract class VDomLifecycleInterceptor {
  /// Called before mount
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {}

  /// Called after mount
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {}

  /// Called before update
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {}

  /// Called after update
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {}

  /// Called before unmount
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {}

  /// Called after unmount
  void afterUnmount(DCFComponentNode node, VDomLifecycleContext context) {}
}

/// Custom state change handler - allows bypassing normal state updates
abstract class VDomStateChangeHandler {
  /// Whether this handler should process the state change
  bool shouldHandle(DCFStatefulComponent component, dynamic newState);

  /// Custom state change logic
  void handleStateChange(
    DCFStatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  );
}

/// Custom hook factory - allows creating hooks that integrate with VDOM
abstract class VDomHookFactory {
  /// Create the hook instance
  Hook createHook(DCFStatefulComponent component, List<dynamic> args);
}

/// Context objects that provide VDOM access to extensions

/// Reconciliation context
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

/// Lifecycle context
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

/// State change context
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


/// Example: Custom reconciliation handler
/// 
/// ```dart
/// class CustomReconciliationHandler extends VDomReconciliationHandler {
///   @override
///   bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
///     return newNode.runtimeType == MyCustomComponent;
///   }
/// 
///   @override
///   Future<void> reconcile(
///     DCFComponentNode oldNode, 
///     DCFComponentNode newNode,
///     VDomReconciliationContext context,
///   ) async {
///     // Custom reconciliation logic
///     await context.defaultReconcile(oldNode.renderedNode, newNode.renderedNode);
///   }
/// }
/// 
/// // Register it
/// VDomExtensionRegistry.instance.registerReconciliationHandler<MyCustomComponent>(
///   CustomReconciliationHandler()
/// );
/// ```

/// Example: Custom state hook that bypasses normal component updates
/// 
/// ```dart
/// class OptimizedStateHook<T> extends Hook {
///   T _value;
///   final Function(T) _setValue;
///   
///   OptimizedStateHook(this._value, this._setValue);
///   
///   T get value => _value;
///   
///   void setValue(T newValue) {
///     if (_value != newValue) {
///       _value = newValue;
///       _setValue(newValue); // Custom update logic
///     }
///   }
///   
///   @override
///   void dispose() {}
/// }
/// 
/// class OptimizedStateHookFactory extends VDomHookFactory {
///   @override
///   Hook createHook(StatefulComponent component, List<dynamic> args) {
///     final initialValue = args[0];
///     
///     return OptimizedStateHook(
///       initialValue,
///       (newValue) {
///         // Custom logic - maybe only update specific parts of UI
///         // instead of full component re-render
///       }
///     );
///   }
/// }
/// 
/// // Register it
/// VDomExtensionRegistry.instance.registerHookFactory(
///   'useOptimizedState',
///   OptimizedStateHookFactory()
/// );
/// ```

/// Example: Component-specific lifecycle handler
/// 
/// ```dart
/// class AnimatedComponentLifecycleInterceptor extends VDomLifecycleInterceptor {
///   @override
///   void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
///     // Set up animations before mount
///   }
/// 
///   @override
///   void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
///     // Pause animations during update
///   }
/// 
///   @override
///   void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
///     // Resume animations after update
///   }
/// }
/// 
/// // Register it for AnimatedView components
/// VDomExtensionRegistry.instance.registerLifecycleInterceptor<AnimatedView>(
///   AnimatedComponentLifecycleInterceptor()
/// );
/// `````