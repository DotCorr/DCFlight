/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Reactive props - handle signals in element properties
 */

import '../../../framework/hooks/reactive_signal.dart';

/// Set to true to log reactive prop processing (very verbose).
const bool _kReactivePropsDebug = false;

/// Tracks reactive properties for a native view
class ReactiveViewProps {
  final int viewId;
  final Map<String, ReactiveSignal> _signalProps = {};
  final Map<String, Function> _reactiveFunctions = {};
  final Map<String, List<ReactiveSignal>> _functionDependencies = {};
  final Map<String, dynamic> _staticProps = {};
  
  ReactiveViewProps(this.viewId);
  
  /// Process props and extract reactive signals
  /// Returns the resolved (static) props for initial native view creation
  Map<String, dynamic> processProps(Map<String, dynamic> props) {
    final resolvedProps = <String, dynamic>{};
    
    if (_kReactivePropsDebug) print('🔎 View#$viewId processing ${props.length} props');
    
    for (final entry in props.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (_kReactivePropsDebug) print('  🔎 Prop "$key": ${value.runtimeType}');
      
      if (value is ReactiveSignal) {
        // Track this as a reactive prop
        _signalProps[key] = value;
        // Resolve current value for initial render
        resolvedProps[key] = value.value;
      } else if (value is Function) {
        // Check if this is an event handler (starts with 'on') or reactive function
        if (key.startsWith('on')) {
          // Event handler - pass through as-is (takes parameters)
          _staticProps[key] = value;
          resolvedProps[key] = value;
        } else {
          // Reactive function - track dependencies
          if (_kReactivePropsDebug) print('  🔎 Attempting to track function for "$key"');
          
          try {
            final deps = <ReactiveSignal>[];
            
            final trackingResult = SignalTrackingContext.track(() {
              final fnResult = value();
              if (_kReactivePropsDebug) print('  🔎 Function executed, result: $fnResult');
              return fnResult;
            });
            
            // Use the context from the track() call (current is restored after track returns)
            final context = trackingResult.context;
            if (_kReactivePropsDebug) print('  🔎 Context has ${context.dependencies.length} dependencies');
            
            if (context.dependencies.isNotEmpty) {
              deps.addAll(context.dependencies);
              if (_kReactivePropsDebug) print('🔍 View#$viewId prop "$key": found ${deps.length} signal dependencies');
              
              // Store reactive function with all its signal dependencies
              _reactiveFunctions[key] = value;
              _functionDependencies[key] = deps;
            }
            
            // Store the unwrapped value for native (TrackingResult is not JSON-encodable)
            resolvedProps[key] = trackingResult.value;
          } catch (e, stack) {
            if (_kReactivePropsDebug) {
              print('⚠️ View#$viewId prop "$key": failed to track (treating as static): $e');
              print('  Stack: $stack');
            }
            // If calling function fails (wrong args), treat as static - use called value for native (must be encodable)
            _staticProps[key] = value;
            try {
              resolvedProps[key] = value();
            } catch (_) {
              resolvedProps[key] = null;
            }
          }
        }
      } else {
        // Static prop
        _staticProps[key] = value;
        resolvedProps[key] = value;
      }
    }
    
    return resolvedProps;
  }
  
  /// Subscribe this view to all its reactive props
  void subscribeSignals(Future<void> Function(Map<String, dynamic>) updateFn) {
    // Subscribe to direct signal props
    for (final entry in _signalProps.entries) {
      final key = entry.key;
      final signal = entry.value;
      
      if (_kReactivePropsDebug) print('📌 View#$viewId subscribing to signal for prop "$key"');
      
      signal.subscribeView(viewId, () async {
        if (_kReactivePropsDebug) print('  🔄 Direct update: view#$viewId.$key = ${signal.value}');
        await updateFn({key: signal.value});
      });
    }
    
    // Subscribe to reactive functions
    for (final entry in _reactiveFunctions.entries) {
      final key = entry.key;
      final fn = entry.value;
      final deps = _functionDependencies[key];
      
      if (deps != null && deps.isNotEmpty) {
        if (_kReactivePropsDebug) print('📌 View#$viewId subscribing to ${deps.length} signals for reactive prop "$key"');
        
        for (final signal in deps) {
          signal.subscribeView(viewId, () async {
            // Re-execute function when any dependency changes
            try {
              final newValue = fn();
              if (_kReactivePropsDebug) print('  🔄 Direct update: view#$viewId.$key = $newValue');
              await updateFn({key: newValue});
            } catch (e) {
              if (_kReactivePropsDebug) print('  ⚠️ Failed to re-execute reactive function: $e');
            }
          });
        }
      }
    }
  }
  
  /// Unsubscribe from all signals (when view is destroyed)
  void dispose() {
    for (final signal in _signalProps.values) {
      signal.unsubscribeView(viewId);
    }
    for (final deps in _functionDependencies.values) {
      for (final signal in deps) {
        signal.unsubscribeView(viewId);
      }
    }
    _signalProps.clear();
    _reactiveFunctions.clear();
    _functionDependencies.clear();
    _staticProps.clear();
  }
  
  bool get hasReactiveProps => _signalProps.isNotEmpty || _reactiveFunctions.isNotEmpty;
}

/// Registry to track reactive props for all views
class ReactivePropsRegistry {
  static final ReactivePropsRegistry _instance = ReactivePropsRegistry._();
  static ReactivePropsRegistry get instance => _instance;
  ReactivePropsRegistry._();
  
  final Map<int, ReactiveViewProps> _viewProps = {};
  
  ReactiveViewProps? getProps(int viewId) => _viewProps[viewId];
  
  void register(int viewId, ReactiveViewProps props) {
    _viewProps[viewId] = props;
  }
  
  void unregister(int viewId) {
    final props = _viewProps.remove(viewId);
    props?.dispose();
  }
  
  void clear() {
    for (final props in _viewProps.values) {
      props.dispose();
    }
    _viewProps.clear();
  }
}
