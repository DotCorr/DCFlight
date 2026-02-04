/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';
import 'package:dcflight/dcflight.dart';

/// Stateful component that listens to system-level changes (font scale, language, theme, etc.)
/// and triggers re-renders when they occur.
/// 
/// This wraps the app root to ensure system-level changes trigger state updates,
/// which cause components with `_systemVersion` in props to re-render and update.
/// 
/// **How it works:**
/// 1. Listens to `SystemStateManager.version` changes
/// 2. When version changes, triggers component re-render via `scheduleUpdate()`
/// 3. Components re-render with new `_systemVersion` in props
/// 4. Reconciliation detects prop change and sends update to native
/// 5. Native components detect `_systemVersion` change and force re-measurement
/// 
/// **Future-proof:** Works for any system change (font scale, language, theme, accessibility)
/// as long as `SystemStateManager.onSystemChange()` is called.
class CoreWrapper extends DCFStatefulComponent {
  final DCFComponentNode _child;
  int _previousSystemVersion = 0;
  DateTime? _lastScheduleTime;

  CoreWrapper(this._child, {super.key});

  @override
  DCFComponentNode render() {
    // Track system state version and trigger re-render when it changes
    useEffect(() {
      _previousSystemVersion = SystemStateManager.version;

      StreamSubscription<void>? subscription;
      subscription = ScreenUtilities.instance.dimensionChanges.listen((_) {
        final currentVersion = SystemStateManager.version;
        if (currentVersion != _previousSystemVersion) {
          _previousSystemVersion = currentVersion;
          // Throttle: avoid storm of updates if dimension/version fires repeatedly
          final now = DateTime.now();
          if (_lastScheduleTime == null ||
              now.difference(_lastScheduleTime!).inMilliseconds > 150) {
            _lastScheduleTime = now;
            scheduleUpdate();
          }
        }
      });

      return () => subscription?.cancel();
    }, dependencies: []);
    
    // Return the child - the state change will trigger reconciliation
    // which will process all children naturally
    return _child;
  }
}

