/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:dcflight/framework/renderer/engine/index.dart';
import 'package:dcflight/framework/hooks/context_hook.dart';
import 'package:dcflight/framework/context/context.dart';
import 'package:flutter/foundation.dart';

abstract class DCFStatefulComponent extends DCFComponentNode {
  final String instanceId;
  DCFComponentNode? _renderedNode;
  bool _isMounted = false;
  bool _isUpdating = false;
  int _hookIndex = 0;
  final List<Hook> _hooks = [];
  Function() scheduleUpdate = () {};

  DCFStatefulComponent({super.key})
      : instanceId = '${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}' {
    scheduleUpdate = _defaultScheduleUpdate;
  }

  void _defaultScheduleUpdate() {}

  DCFComponentNode render();

  @override
  DCFComponentNode get renderedNode {
    if (_renderedNode == null) {
      prepareForRender();
      final rawRendered = render();

      // 🔧 CRITICAL: Automatically wrap component returns in View for stable root container
      // This ensures VDOM always has a stable root, preventing parent search issues
      // This is transparent to the user - they can still return single elements/components
      if (rawRendered is DCFElement) {
        _renderedNode = rawRendered;
      } else {
        // Wrap in View to ensure stable root container
        // CRITICAL FIX: Don't force flex: 1 or height: 100% - let content size naturally
        // This prevents layout issues where wrapped content tries to fill parent incorrectly
        _renderedNode = DCFElement(
          type: 'View',
          elementProps: {
            'display': 'flex',
            'flexDirection': 'column',
            'alignItems': 'stretch',
            'justifyContent': 'flex-start',
            // Removed flex: 1 and height: '100%' to allow natural sizing
            // Content will size based on its own layout properties
          },
          children: [rawRendered],
        );
      }

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

  /// Consume a context value from the nearest provider ancestor
  /// 
  /// Example:
  /// ```dart
  /// final ThemeContext = createContext<Theme>();
  /// 
  /// class MyComponent extends DCFStatefulComponent {
  ///   @override
  ///   DCFComponentNode render() {
  ///     final theme = useContext(ThemeContext);
  ///     return DCFText(text: 'Current theme: ${theme.name}');
  ///   }
  /// }
  /// ```
  /// 
  /// Throws an exception if no provider is found and no defaultValue was provided.
  T useContext<T>(DCFContext<T> context) {
    if (_hookIndex >= _hooks.length) {
      final hook = ContextHook<T>(context, this);
      _hooks.add(hook);
    } else {
      final existingHook = _hooks[_hookIndex];
      if (existingHook is ContextHook<T> && existingHook.context == context) {
        _hookIndex++;
        return existingHook.value;
      } else {
        // Replace with new hook if context changed
        final hook = ContextHook<T>(context, this);
        _hooks[_hookIndex] = hook;
      }
    }

    final hook = _hooks[_hookIndex] as ContextHook<T>;
    _hookIndex++;
    return hook.value;
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

  /// Reset all effects for first mount
  /// This is called BEFORE componentDidMount to ensure effects run on first mount
  /// even after hot restart when hooks might be reused with stale state
  /// This is called by the engine during component mounting
  void resetEffectsForFirstMount() {
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is EffectHook) {
        // Force effect to run on first mount by resetting _prevDeps
        hook.resetForFirstMount();
      }
    }
  }

  /// Run effects after render (like React's useEffect)
  /// 
  /// This is called after the component is mounted and rendered.
  /// Effects are guaranteed to run on first mount, and then whenever
  /// their dependencies change.
  /// 
  /// Effects are reset BEFORE componentDidMount is called (in _resetEffectsForFirstMount)
  /// to ensure they always run on first mount, even after hot restart.
  void runEffectsAfterRender() {
    if (kDebugMode && runtimeType.toString().contains('Portal')) {
    }

    // Run all effect hooks (but not layout or insertion effects)
    // Effects have already been reset for first mount if needed
    for (var i = 0; i < _hooks.length; i++) {
      final hook = _hooks[i];
      if (hook is EffectHook &&
          hook is! LayoutEffectHook &&
          hook is! InsertionEffectHook) {
        if (kDebugMode && runtimeType.toString().contains('Portal')) {
        }
        // runEffect() handles first-run detection internally
        // _prevDeps was reset to null in _resetEffectsForFirstMount if this is first mount
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

abstract class DCFStatelessComponent extends DCFComponentNode {
  DCFComponentNode? _renderedNode;
  bool _isMounted = false;

  DCFStatelessComponent({super.key});

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

