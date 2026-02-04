/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';
import 'state_hook.dart' show Hook;

/// Context for tracking signal dependencies during reactive computations
/// Public so reactive_props.dart can access it
class SignalTrackingContext {
  static SignalTrackingContext? _current;
  final Set<ReactiveSignal> _dependencies = {};
  
  static SignalTrackingContext? get current => _current;
  
  /// Track signal dependencies and return both result and the context used
  static TrackingResult<T> track<T>(T Function() fn) {
    final context = SignalTrackingContext();
    final previous = _current;
    _current = context;
    try {
      final result = fn();
      return TrackingResult(result, context);
    } finally {
      _current = previous;
    }
  }
  
  void addDependency(ReactiveSignal signal) {
    _dependencies.add(signal);
  }
  
  Set<ReactiveSignal> get dependencies => _dependencies;
}

/// Result of tracking with the context that was used
class TrackingResult<T> {
  final T value;
  final SignalTrackingContext context;
  
  TrackingResult(this.value, this.context);
}

/// Pure reactive signal - Angular/SolidJS-style fine-grained reactivity
/// 
/// **Use for EVERYTHING - the engine optimizes automatically:**
/// - Props (text, colors, numbers) → Direct native updates (< 1ms)
/// - Structure (if/for, add/remove children) → Smart reconciliation (~5ms)
/// 
/// Example:
/// ```dart
/// final count = signal(0);
/// final showMenu = signal(false);
/// 
/// DCFView(
///   children: [
///     // Prop usage → direct update
///     DCFText(content: () => "Count: ${count()}"),
///     
///     // Structure usage → reconciliation
///     if (showMenu()) Menu(),
///   ],
/// )
/// 
/// count.set(1);        // Direct updateView()
/// showMenu.set(true);  // Re-render + reconcile
/// ```
class ReactiveSignal<T> extends Hook {
  T _value;
  final Set<_Subscriber> _subscribers = {};
  
  ReactiveSignal(this._value);
  
  /// Get the current value and track dependency
  T call() {
    // Track this signal as a dependency if we're in a reactive context
    final context = SignalTrackingContext.current;
    print('  🔎 Signal.call() - context: ${context != null ? "EXISTS" : "NULL"}');
    if (context != null) {
      context.addDependency(this);
      print('  🔎 Signal added as dependency to context');
    }
    return _value;
  }
  
  /// Get value without tracking (for logging, debugging, etc.)
  T get value => _value;
  
  /// Update value and notify all subscribers
  void set(T newValue) {
    if (_value == newValue) return;
    
    // Only log if reconciliation logging is enabled
    // print('🎯 SIGNAL UPDATE: $_value → $newValue (${_subscribers.length} subscribers)');
    
    _value = newValue;
    
    // Directly notify all subscribers
    for (final subscriber in _subscribers.toList()) {
      subscriber.notify();
    }
  }
  
  /// Update value using a function
  void update(T Function(T) fn) {
    set(fn(_value));
  }
  
  /// Subscribe a callback to this signal
  void subscribe(void Function() callback) {
    _subscribers.add(_Subscriber(callback));
  }
  
  /// Unsubscribe a callback
  void unsubscribe(void Function() callback) {
    _subscribers.removeWhere((sub) => sub.callback == callback);
  }
  
  /// Subscribe a view update (used by engine)
  void subscribeView(int viewId, Future<void> Function() updateFn) {
    _subscribers.add(_Subscriber(updateFn, viewId: viewId));
  }
  
  /// Unsubscribe all listeners for a view
  void unsubscribeView(int viewId) {
    _subscribers.removeWhere((sub) => sub.viewId == viewId);
  }
  
  /// Clear all subscribers (for cleanup)
  void dispose() {
    _subscribers.clear();
  }
  
  @override
  String toString() => 'Signal($_value)';
}

/// Computed signal - derives value from other signals
class ComputedSignal<T> extends ReactiveSignal<T> {
  final T Function() _compute;
  final Set<ReactiveSignal> _dependencies = {};
  bool _isDirty = true;
  
  ComputedSignal(this._compute) : super(_compute()) {
    _recompute();
  }
  
  void _recompute() {
    // Unsubscribe from old dependencies
    for (final dep in _dependencies) {
      dep.unsubscribe(_markDirty);
    }
    _dependencies.clear();
    
    // Track new dependencies
    final trackingResult = SignalTrackingContext.track(() {
      _value = _compute();
      return _value;
    });
    
    _dependencies.addAll(trackingResult.context.dependencies);
    
    // Subscribe to new dependencies
    for (final dep in _dependencies) {
      dep.subscribe(_markDirty);
    }
    
    _isDirty = false;
  }
  
  void _markDirty() {
    _isDirty = true;
    _recompute();
    
    // Notify our subscribers
    for (final subscriber in _subscribers.toList()) {
      subscriber.notify();
    }
  }
  
  @override
  T call() {
    if (_isDirty) {
      _recompute();
    }
    return super.call();
  }
}

/// Subscriber to a signal
class _Subscriber {
  final Function callback;
  final int? viewId;
  
  _Subscriber(this.callback, {this.viewId});
  
  void notify() {
    if (callback is Future<void> Function()) {
      (callback as Future<void> Function())();
    } else {
      callback();
    }
  }
}

/// Create a reactive signal - Angular-style fine-grained reactivity
/// 
/// **Updates native views directly without re-rendering!**
/// 
/// ```dart
/// final count = signal(0);
/// count.set(1);  // Direct native view update
/// ```
ReactiveSignal<T> signal<T>(T initialValue) => ReactiveSignal(initialValue);

/// Create a computed signal - automatically derives from other signals
/// 
/// ```dart
/// final doubled = computed(() => count() * 2);
/// // Auto-updates when count changes
/// ```
ComputedSignal<T> computed<T>(T Function() compute) => ComputedSignal(compute);

/// Reactive effect - runs when dependencies change
class ReactiveEffect {
  final void Function() _effect;
  final Set<ReactiveSignal> _dependencies = {};
  
  ReactiveEffect(this._effect) {
    _run();
  }
  
  void _run() {
    // Unsubscribe from old dependencies
    for (final dep in _dependencies) {
      dep.unsubscribe(_run);
    }
    _dependencies.clear();
    
    // Track dependencies and run effect
    final trackingResult = SignalTrackingContext.track(() {
      _effect();
      return null;
    });
    
    _dependencies.addAll(trackingResult.context.dependencies);
    
    // Subscribe to new dependencies
    for (final dep in _dependencies) {
      dep.subscribe(_run);
    }
  }
  
  void dispose() {
    for (final dep in _dependencies) {
      dep.unsubscribe(_run);
    }
    _dependencies.clear();
  }
}

/// Helper to create a reactive effect
ReactiveEffect effect(void Function() fn) => ReactiveEffect(fn);
