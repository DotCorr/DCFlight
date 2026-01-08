/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Typedef for void callback functions
typedef VoidCallback = void Function();

/// A mutable value container that notifies listeners when changed.
///
/// Similar to React Native Skia's `useSharedValue`, this allows
/// animations to drive UI updates by mutating values.
///
/// Example:
/// ```dart
/// final x = AnimatedValue<double>(0.0);
///
/// // Update value (triggers listeners)
/// x.value = 100.0;
///
/// // Read value
/// print(x.value);
///
/// // Subscribe to changes
/// x.addListener(() => print('Value changed to ${x.value}'));
/// ```
class AnimatedValue<T> {
  T _value;
  final List<VoidCallback> _listeners = [];

  AnimatedValue(this._value);

  /// Get current value
  T get value => _value;

  /// Set value and notify listeners if changed
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      _notifyListeners();
    }
  }

  /// Add a listener that will be called when value changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a previously added listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of value change
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Clean up all listeners
  void dispose() {
    _listeners.clear();
  }

  @override
  String toString() => 'AnimatedValue($_value)';
}
