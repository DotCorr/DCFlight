/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'package:dcflight/dcflight.dart';

/// Stateful component that listens to OS-level changes (font scale, language, etc.)
/// and triggers re-renders when they occur.
/// 
/// This wraps the app root to ensure OS-level changes trigger state updates,
/// which cause the entire app to re-render with new values.
/// 
class CoreWrapper extends DCFStatefulComponent {
  final DCFComponentNode _child;
  int _updateCounter = 0;
  
  CoreWrapper(this._child, {super.key});
  
  @override
  DCFComponentNode render() {
    // Use useEffect to subscribe to dimension changes (React-style)
    // This ensures the subscription is properly managed and re-runs when needed
    useEffect(() {
      print('🔄 CoreWrapper: Setting up dimension change listener...');
      
      StreamSubscription<void>? subscription;
      subscription = ScreenUtilities.instance.dimensionChanges.listen((_) {
        print('🔄 CoreWrapper: Dimension change detected, triggering update...');
        // Simple state update - increment counter to force re-render
        // This will trigger a re-render of this component, which will reconcile
        // its rendered node (the child), propagating changes through the entire tree
        _updateCounter++;
        scheduleUpdate();
        print('✅ CoreWrapper: Update scheduled, counter=$_updateCounter');
      });
      
      // Return cleanup function (React-style)
      return () {
        print('🔄 CoreWrapper: Cleaning up dimension change listener...');
        subscription?.cancel();
      };
    }, dependencies: []); // Empty deps = run once on mount, cleanup on unmount
    
    // Return the child - the state change will trigger reconciliation
    // which will process all children naturally
    return _child;
  }
}

