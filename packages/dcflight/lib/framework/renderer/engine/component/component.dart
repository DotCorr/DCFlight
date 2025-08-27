/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/engine/component/hooks/memo_hook.dart';
import 'package:dcflight/framework/renderer/engine/component/hooks/store.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
import 'package:equatable/equatable.dart';
import 'hooks/state_hook.dart';

// ignore: must_be_immutable
abstract class StatefulComponent extends DCFComponentNode with EquatableMixin {
  // Keep instanceId for internal tracking only (not for reconciliation)
  final String instanceId;
  DCFComponentNode? _renderedNode;
  bool _isMounted = false;
  bool _isUpdating = false;
  int _hookIndex = 0;
  final List<Hook> _hooks = [];
  Function() scheduleUpdate = () {};

  StatefulComponent({super.key})
      : instanceId = '${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}' {
    scheduleUpdate = _defaultScheduleUpdate;
  }

  /// Abstract props getter - StatefulComponents must implement this for Equatable
  @override
  List<Object?> get props;

  void _defaultScheduleUpdate() {}

  DCFComponentNode render();

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

  @override
  set renderedNode(DCFComponentNode? node) {
    _renderedNode = node;
    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }
  }

  bool get isMounted => _isMounted;

  @override
  void componentDidMount() {
    _isMounted = true;
  }

  @override
  void componentWillUnmount() {
    for (final hook in _hooks) {
      hook.dispose();
    }
    _hooks.clear();

    try {
    } catch (e) {
      if (kDebugMode) {
        print('Error during component unmount cleanup: $e');
      }
    }

    _isMounted = false;
  }

  void componentDidUpdate(Map<String, dynamic> prevProps) {}

  void prepareForRender() {
    _hookIndex = 0;
  }

  StateHook<T> useState<T>(T initialValue, [String? name]) {
    if (_hookIndex >= _hooks.length) {
      final hook = StateHook<T>(initialValue, name, () {
        scheduleUpdate();
      });
      _hooks.add(hook);
    }

    final hook = _hooks[_hookIndex] as StateHook<T>;
    _hookIndex++;

    return hook;
  }

  void useEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      final hook = EffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      final hook = _hooks[_hookIndex] as EffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  void useLayoutEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      final hook = LayoutEffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      final hook = _hooks[_hookIndex] as LayoutEffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  void useInsertionEffect(Function()? Function() effect,
      {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      final hook = InsertionEffectHook(effect, dependencies);
      _hooks.add(hook);
    } else {
      final hook = _hooks[_hookIndex] as InsertionEffectHook;
      hook.updateDependencies(dependencies);
    }

    _hookIndex++;
  }

  RefObject<T> useRef<T>([T? initialValue]) {
    if (_hookIndex >= _hooks.length) {
      final hook = RefHook<T>(initialValue);
      _hooks.add(hook);
    }

    final hook = _hooks[_hookIndex] as RefHook<T>;
    _hookIndex++;

    return hook.ref;
  }

  T useMemo<T>(T Function() create, {List<dynamic> dependencies = const []}) {
    if (_hookIndex >= _hooks.length) {
      final hook = MemoHook<T>(create, dependencies);
      _hooks.add(hook);
    } else {
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

  StoreHook<T> useStore<T>(Store<T> store) {
    if (_hookIndex >= _hooks.length) {
      final hook = StoreHook<T>(store, () {
        if (_isMounted && !_isUpdating) {
          _isUpdating = true;
          scheduleUpdate();
          Future.microtask(() {
            _isUpdating = false;
          });
        }
      }, '${runtimeType}_${key ?? hashCode}', runtimeType.toString());
      _hooks.add(hook);
    }

    final hook = _hooks[_hookIndex] as StoreHook<T>;

    if (hook.store != store) {
      hook.dispose();
      final newHook = StoreHook<T>(store, () {
        if (_isMounted && !_isUpdating) {
          _isUpdating = true;
          scheduleUpdate();
          Future.microtask(() {
            _isUpdating = false;
          });
        }
      }, '${runtimeType}_${key ?? hashCode}', runtimeType.toString());
      _hooks[_hookIndex] = newHook;
      _hookIndex++;
      return newHook;
    }

    _hookIndex++;
    return hook;
  }

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

  void runEffectsAfterRender() {
    if (kDebugMode && runtimeType.toString().contains('Portal')) {
    }

    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is EffectHook &&
          hook is! LayoutEffectHook &&
          hook is! InsertionEffectHook) {
        if (kDebugMode && runtimeType.toString().contains('Portal')) {
        }
        hook.runEffect();
      }
    }
  }

  void runLayoutEffects() {
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is LayoutEffectHook) {
        hook.runEffect();
      }
    }
  }

  void runInsertionEffects() {
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is InsertionEffectHook) {
        hook.runEffect();
      }
    }
  }

  @override
  DCFComponentNode clone() {
    throw UnsupportedError("Stateful components cannot be cloned directly.");
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;
    final node = renderedNode;
    node.mount(this);
  }

  @override
  void unmount() {
    if (_renderedNode != null) {
      _renderedNode!.unmount();
      _renderedNode = null;
    }
    componentWillUnmount();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}(${key ?? hashCode})';
  }
}

// ignore: must_be_immutable
abstract class StatelessComponent extends DCFComponentNode with EquatableMixin {
  DCFComponentNode? _renderedNode;
  bool _isMounted = false;

  StatelessComponent({super.key});

  @override
  List<Object?> get props;

  DCFComponentNode render();

  @override
  DCFComponentNode get renderedNode {
    _renderedNode ??= render();

    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }

    return _renderedNode!;
  }

  @override
  set renderedNode(DCFComponentNode? node) {
    _renderedNode = node;
    if (_renderedNode != null) {
      _renderedNode!.parent = this;
    }
  }

  bool get isMounted => _isMounted;

  @override
  void componentDidMount() {
    _isMounted = true;
  }

  @override
  void componentWillUnmount() {
    _isMounted = false;
  }

  @override
  DCFComponentNode clone() {
    throw UnsupportedError("Stateless components cannot be cloned directly.");
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;
    final node = renderedNode;
    node.mount(this);
  }

  @override
  void unmount() {
    if (_renderedNode != null) {
      _renderedNode!.unmount();
      _renderedNode = null;
    }
    componentWillUnmount();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}(${key ?? hashCode})';
  }
}

