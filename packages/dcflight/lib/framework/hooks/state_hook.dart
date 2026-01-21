/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/hooks/store.dart';

/// Base hook class for all hook types
abstract class Hook {
  /// Clean up the hook when component unmounts
  void dispose() {}
}

/// State hook for managing component state
class StateHook<T> extends Hook {
  /// Current value of the state
  T _value;

  /// Name for debugging
  final String? _name;

  /// Schedule update function to trigger re-render
  Function() _scheduleUpdate;

  /// Create a state hook
  StateHook(this._value, this._name, this._scheduleUpdate);

  /// Get the current value
  T get state => _value;

  /// Set the value and trigger update
  void setState(T newValue) {
    print("🔥 STATE_HOOK: setState called - old: $_value, new: $newValue");
    if (_value != newValue) {
      print("🔥 STATE_HOOK: Value changed, updating and scheduling render");
      _value = newValue;
      
      print("🔥 STATE_HOOK: Calling _scheduleUpdate");
      _scheduleUpdate();
      print("🔥 STATE_HOOK: _scheduleUpdate completed");
    } else {
      print("🔥 STATE_HOOK: Value unchanged, skipping update");
    }
  }
  
  @override
  void dispose() {
    // 🔥 CRITICAL: Clear _scheduleUpdate closure to break reference cycle
    // The _scheduleUpdate closure captures the component instance, preventing GC
    // Even though hooks are disposed, we need to explicitly clear the closure
    _scheduleUpdate = () {}; // Replace with no-op to break reference
  }
  
  @override
  String toString() {
    final name = _name != null ? ' ($_name)' : '';
    return 'StateHook$name: $_value';
  }
}

/// Effect hook for side effects in components
class EffectHook extends Hook {
  /// The effect function
  final Function()? Function() _effect;

  /// Dependencies array - when these change, effect runs again
  List<dynamic> _dependencies;

  /// Cleanup function returned by the effect
  Function()? _cleanup;

  /// Previous dependencies for comparison
  List<dynamic>? _prevDeps;

  /// Create an effect hook
  EffectHook(this._effect, this._dependencies);
  
  /// Update dependencies - called during reconciliation
  /// 
  /// CRITICAL: This is called during reconciliation, but we don't run cleanup here.
  /// Cleanup only happens in runEffect() when dependencies actually change.
  /// This prevents unnecessary cleanup during reconciliation loops.
  void updateDependencies(List<dynamic> newDependencies) {
    _dependencies = newDependencies;
    // Don't run cleanup here - wait for runEffect() to determine if deps actually changed
  }
  
  /// Reset hook state for first mount
  /// This ensures effects always run on first mount, even if the hook
  /// was reused from a previous component instance (e.g., after hot restart)
  /// This is called by the framework when a component mounts for the first time
  void resetForFirstMount() {
    _prevDeps = null;
    // Don't reset _cleanup here - let runEffect() handle cleanup properly
    // This ensures effects run on first mount even after hot restart
  }

  /// Run the effect if needed based on dependency changes
  /// 
  /// Effects always run on first mount (_prevDeps == null).
  /// After that, they only run when dependencies actually change.
  /// 
  /// CRITICAL: This compares dependencies BEFORE running cleanup, preventing
  /// unnecessary cleanup during reconciliation loops when deps haven't changed.
  void runEffect() {
    // Check if dependencies actually changed BEFORE running cleanup
    // This prevents unnecessary cleanup during reconciliation loops
    final depsChanged = _prevDeps == null || !_areEqualDeps(_dependencies, _prevDeps!);
    
    if (depsChanged) {
      // Dependencies changed - cleanup old effect and run new one
      if (_cleanup != null) {
        try {
          _cleanup!();
        } catch (e) {
          // Ignore cleanup errors
        }
        _cleanup = null;
      }

      // Run the effect
      try {
        _cleanup = _effect?.call();
      } catch (e, stackTrace) {
        // Log effect errors but don't crash
        print('⚠️ EffectHook: Error running effect: $e');
        print('Stack trace: $stackTrace');
      }
      
      // Update previous dependencies to track changes
      _prevDeps = List<dynamic>.from(_dependencies);
    }
    // If deps haven't changed, do nothing - keep existing cleanup and effect
  }

  @override
  void dispose() {
    if (_cleanup != null) {
      try {
        _cleanup!();
      } catch (e) {
      }
      _cleanup = null;
    }
  }

  /// Compare two dependency arrays for equality
  bool _areEqualDeps(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    
    return true;
  }
}

/// Layout effect hook - runs after component and its children are mounted
/// This is ideal for DOM measurements, focus management, or operations that need
/// the component tree to be fully rendered
class LayoutEffectHook extends EffectHook {
  /// Create a layout effect hook
  LayoutEffectHook(super.effect, super.dependencies);
  
  @override
  String toString() {
    return 'LayoutEffectHook(deps: ${_dependencies.length})';
  }
}

/// Insertion effect hook - runs after the entire component tree is ready
/// This is ideal for operations that need the complete application tree,
/// such as navigation commands, global state initialization, or third-party
/// library integration that requires the full DOM structure
class InsertionEffectHook extends EffectHook {
  /// Create an insertion effect hook
  InsertionEffectHook(super.effect, super.dependencies);
  
  @override
  String toString() {
    return 'InsertionEffectHook(deps: ${_dependencies.length})';
  }
}

/// Reference object wrapper
class RefObject<T> {
  /// Current value
  T? _value;

  /// Create a ref object
  RefObject([this._value]);

  /// Get current value
  T? get current => _value;
  
  /// Set current value
  set current(T? value) {
    _value = value;
  }
}

/// Ref hook for storing mutable references
class RefHook<T> extends Hook {
  /// The ref object
  final RefObject<T> ref;

  /// Create a ref hook
  RefHook([T? initialValue]) : ref = RefObject<T>(initialValue);
  
  @override
  void dispose() {
  }
}

/// Store hook for connecting to global state
class StoreHook<T> extends Hook {
  /// The store
  final Store<T> _store;
  
  /// Component information for tracking
  final String? _componentId;
  final String? _componentType;
  
  /// Get the store (for hook validation)
  Store<T> get store => _store;
  
  /// State change callback
  final Function() _onChange;
  
  /// Listener function reference for unsubscribing
  late final void Function(T) _listener;
  
  /// Flag to track if we're subscribed to prevent double subscription
  bool _isSubscribed = false;
  
  /// Debounce flag to prevent multiple rapid updates
  bool _updatePending = false;

  /// Create a store hook
  StoreHook(this._store, this._onChange, [this._componentId, this._componentType]) {
    if (_componentId != null && _componentType != null) {
        _store.trackHookAccess(_componentId!, _componentType!);
    }
    
    _listener = (T _) {
      if (_updatePending) {
        return;
      }
      
      _updatePending = true;
      
      Future.microtask(() {
        if (_updatePending && _isSubscribed) {
          _updatePending = false;
          _onChange();
        }
      });
    };
    
    if (!_isSubscribed) {
      _store.subscribe(_listener);
      _isSubscribed = true;
    }
  }

  /// Get current state
  T get state => _store.state;
  
  /// Update store state
  void setState(T newState) {
    _store.setState(newState);
  }
  
  /// Update store state with a function
  void updateState(T Function(T) updater) {
    _store.updateState(updater);
  }

  @override
  void dispose() {
    if (_isSubscribed) {
      _store.unsubscribe(_listener);
      _isSubscribed = false;
    }
    _updatePending = false;
  }
}