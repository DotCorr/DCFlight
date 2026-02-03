/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Pure signals layer for the engine — no VDOM, reactive updates only.
///
/// Inspired by Solid/React Server Signals: fine-grained reactivity where
/// writes propagate and only affected effects re-run.

import 'dart:async';

/// Listener callback for signal changes (dynamic so effects can subscribe to any signal)
typedef SignalListener = void Function(dynamic value, dynamic previous);

/// A reactive signal. Reading it tracks the current effect; writing it notifies.
class Signal<T> {
  T _value;
  final List<SignalListener> _listeners = [];
  bool _readOnly = false;

  Signal(this._value, [String? name]);

  T get value => _read();
  set value(T v) => _write(v);

  T _read() {
    final current = _currentEffect;
    if (current != null) {
      if (!current._sources.contains(this)) {
        current._sources.add(this);
        _listeners.add(current._onSignalChange!);
      }
    }
    return _value;
  }

  void _write(T v) {
    if (_readOnly) return; // computed signals are read-only from outside
    if (identical(_value, v)) return;
    final prev = _value;
    _value = v;
    for (final fn in List<SignalListener>.from(_listeners)) {
      fn(v, prev);
    }
  }

  /// Internal: allow computed to push value from effect
  void setValueInternal(T v) {
    if (identical(_value, v)) return;
    final prev = _value;
    _value = v;
    for (final fn in List<SignalListener>.from(_listeners)) {
      fn(v, prev);
    }
  }

  /// Call [fn] and return its result; re-run when any read signal changes.
  static T _runEffect<T>(EffectCell cell, T Function() fn) {
    cell._dispose();
    cell._sources.clear();
    _currentEffect = cell;
    try {
      return fn();
    } finally {
      _currentEffect = null;
    }
  }

  static EffectCell? _currentEffect;
}

/// Internal effect cell so effects can re-subscribe when re-running
class EffectCell {
  final void Function() _fn;
  final Set<Signal> _sources = {};
  void Function(dynamic, dynamic)? _onSignalChange;
  bool _disposed = false;

  EffectCell(this._fn) {
    _onSignalChange = (_, __) {
      if (_disposed) return;
      _scheduleEffect(this);
    };
  }

  void _dispose() {
    final fn = _onSignalChange;
    if (fn != null) {
      for (final s in _sources) {
        s._listeners.remove(fn);
      }
    }
    _sources.clear();
  }

  void run() {
    Signal._runEffect(this, () {
      _fn();
      return null;
    });
  }
}

void _scheduleEffectImpl(EffectCell c) {
  Future.microtask(() {
    if (!c._disposed) c.run();
  });
}

void Function(EffectCell) _scheduleEffect = _scheduleEffectImpl;

/// Creates a reactive signal with initial value [initial].
Signal<T> createSignal<T>(T initial, [String? name]) => Signal<T>(initial);

/// Runs [fn] immediately and again whenever any signal read inside [fn] changes.
/// Returns a dispose function.
void Function() effect(void Function() fn) {
  final cell = EffectCell(fn);
  cell.run();
  return () {
    cell._disposed = true;
    cell._dispose();
  };
}

/// Schedules effect to run on the next microtask (batched).
void Function() effectScheduled(void Function() fn) {
  return effect(() {
    final f = fn;
    Future.microtask(f);
  });
}

/// Creates a derived (computed) signal. Re-computes only when any read signal changes.
Signal<R> computed<R>(R Function() fn, [String? name]) {
  final s = Signal<R>(fn()).._readOnly = true;
  final cell = EffectCell(() {
    s.setValueInternal(fn());
  });
  cell.run(); // subscribe to sources and set initial derived value
  return s;
}

/// Optional: set a custom scheduler for effects (e.g. batch with requestAnimationFrame).
void setEffectScheduler(void Function(EffectCell) scheduler) {
  _scheduleEffect = scheduler;
}
