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
/// **Important**: Only triggers on font scale changes, NOT layout changes.
/// Layout changes (width/height) are handled natively and don't require rebuilds.
class CoreWrapper extends DCFStatefulComponent {
  final DCFComponentNode _child;
  int _updateCounter = 0;
  double _previousFontScale = 1.0;
  
  CoreWrapper(this._child, {super.key});
  
  @override
  DCFComponentNode render() {
    //Only trigger updates when font scale changes, not layout changes
    useEffect(() {
      // Initialize previous font scale
      _previousFontScale = ScreenUtilities.instance.fontScale;
      
      StreamSubscription<void>? subscription;
      subscription = ScreenUtilities.instance.dimensionChanges.listen((_) {
        // Check if font scale actually changed (not just layout)
        final currentFontScale = ScreenUtilities.instance.fontScale;
        
        if (currentFontScale != _previousFontScale) {
          print('🔄 CoreWrapper: Font scale changed: $_previousFontScale → $currentFontScale');
          _previousFontScale = currentFontScale;
          
          // Only trigger update when font scale changes
          // Layout changes are handled natively, no rebuild needed
          _updateCounter++;
          scheduleUpdate();
          print('✅ CoreWrapper: Update scheduled for font scale change, counter=$_updateCounter');
        } else {
          // Layout change only - skip rebuild (handled natively)
          print('⏭️ CoreWrapper: Layout change detected, skipping rebuild (handled natively)');
        }
      });
    
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

