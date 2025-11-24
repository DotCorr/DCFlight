/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// A simple change notifier for canvas repainting.
///
/// Similar to Flutter's ChangeNotifier but simpler - just signals when
/// animations have updated and canvas needs to repaint.
///
/// Example:
/// ```dart
/// final notifier = CanvasRepaintNotifier();
/// notifier.addListener(() => canvas.repaint());
///
/// // Later, when animation updates:
/// notifier.notify();
/// ```
class CanvasRepaintNotifier {
  final List<VoidCallback> _listeners = [];

  /// Add a listener that will be called when notifyListeners is called
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a previously added listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that the canvas needs to repaint
  void notify() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Clean up all listeners
  void dispose() {
    _listeners.clear();
  }
}

/// Typedef for void callback functions
typedef VoidCallback = void Function();
