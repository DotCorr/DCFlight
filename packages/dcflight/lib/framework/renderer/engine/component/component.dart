/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math';
import 'package:dcflight/framework/renderer/engine/component/hooks/memo_hook.dart';
import 'package:dcflight/framework/renderer/engine/component/hooks/store.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
import 'hooks/state_hook.dart';

// ignore: must_be_immutable
/// Stateful component with hooks and lifecycle methods + extension support
abstract class StatefulComponent extends DCFComponentNode {
  /// Unique ID for this component instance
  final String instanceId;

  /// The rendered node from the component
  DCFComponentNode? _renderedNode;

  /// Whether the component is mounted
  bool _isMounted = false;

  /// Whether the component is currently updating to prevent cascading updates
  bool _isUpdating = false;

  /// Current hook index during rendering
  int _hookIndex = 0;

  /// List of hooks
  final List<Hook> _hooks = [];

  /// Function to schedule updates when state changes
  Function() scheduleUpdate = () {};

  /// Create a stateful component
  StatefulComponent({super.key})
      : instanceId =
            '${DateTime.now().millisecondsSinceEpoch}.${Random().nextDouble()}' {
    scheduleUpdate = _defaultScheduleUpdate;
  }

  /// Default no-op schedule update function (replaced by VDOM)
  void _defaultScheduleUpdate() {}

  /// Render the component - must be implemented by subclasses
  DCFComponentNode render();

  /// Get the rendered node (lazily render if necessary)
  @override
  DCFComponentNode get renderedNode {
    if (_renderedNode == null) {
      prepareForRender();
      _renderedNode = render();

      if (_renderedNode != null) {
        _renderedNode!.parent = this;
      }
    }
    return _renderedNode!;
  }

  /// Set the rendered node
  @override
  set renderedNode(DCFComponentNode? node) {
    _renderedNode = node;
    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }
  }

  /// Get whether the component is mounted
  bool get isMounted => _isMounted;

  /// Called when the component is mounted
  @override
  void componentDidMount() {
    _isMounted = true;
  }

  /// Called when the component will unmount
  @override
  void componentWillUnmount() {
    // Clean up hooks first
    for (final hook in _hooks) {
      hook.dispose();
    }
    _hooks.clear();

    // Clean up any remaining store subscriptions via StoreManager
    // This is a safety net in case hooks didn't clean up properly
    try {
      // Note: StoreManager cleanup will be handled by individual hooks
    } catch (e) {}

    _isMounted = false;
  }

  /// Called after the component updates
  void componentDidUpdate(Map<String, dynamic> prevProps) {}

  /// Reset hook state for next render
  void prepareForRender() {
    _hookIndex = 0;
  }

  /// Create a state hook
  StateHook<T> useState<T>(T initialValue, [String? name]) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = StateHook<T>(initialValue, name, () {
        scheduleUpdate();
      });
      _hooks.add(hook);
    }

    // Get the hook (either existing or newly created)
    final hook = _hooks[_hookIndex] as StateHook<T>;
    _hookIndex++;

    return hook;
  }

  /// Standard effect hook - runs immediately after component mount
  /// This is the React-compatible useEffect that runs as soon as the component is mounted
  void useEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = EffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      // Update dependencies for existing hook
      final hook = _hooks[_hookIndex] as EffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  /// Layout effect hook - runs after component and its children are mounted
  /// This is ideal for DOM measurements, focus management, or operations that need
  /// the component tree to be fully rendered. Similar to React's useLayoutEffect.
  void useLayoutEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = LayoutEffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      // Update dependencies for existing hook
      final hook = _hooks[_hookIndex] as LayoutEffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  /// Insertion effect hook - runs after the entire component tree is ready
  /// This is ideal for operations that need the complete application tree,
  /// such as navigation commands, global state initialization, or third-party
  /// library integration that requires the full DOM structure.
  void useInsertionEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = InsertionEffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      // Update dependencies for existing hook
      final hook = _hooks[_hookIndex] as InsertionEffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  /// Create a ref hook
  RefObject<T> useRef<T>([T? initialValue]) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = RefHook<T>(initialValue);
      _hooks.add(hook);
    }

    // Get the hook (either existing or newly created)
    final hook = _hooks[_hookIndex] as RefHook<T>;
    _hookIndex++;

    return hook.ref;
  }

  /// Memoizes a value, re-creating it only when dependencies change.
  /// This is ideal for preserving instances of stateful child components.
  T useMemo<T>(T Function() create, {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook
      final hook = MemoHook<T>(create, dependencies);
      _hooks.add(hook);
    } else {
      // Update dependencies for existing hook
      final hook = _hooks[_hookIndex];
      if (hook is! MemoHook<T>) {
        throw Exception(
            'Hook at index $_hookIndex is not of type MemoHook<$T>');
      }
      hook.updateDependencies(dependencies);
    }

    final hook = _hooks[_hookIndex] as MemoHook<T>;
    _hookIndex++;
    return hook.value;
  }

  /// Create a store hook for global state
  StoreHook<T> useStore<T>(Store<T> store) {
    if (_hookIndex >= _hooks.length) {
      // Create new hook with update protection and component tracking
      final hook = StoreHook<T>(store, () {
        // Only schedule update if component is mounted and not already updating
        if (_isMounted && !_isUpdating) {
          _isUpdating = true;
          scheduleUpdate();
          // Reset updating flag after microtask to prevent rapid successive updates
          Future.microtask(() {
            _isUpdating = false;
          });
        }
      }, instanceId, runtimeType.toString());
      _hooks.add(hook);
    }

    // Get the hook (either existing or newly created)
    final hook = _hooks[_hookIndex] as StoreHook<T>;

    // Verify this hook is for the same store to prevent mismatches
    if (hook.store != store) {
      // Dispose the old hook and create a new one
      hook.dispose();
      final newHook = StoreHook<T>(store, () {
        if (_isMounted && !_isUpdating) {
          _isUpdating = true;
          scheduleUpdate();
          Future.microtask(() {
            _isUpdating = false;
          });
        }
      }, instanceId, runtimeType.toString());
      _hooks[_hookIndex] = newHook;
      _hookIndex++;
      return newHook;
    }

    _hookIndex++;
    return hook;
  }

  /// Use a custom hook registered via extensions
  T useCustomHook<T extends Hook>(String hookName, [List<dynamic>? args]) {
    if (_hookIndex >= _hooks.length) {
      final factory = VDomExtensionRegistry.instance.getHookFactory(hookName);
      if (factory == null) {
        throw Exception(
            'Hook "$hookName" not registered in VDomExtensionRegistry');
      }

      final hook = factory.createHook(this, args ?? []);
      if (hook is! T) {
        throw Exception('Hook "$hookName" is not of type $T');
      }

      _hooks.add(hook);
    }

    final hook = _hooks[_hookIndex];
    if (hook is! T) {
      throw Exception('Hook at index $_hookIndex is not of type $T');
    }

    _hookIndex++;
    return hook;
  }

  /// Run immediate effects after render - called by VDOM (existing behavior)
  void runEffectsAfterRender() {
    if (kDebugMode && runtimeType.toString().contains('Portal')) {
      // Debug logging for portal components
    }

    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      // Only run standard EffectHook, not the specialized subclasses
      if (hook is EffectHook &&
          hook is! LayoutEffectHook &&
          hook is! InsertionEffectHook) {
        if (kDebugMode && runtimeType.toString().contains('Portal')) {
          // Debug logging for portal effects
        }
        hook.runEffect();
      }
    }
  }

  /// Run layout effects after children are mounted - called by VDOM
  void runLayoutEffects() {
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is LayoutEffectHook) {
        hook.runEffect();
      }
    }
  }

  /// Run insertion effects after entire tree is ready - called by VDOM
  void runInsertionEffects() {
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is InsertionEffectHook) {
        hook.runEffect();
      }
    }
  }

  /// Implement VDomNode methods

  @override
  DCFComponentNode clone() {
    // Components can't be cloned easily due to state, hooks, etc.
    throw UnsupportedError("Stateful components cannot be cloned directly.");
  }

  @override
  bool equals(DCFComponentNode other) {
    if (other is! StatefulComponent) return false;
    // Components are considered equal if they're the same type with the same key
    return runtimeType == other.runtimeType && key == other.key;
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;

    // Ensure the component has rendered
    final node = renderedNode;

    // Mount the rendered content
    node.mount(this);
  }

  @override
  void unmount() {
    // Unmount the rendered content if any
    if (_renderedNode != null) {
      _renderedNode!.unmount();
      _renderedNode = null;
    }

    // Component lifecycle method
    componentWillUnmount();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}($instanceId)';
  }
}

// ignore: must_be_immutable
/// Stateless component without hooks or state
abstract class StatelessComponent extends DCFComponentNode {
  /// Unique ID for this component instance
  final String instanceId;

  /// The rendered node from the component
  DCFComponentNode? _renderedNode;

  /// Whether the component is mounted
  bool _isMounted = false;

  /// Create a stateless component
  StatelessComponent({super.key})
      : instanceId =
            '${DateTime.now().millisecondsSinceEpoch}.${Random().nextDouble()}';

  /// Render the component - must be implemented by subclasses
  DCFComponentNode render();

  /// Get the rendered node (lazily render if necessary)
  @override
  DCFComponentNode get renderedNode {
    _renderedNode ??= render();

    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }

    return _renderedNode!;
  }

  /// Set the rendered node
  @override
  set renderedNode(DCFComponentNode? node) {
    _renderedNode = node;
    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }
  }

  /// Get whether the component is mounted
  bool get isMounted => _isMounted;

  /// Called when the component is mounted
  @override
  void componentDidMount() {
    _isMounted = true;
  }

  /// Called when the component will unmount
  @override
  void componentWillUnmount() {
    _isMounted = false;
  }

  /// Implement VDomNode methods

  @override
  DCFComponentNode clone() {
    // Components can't be cloned easily
    throw UnsupportedError("Stateless components cannot be cloned directly.");
  }

  @override
  bool equals(DCFComponentNode other) {
    if (other is! StatelessComponent) return false;
    // Components are equal if they're the same type with the same key
    return runtimeType == other.runtimeType && key == other.key;
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;

    // Ensure the component has rendered
    final node = renderedNode;

    // Mount the rendered content
    node.mount(this);
  }

  @override
  void unmount() {
    // Unmount the rendered content if any
    if (_renderedNode != null) {
      _renderedNode!.unmount();
      _renderedNode = null;
    }

    // Component lifecycle method
    componentWillUnmount();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}($instanceId)';
  }
}
